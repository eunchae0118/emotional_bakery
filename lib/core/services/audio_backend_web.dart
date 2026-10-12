// lib/core/services/audio_backend_web.dart
//
// 웹용 AudioBackend 구현. audioplayers_web(HTMLAudioElement 기반)을 안 쓰고 Web Audio API
// (AudioContext)를 직접 씀 - 이유는 두 가지:
// 1. iOS Safari는 HTMLAudioElement.volume을 JS로 못 바꿈(항상 1 고정) - 그래서
//    audioplayers_web 기반으로는 크로스페이드도 설정 메뉴 볼륨 조절도 iOS에서 안 먹힘.
//    Web Audio의 GainNode는 이 제약이 없음.
// 2. HTMLAudioElement는 한 번 멈췄다가 제스처 없이 다시 play()하면 iOS가 거부할 수 있는데,
//    AudioBufferSourceNode는 "디코딩된 버퍼를 재생"하는 방식이라 제스처 문제 자체가 AudioContext
//    하나(생성 시 1번)에만 걸림 - 한 번 resume()해두면 그 뒤로 소스 노드를 몇 개를 새로
//    만들어 재생하든 추가 제스처가 필요 없음(context가 다시 suspended로 안 돌아가는 한).
//
// AudioContext 자체가 다시 suspended로 돌아갈 수 있는 경우(탭 백그라운드, 전화/Siri 등으로
// 오디오 세션 인터럽트)에 대비해서, 복구는 AudioService.onUserGesture()가 터치마다 불러주는
// onUserGesture()에서 처리함 - 여기선 상태 확인 + resume() 재시도만 가볍게 함

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_backend.dart';
import 'package:emotional_bakery/core/services/audio_log.dart';

AudioBackend createAudioBackend() => WebAudioBackend();

// 지금 재생 중인 BGM 트랙 하나가 쓰는 노드 묶음. 크로스페이드로 트랙이 바뀌면 이전 걸
// 들고 있던 _ActiveTrack은 그냥 버려지고(페이드아웃 끝난 뒤 stop+disconnect), 새
// _ActiveTrack이 _activeTrack 자리를 이어받음
class _ActiveTrack {
  _ActiveTrack(this.trackId, this.source, this.gainNode, this.trackGain);

  final String trackId;
  final web.AudioBufferSourceNode source;
  final web.GainNode gainNode; // 이 트랙 전용 - trackGain까지 반영된 크로스페이드 볼륨
  final double trackGain;
}

class WebAudioBackend implements AudioBackend {
  // 지금 아무 곡도 안 흐르고 있다가 처음 소리가 나는 순간 전용 페이드인 길이
  static const Duration _firstPlayFadeInDuration = Duration(
    milliseconds: 1500,
  );
  // onUserGesture가 끊긴 재생을 되살릴 때 쓰는 기본 크로스페이드 길이
  static const Duration _recoveryFadeDuration = Duration(milliseconds: 600);
  // 사용자 볼륨 단계 변경 시 마스터 게인을 부드럽게 바꾸는 램프 길이
  static const double _volumeRampSeconds = 0.15;

  // AudioContext는 앱 전체에서 하나만 만들고 재사용함 - MDN도 이걸 권장함("재사용하고
  // 새로 만들지 마라"). 생성자에서 바로 만들어두되, 실제로 소리가 나려면 resume()이
  // 사용자 제스처 안에서 불려야 함(onUserGesture 참고)
  final web.AudioContext _audioContext = web.AudioContext();

  // BGM 마스터 게인. 트랙 전용 게인(trackGain, 크로스페이드) -> 이 마스터 게인(bgmLevel,
  // 사용자 볼륨 단계) -> destination 순서로 연결함
  late final web.GainNode _bgmMasterGain = _audioContext.createGain()
    ..connect(_audioContext.destination);

  // 디코딩된 AudioBuffer 캐시. BGM/효과음 공용 - path 하나당 한 번만 fetch+decode하고,
  // 디코딩 도중에 또 같은 path가 요청되면 같은 Future를 그대로 돌려줘서 "디코딩 끝날 때까지
  // 기다렸다가 재생"이 자연스럽게 됨(이미 끝난 것도 캐시라 즉시 반환됨)
  final Map<String, Future<web.AudioBuffer>> _bufferCache = {};

  String? _activeTrackId; // 지금 재생 "되어야 하는" 트랙(장부) - await 전에 동기적으로 커밋됨
  _ActiveTrack? _activeTrack; // 실제로 만들어져서 재생 중인 노드
  int _fadeToken = 0;
  bool _hasPrefetched = false;

  // Flutter 웹 빌드는 pubspec assets를 '/assets/<에셋키>'로 서빙하는데, 에셋키 자체가 이미
  // 'assets/sounds/...' 형태라서(pubspec에 'assets/sounds/'로 등록했으니까) 최종 요청
  // 경로는 'assets/'가 두 번 겹친 'assets/assets/sounds/...'가 맞음 - audioplayers_web
  // 소스(AudioCache._sanitizeURLForWeb)도 똑같이 이렇게 두 번 붙여서 처리함. 실제
  // flutter build web 결과물(build/web/assets/assets/sounds/...)로도 확인한 경로임
  String _assetUrl(String path) => 'assets/assets/$path';

  Future<web.AudioBuffer> _bufferFor(String path) {
    return _bufferCache.putIfAbsent(path, () => _decode(path));
  }

  Future<web.AudioBuffer> _decode(String path) async {
    try {
      final web.Response response = await web.window
          .fetch(_assetUrl(path).toJS)
          .toDart;
      final JSArrayBuffer arrayBuffer = await response.arrayBuffer().toDart;
      return await _audioContext.decodeAudioData(arrayBuffer).toDart;
    } catch (e) {
      logAudioError('WebAudioBackend._decode($path)', e);
      rethrow;
    }
  }

  // 첫 사용자 제스처 직후 한 번, 등록된 BGM 트랙을 전부 백그라운드로 미리 디코딩해둠.
  // playBgm이 그 전에 불려도 _bufferFor가 같은 Future를 공유하니 중복 디코딩은 안 됨
  void _prefetchAll() {
    for (final String path in AudioIds.bgmTracks.values) {
      unawaited(
        _bufferFor(path).catchError((Object e) {
          // 실패해도 여기선 조용히 넘어감 - 실제 재생 시도(playBgm)에서 다시 에러가 찍히고
          // 거기서 정식으로 처리됨. 프리페치는 그냥 미리 당겨두는 최적화일 뿐
          throw e;
        }),
      );
    }
  }

  @override
  Future<bool> playBgm({
    required String trackId,
    required String path,
    required double trackGain,
    required double bgmLevel,
    required Duration fadeDuration,
  }) async {
    if (_activeTrackId == trackId) {
      // 이미 같은 트랙이 장부상 활성 상태 - 실제로도 노드가 있고 context가 돌고 있으면
      // 진짜로 들리는 중인 거라 더 할 일 없음. 아니면(디코딩/시작 실패 등으로 노드가 없거나
      // context가 still suspended) false를 돌려줘서 바깥(AudioService)이 보류 상태로
      // 기억해뒀다가 다음 onUserGesture에서 다시 시도하게 함
      return _activeTrack != null && _audioContext.state == 'running';
    }

    // 동시성 버그 방지: "이 트랙이 활성이어야 한다"는 의도를 디코딩(await) 전에 먼저
    // 동기적으로 커밋해둠 - 안 그러면 디코딩 기다리는 사이 같은 트랙이 또 요청됐을 때 위
    // 가드가 못 걸러서 중복 재생될 수 있음(예전 audioplayers 기반 구현에서 실제로 겪었던
    // 버그 - audio_service.dart 이전 버전 주석 참고)
    final String? previousTrackId = _activeTrackId;
    final int token = ++_fadeToken;
    _activeTrackId = trackId;

    web.AudioBuffer buffer;
    try {
      buffer = await _bufferFor(path);
    } catch (e) {
      if (token == _fadeToken) _activeTrackId = previousTrackId;
      return false;
    }
    // 디코딩을 기다리는 사이 더 최신 요청이 들어와서 이미 추월당했으면 조용히 포기
    if (token != _fadeToken) return false;

    final _ActiveTrack? outgoing = _activeTrack;
    final bool isFirstPlay = outgoing == null;
    final Duration effectiveFade = isFirstPlay
        ? _firstPlayFadeInDuration
        : fadeDuration;
    final double fadeSeconds = effectiveFade.inMilliseconds / 1000;

    final web.AudioBufferSourceNode source = _audioContext.createBufferSource();
    source.buffer = buffer;
    source.loop = true; // AudioBufferSourceNode의 네이티브 루프는 샘플 단위로 끊김이 없음
    final web.GainNode trackGainNode = _audioContext.createGain();
    source.connect(trackGainNode);
    trackGainNode.connect(_bgmMasterGain);

    final double now = _audioContext.currentTime;
    trackGainNode.gain.setValueAtTime(0.0, now);
    trackGainNode.gain.linearRampToValueAtTime(trackGain, now + fadeSeconds);

    try {
      source.start(0);
    } catch (e) {
      logAudioError('WebAudioBackend.playBgm($trackId) start', e);
      if (token == _fadeToken) _activeTrackId = previousTrackId;
      try {
        trackGainNode.disconnect();
      } catch (_) {}
      return false;
    }

    _activeTrack = _ActiveTrack(trackId, source, trackGainNode, trackGain);

    if (outgoing != null) {
      final web.AudioParam outGain = outgoing.gainNode.gain;
      final double currentOutValue = outGain.value; // 중간에 끊긴 상태여도 정확한 현재값
      outGain.cancelScheduledValues(now);
      outGain.setValueAtTime(currentOutValue, now);
      outGain.linearRampToValueAtTime(0.0, now + fadeSeconds);
      Future.delayed(effectiveFade, () => _safeStopTrack(outgoing));
    }

    // 첫 터치가 일어났다는 뜻이니(여기까지 왔다는 건 디코딩도 성공했다는 거라) 아직 안
    // 당겨놨으면 나머지 등록된 곡들도 미리 디코딩해둠
    if (!_hasPrefetched) {
      _hasPrefetched = true;
      _prefetchAll();
    }

    return _audioContext.state == 'running';
  }

  void _safeStopTrack(_ActiveTrack track) {
    try {
      track.source.stop();
    } catch (e) {
      logAudioError('WebAudioBackend._safeStopTrack', e);
    }
    try {
      track.source.disconnect();
      track.gainNode.disconnect();
    } catch (_) {
      // 이미 끊겨있으면 그냥 무시 - 정리 과정이라 실패해도 재생엔 영향 없음
    }
  }

  @override
  Future<void> stopBgm(Duration fadeOut) async {
    final _ActiveTrack? track = _activeTrack;
    if (track == null) return;
    _activeTrackId = null;
    _activeTrack = null;
    ++_fadeToken;

    final double now = _audioContext.currentTime;
    final web.AudioParam gain = track.gainNode.gain;
    final double currentValue = gain.value;
    gain.cancelScheduledValues(now);
    gain.setValueAtTime(currentValue, now);
    gain.linearRampToValueAtTime(0.0, now + fadeOut.inMilliseconds / 1000);
    await Future.delayed(fadeOut);
    _safeStopTrack(track);
  }

  @override
  void setBgmLevel(double bgmLevel, double trackGain) {
    final double now = _audioContext.currentTime;
    final web.AudioParam master = _bgmMasterGain.gain;
    final double current = master.value;
    master.cancelScheduledValues(now);
    master.setValueAtTime(current, now);
    master.linearRampToValueAtTime(bgmLevel, now + _volumeRampSeconds);
    // trackGain은 트랙 전용 게인 노드에 크로스페이드 시작할 때 이미 반영돼있고(고정값이라
    // 재생 중에 또 바뀌지 않음), 사용자 볼륨 단계는 여기 마스터 게인에서만 다루면 됨
  }

  @override
  Future<void> playSfx({required String path, required double sfxLevel}) async {
    if (sfxLevel <= 0) return;
    web.AudioBuffer buffer;
    try {
      buffer = await _bufferFor(path);
    } catch (e) {
      return; // 디코딩 실패는 _decode에서 이미 로그 남김
    }
    try {
      final web.AudioBufferSourceNode source = _audioContext.createBufferSource();
      source.buffer = buffer;
      final web.GainNode gainNode = _audioContext.createGain();
      gainNode.gain.setValueAtTime(sfxLevel, _audioContext.currentTime);
      source.connect(gainNode);
      gainNode.connect(_audioContext.destination);
      source.start(0);
    } catch (e) {
      logAudioError('WebAudioBackend.playSfx', e);
    }
  }

  // resume() Promise가 이미 떠서 기다리는 중인지. main.dart가 포인터 다운/업 둘 다에서
  // onUserGesture를 부르니까, 같은 터치 안에서 이 함수가 두 번 불려도 resume()을 중복으로
  // 걸지 않게 막는 용도
  bool _resumeInFlight = false;

  @override
  void onUserGesture({
    required String? activeTrackId,
    required String? activePath,
    required double trackGain,
    required double bgmLevel,
  }) {
    // iOS는 resume()이 제스처 처리 콜스택 안에서 "동기적으로 호출"돼야 인정해줌 - await로
    // 한 틱이라도 미루면 거부될 수 있어서, 상태 확인 직후 바로(다른 await 없이) 호출함.
    // 포인터 다운에서 거부돼도 포인터 업에서 한 번 더 기회가 옴(main.dart 참고)
    if (_audioContext.state != 'running' && !_resumeInFlight) {
      _resumeInFlight = true;
      _audioContext.resume().toDart.then(
        (_) {
          _resumeInFlight = false;
          // resume이 실제로 끝난 시점에 한 번 더 확인함 - 보통은 아래에서 바로 건
          // playBgm이 이미 노드를 만들어서 큐에 걸어둔 상태라 resume되는 순간 자동으로
          // 들리기 시작하지만, 혹시 그 사이 노드 자체가 안 만들어진 채로 남아있으면
          // (예: 그때는 activeTrack이 없었는데 지금은 생겼어야 하는 경우) 여기서 한 번 더
          // 되살림. 다운/업 호출 시점 기준 값을 그대로 들고 있어서, 그 사이 다른 트랙으로
          // 바뀌었으면 _maybeRevivePending 안에서 걸러짐
          _maybeRevivePending(
            activeTrackId: activeTrackId,
            activePath: activePath,
            trackGain: trackGain,
            bgmLevel: bgmLevel,
          );
        },
        onError: (Object e) {
          _resumeInFlight = false;
          logAudioError('WebAudioBackend.resume', e);
        },
      );
    }

    if (!_hasPrefetched && _audioContext.state == 'running') {
      _hasPrefetched = true;
      _prefetchAll();
    }

    _maybeRevivePending(
      activeTrackId: activeTrackId,
      activePath: activePath,
      trackGain: trackGain,
      bgmLevel: bgmLevel,
    );
  }

  // activeTrackId에 맞는 노드가 이미 있으면(=정상 재생 중이거나, context가 suspended라도
  // 노드 자체는 만들어져서 재생 대기 중이면) 더 할 일 없음 - context가 resume되는 순간
  // 이미 만들어둔 노드가 알아서 소리를 내기 시작하니까, 새로 재생을 걸 필요가 없음. 노드
  // 자체가 없는 경우(디코딩/시작이 실패했던 경우)에만 다시 playBgm을 시도함. playBgm 쪽도
  // "같은 trackId면 바로 return"하는 가드가 있어서, 여기서 두 번 불려도 소스가 중복으로
  // 생기진 않음(멱등)
  void _maybeRevivePending({
    required String? activeTrackId,
    required String? activePath,
    required double trackGain,
    required double bgmLevel,
  }) {
    if (activeTrackId == null || activePath == null) return;
    // 그 사이 장부가 다른 트랙으로 바뀌었으면(= 이 되살리기 시도가 오래된 정보 기준이면)
    // 지금 상황이랑 안 맞는 트랙을 재생할 수 있으니 조용히 포기함
    if (_activeTrackId != activeTrackId) return;
    if (_activeTrack != null) return; // 이미 노드가 떠 있음 - 재생 불필요
    playBgm(
      trackId: activeTrackId,
      path: activePath,
      trackGain: trackGain,
      bgmLevel: bgmLevel,
      fadeDuration: _recoveryFadeDuration,
    );
  }

  @override
  Future<void> pauseForLifecycle() async {
    try {
      await _audioContext.suspend().toDart;
    } catch (e) {
      logAudioError('WebAudioBackend.pauseForLifecycle', e);
    }
  }

  @override
  Future<void> resumeForLifecycle() async {
    try {
      await _audioContext.resume().toDart;
    } catch (e) {
      // 탭 복귀가 사용자 제스처로 안 치는 브라우저도 있어서 여기선 실패가 흔할 수 있음 -
      // 그래도 괜찮음, 다음 터치(onUserGesture)에서 다시 시도됨
      logAudioError('WebAudioBackend.resumeForLifecycle', e);
    }
  }
}
