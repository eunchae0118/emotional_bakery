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
  static const Duration _firstPlayFadeInDuration = Duration(milliseconds: 1500);
  // onUserGesture가 끊긴 재생을 되살릴 때 쓰는 기본 크로스페이드 길이
  static const Duration _recoveryFadeDuration = Duration(milliseconds: 600);
  // 사용자 볼륨 단계 변경 시 마스터 게인을 부드럽게 바꾸는 램프 길이
  static const double _volumeRampSeconds = 0.15;

  // AudioContext는 보통 앱 전체에서 하나만 만들고 재사용함 - MDN도 이걸 권장함("재사용하고
  // 새로 만들지 마라"). 생성자에서 바로 만들어두되, 실제로 소리가 나려면 resume()이
  // 사용자 제스처 안에서 불려야 함(onUserGesture 참고). 단, 백그라운드 복귀 시에는
  // _rebuildContextSynchronously에서 통째로 새로 만들어 이 필드를 교체하기 때문에 final이
  // 아님 - 아래 메서드들은 다 이 필드를 그때그때 다시 읽으니 교체돼도 자연히 새 걸 씀
  web.AudioContext _audioContext = web.AudioContext();

  // BGM 마스터 게인. 트랙 전용 게인(trackGain, 크로스페이드) -> 이 마스터 게인(bgmLevel,
  // 사용자 볼륨 단계) -> destination 순서로 연결함. _audioContext랑 같은 이유로 final이
  // 아님 - context가 바뀌면 새 context에 묶인 새 게인 노드로 같이 바꿔줘야 함
  late web.GainNode _bgmMasterGain;

  // bgmMasterGain을 만들고 destination까지 연결해서 돌려줌 - 생성자에서 처음 만들 때랑
  // 백그라운드 복귀 후 context를 새로 만들 때(_rebuildContextSynchronously) 둘 다 씀
  web.GainNode _createMasterGain(web.AudioContext context) {
    final web.GainNode gain = context.createGain();
    gain.connect(context.destination);
    return gain;
  }

  // 디코딩된 BGM AudioBuffer 캐시의 최대 개수(LRU). 곡이 10곡 안팎으로 늘면 디코딩된
  // PCM 버퍼가 전부 메모리에 눌러앉아서 아이폰 사파리에서 메모리 부족으로 탭이 죽을 수
  // 있어서, 최근에 요청한 곡만 이 개수만큼 들고 있고 나머지는 디코딩 결과를 버림(다시
  // 필요해지면 그때 또 디코딩함 - 느려지는 것뿐이지 끊기거나 틀리게 재생되진 않음)
  static const int _bgmBufferCacheLimit = 2;

  // 디코딩된 BGM AudioBuffer 캐시. Dart의 Map은 삽입 순서를 그대로 유지하는
  // LinkedHashMap이라, "읽을 때마다 remove 후 다시 넣기"로 최근 사용 순서를 유지함 -
  // 맨 앞(keys.first)이 항상 가장 오래 안 쓴 항목이 됨(_bgmBufferFor/
  // _evictOldestBgmBufferIfNeeded 참고). path 하나당 한 번만 fetch+decode하고, 디코딩
  // 도중에 또 같은 path가 요청되면 같은 Future를 그대로 돌려줘서 "디코딩 끝날 때까지
  // 기다렸다가 재생"이 자연스럽게 됨(이미 끝난 것도 캐시라 즉시 반환됨)
  final Map<String, Future<web.AudioBuffer>> _bgmBufferCache = {};

  // 효과음용 디코딩 캐시. 짧은 파일이라 메모리 부담이 적어서 BGM이랑 별개로 한도 없이
  // 유지함(이쪽은 LRU 안 씀)
  final Map<String, Future<web.AudioBuffer>> _sfxBufferCache = {};

  // 지금 겹쳐 재생 중인 블립 소스 노드들. stopBlip()이 이걸 전부 끊어줌 - 'ended'
  // 이벤트가 자연스럽게 끝난 노드는 알아서 이 집합에서 빠짐(아래 playBlip 참고)
  final Set<web.AudioBufferSourceNode> _activeBlipSources = {};

  String? _activeTrackId; // 지금 재생 "되어야 하는" 트랙(장부) - await 전에 동기적으로 커밋됨
  _ActiveTrack? _activeTrack; // 실제로 만들어져서 재생 중인 노드
  int _fadeToken = 0;

  // 지금 재생 "되어야 하는" 트랙의 asset 경로. _evictOldestBgmBufferIfNeeded가 캐시를
  // 비울 때 이 경로는 절대 안 건드리려고 뽑아둠 - 재생 중인 트랙은 한참 전에 캐시에서
  // 한 번만 요청되고 그 뒤로는 다시 안 건드려지니까(계속 루프 재생만 하니까), LRU 기준
  // "오래 안 쓴 항목"에 걸려서 다른 곡 prefetch 때문에 밀려날 수 있음
  String? get _activeBgmPath {
    final String? trackId = _activeTrackId;
    if (trackId == null) return null;
    return AudioIds.bgmTracks[trackId];
  }

  // BGM 디코딩(fetch+decodeAudioData)을 한 번에 하나씩만 돌게 직렬화하는 큐. 재생 중인
  // 곡 디코딩이랑 다음 챕터 prefetch가 동시에 겹치면 그 순간 두 곡의 PCM이 동시에
  // 메모리에 떠서 피크가 커지니까, 뒤에 온 요청은 앞 디코딩이 끝날 때까지 기다리게 함.
  // 체이닝한 Future 안에서 try/catch로 에러를 흡수해서, 하나가 실패해도 큐 자체는 안
  // 끊기고 다음 요청이 그대로 이어서 돎
  Future<void> _bgmDecodeQueue = Future.value();

  // setBgmLevel이 마지막으로 받은 사용자 볼륨 레벨(0~1). 네이티브 DOM 리스너처럼
  // AudioService를 거치지 않고 백엔드 혼자 재생을 되살려야 하는 경로에서 다시 씀
  double _lastBgmLevel = 0.6;

  // resume()이 지금 진행 중인지 - resume() 호출 자체를 막는 데는 안 씀(state만 보고 여러
  // 경로에서 몇 번을 불러도 안전함). 성공한 뒤 재생을 되살리는 쪽(_maybeRevivePendingFromState)
  // 은 "이미 노드가 떠 있으면 아무것도 안 함"이라는 멱등성으로 중복을 막기 때문에, 이 플래그는
  // 그걸 또 막는 용도가 아니라 진단 패널(debugStatus)에서 "지금 resume 요청이 떠 있는지"를
  // 보여주는 참고용 상태값으로만 씀
  bool _resumeInFlight = false;

  // 탭이 백그라운드로 나갔다가(hidden/pagehide) 돌아왔을 때, 복귀 후 첫 터치에서
  // AudioContext를 통째로 새로 만들어야 하는지 표시하는 플래그. iOS가 백그라운드 동안
  // context를 'interrupted'로 바꾸는데, 이걸 resume()으로 되살리려 하면 깨진 버퍼
  // 조각이 반복 재생되는 비프음이 날 수 있어서, 복구 대신 "나갔다 오면 항상 새 context를
  // 만든다"는 결정적인 방식을 씀. 이 플래그는 나갈 때(hidden/pagehide) true로 세팅되고,
  // 복귀 후 첫 네이티브 활성화 이벤트(touchend/pointerup/click)에서 소비됨
  bool _needsRebuildOnReturn = false;

  // 나갈 때 마스터 게인을 0으로 페이드했다가, 복귀 후 새 context의 마스터 게인을 원래
  // 값으로 되돌리기 위해 기억해두는 값. 페이드로 날려버린 값이라 나중에 다시 읽을 방법이
  // 없어서 미리 찍어둬야 함
  double? _rebuildTargetMasterGain;

  // 나갈 때 마스터 게인을 0으로 줄이는 데 걸리는 시간(초). iOS가 context를 interrupted로
  // 바꾸면서 재생 중이던 버퍼 조각이 그대로 반복되는 비프음이 나는 걸 막으려고, suspend()
  // 호출 전에 아주 짧게 무음으로 만들어둠
  static const double _hideGainFadeSeconds = 0.08;

  // Flutter의 Listener(onPointerUp) 경로는 이벤트가 프레임 단위로 지연 전달될 수 있어서,
  // iOS가 "사용자 활성화"로 안 쳐줄 가능성이 있음 - 그래서 document에 직접 네이티브 DOM
  // 리스너를 달아서 더 확실하게 resume()을 시도함. 생성자는 한 번만 불리니까 리스너도
  // 자연히 한 번만 등록됨
  WebAudioBackend() {
    _bgmMasterGain = _createMasterGain(_audioContext);

    void handleActivationEvent(web.Event event) {
      // 백그라운드에서 돌아온 뒤 첫 활성화 이벤트면 resume() 대신 context를 통째로
      // 새로 만듦. 같은 터치에서 touchend/pointerup/click이 연달아 와도 플래그를 제일
      // 먼저 내려서(동기적으로) 한 번만 재구축되게 함
      if (_needsRebuildOnReturn) {
        _needsRebuildOnReturn = false;
        _rebuildContextSynchronously(event.type);
        return;
      }
      _tryResume(event.type);
    }

    final web.EventListener listener = handleActivationEvent.toJS;
    final web.AddEventListenerOptions options = web.AddEventListenerOptions(
      capture: true,
      passive: true,
    );
    web.document.addEventListener('touchend', listener, options);
    web.document.addEventListener('pointerup', listener, options);
    web.document.addEventListener('click', listener, options);

    // 탭이 백그라운드로 나가는 걸 감지하는 두 경로. visibilitychange(hidden)가 기본이고,
    // pagehide는 iOS Safari가 visibilitychange보다 먼저/대신 쏘는 경우가 있어서 같이 둠 -
    // _fadeOutAndSuspend 자체가 "이미 처리 중이면 무시"라 둘 다 걸려도 중복 실행은 안 됨
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'hidden') {
          unawaited(_fadeOutAndSuspend('visibilitychange(hidden)'));
        } else {
          logAudioError(
            'WebAudioBackend.visibilitychange',
            'visible 감지(state=${_audioContext.state} needsRebuild=$_needsRebuildOnReturn)',
          );
        }
      }).toJS,
      options,
    );
    web.window.addEventListener(
      'pagehide',
      ((web.Event _) {
        unawaited(_fadeOutAndSuspend('pagehide'));
      }).toJS,
      options,
    );

    // 돌아올 때는 여기서 아무 오디오 호출도 안 함 - iOS는 사용자 터치 없이는 resume을
    // 허용 안 해서, 실제 복구는 복귀 후 첫 터치(위 handleActivationEvent)에서만 함.
    // 여기선 진단용 로그만 남김
    web.window.addEventListener(
      'pageshow',
      ((web.Event _) {
        logAudioError(
          'WebAudioBackend.pageshow',
          '감지(state=${_audioContext.state} needsRebuild=$_needsRebuildOnReturn)',
        );
      }).toJS,
      options,
    );
    web.window.addEventListener(
      'focus',
      ((web.Event _) {
        logAudioError(
          'WebAudioBackend.focus',
          '감지(state=${_audioContext.state} needsRebuild=$_needsRebuildOnReturn)',
        );
      }).toJS,
      options,
    );
  }

  // 탭이 백그라운드로 나갈 때(hidden/pagehide) 호출됨. iOS가 곧 context를 interrupted로
  // 바꾸면서 그 순간 재생 중이던 버퍼 조각이 반복 재생되는 비프음이 나는 걸 막으려고,
  // suspend() 호출 전에 마스터 게인을 아주 짧게 0으로 줄여둠. 복귀 후 첫 터치에서
  // context를 통째로 새로 만들 거라는 표시(_needsRebuildOnReturn)와, 그때 마스터 게인을
  // 되돌릴 목표값(_rebuildTargetMasterGain)도 여기서 같이 남겨둠
  Future<void> _fadeOutAndSuspend(String reason) async {
    if (_needsRebuildOnReturn) return; // 이미 처리 중 - hidden+pagehide 겹쳐 와도 한 번만
    logAudioError(
      'WebAudioBackend._fadeOutAndSuspend',
      '감지됨(reason=$reason state=${_audioContext.state})',
    );
    _needsRebuildOnReturn = true;
    _rebuildTargetMasterGain = _bgmMasterGain.gain.value;

    final web.AudioContext context = _audioContext;
    final web.GainNode masterGain = _bgmMasterGain;
    try {
      final double now = context.currentTime;
      final double current = masterGain.gain.value;
      masterGain.gain.cancelScheduledValues(now);
      masterGain.gain.setValueAtTime(current, now);
      masterGain.gain.linearRampToValueAtTime(0.0, now + _hideGainFadeSeconds);
      logAudioError(
        'WebAudioBackend._fadeOutAndSuspend',
        '게인 페이드 예약됨(reason=$reason)',
      );
    } catch (e) {
      logAudioError(
        'WebAudioBackend._fadeOutAndSuspend',
        '게인 페이드 예약 실패(reason=$reason): $e',
      );
    }

    await Future.delayed(
      Duration(milliseconds: (_hideGainFadeSeconds * 1000).round()),
    );

    try {
      await context.suspend().toDart;
      logAudioError(
        'WebAudioBackend._fadeOutAndSuspend',
        'suspend 성공(reason=$reason state=${context.state})',
      );
    } catch (e) {
      logAudioError(
        'WebAudioBackend._fadeOutAndSuspend',
        'suspend 실패(reason=$reason): $e',
      );
    }
  }

  // 백그라운드 복귀 후 첫 활성화 이벤트(touchend/pointerup/click) 안에서 동기적으로
  // 불림 - AudioContext 생성과 resume() 호출 사이에 await가 하나도 없어야 iOS가 이
  // resume()을 사용자 제스처로 인정해주기 때문에, 이 함수는 async가 아니라 그냥 void로
  // 만들어서 앞부분(context 교체, 게인 노드 재연결)이 전부 한 틱 안에 동기적으로 끝나게 함.
  // 이미 디코딩된 AudioBuffer 캐시(_bgmBufferCache/_sfxBufferCache)는 context에 안
  // 묶여있어서 그대로 재사용함 - 여기서 다시 디코딩하지 않음
  void _rebuildContextSynchronously(String eventLabel) {
    logAudioError('WebAudioBackend.rebuildContext', '시작(event=$eventLabel)');

    // a) 기존 context는 닫기만 하고 결과는 안 기다림(await 금지) - 실패해도 무시
    final web.AudioContext oldContext = _audioContext;
    try {
      oldContext.close().toDart.then(
        (_) => logAudioError(
          'WebAudioBackend.rebuildContext',
          '기존 context close 성공',
        ),
        onError: (Object e) => logAudioError(
          'WebAudioBackend.rebuildContext',
          '기존 context close 실패(무시): $e',
        ),
      );
    } catch (e) {
      logAudioError(
        'WebAudioBackend.rebuildContext',
        '기존 context close 호출 자체 실패(무시): $e',
      );
    }

    // b) 새 context를 만들고 바로 resume() 호출 - 여기까지 await가 하나도 없어야 함
    final web.AudioContext newContext = web.AudioContext();
    _audioContext = newContext;

    // 옛 context에 묶여있던 소스/게인 노드 참조는 여기서 버림 - 새 context 위에서
    // 새로 만들 거라 재사용 안 함. 토큰도 올려서 옛 context를 참조하던 진행 중인
    // 크로스페이드/타이머 클로저가 전부 낡은 것으로 처리되게 함
    _activeTrack = null;
    ++_fadeToken;

    // c) 마스터 게인을 새 context 위에 다시 만들고 destination까지 재연결, 나갈 때
    // 기억해둔 목표값으로 즉시 복원(여기도 램프 없이 바로 세팅 - 끊긴 상태에서 막 돌아온
    // 거라 페이드할 "이전 값"이라는 개념이 없음)
    _bgmMasterGain = _createMasterGain(newContext);
    final double targetMasterGain = _rebuildTargetMasterGain ?? _lastBgmLevel;
    _bgmMasterGain.gain.setValueAtTime(
      targetMasterGain,
      newContext.currentTime,
    );
    _rebuildTargetMasterGain = null;

    logAudioError(
      'WebAudioBackend.rebuildContext',
      '새 context 생성 완료(state=${newContext.state})',
    );

    newContext.resume().toDart.then(
      (_) {
        logAudioError(
          'WebAudioBackend.rebuildContext',
          'resume 성공(event=$eventLabel state=${newContext.state})',
        );
        // 아래 playBgm 동기 호출 시점에 아직 resume이 안 끝나서 재생이 보류됐을 수
        // 있으니, resume이 실제로 끝난 뒤 한 번 더 되살려봄 - 이미 노드가 떠 있으면
        // 멱등이라 아무 일도 안 함
        _maybeRevivePendingFromState();
      },
      onError: (Object e) {
        logAudioError(
          'WebAudioBackend.rebuildContext',
          'resume 실패(event=$eventLabel): $e',
        );
      },
    );

    // d) 기억해둔(장부에 남아있는) 곡을 처음부터 재생 - 디코딩된 버퍼는 캐시에 이미
    // 있어서 재사용되고, 페이드인은 playBgm이 "노드가 없던 상태에서 처음 재생"으로 인식해
    // _firstPlayFadeInDuration(기존 로직)을 그대로 씀
    final String? trackId = _activeTrackId;
    if (trackId != null) {
      final String? path = AudioIds.bgmTracks[trackId];
      final double trackGain = AudioIds.trackGain[trackId] ?? 1.0;
      if (path != null) {
        logAudioError(
          'WebAudioBackend.rebuildContext',
          '재생 시작 시도(trackId=$trackId)',
        );
        playBgm(
          trackId: trackId,
          path: path,
          trackGain: trackGain,
          bgmLevel: _lastBgmLevel,
          fadeDuration: _firstPlayFadeInDuration,
        );
      }
    }

    logAudioError('WebAudioBackend.rebuildContext', '완료(event=$eventLabel)');
  }

  // resume() 호출 + 로그 + 성공/실패 후처리를 한곳에 모아둠 - Flutter Listener 경로
  // (onUserGesture)랑 네이티브 DOM 리스너 경로 둘 다 이걸 그대로 씀. eventLabel은 로그에
  // 찍을 이벤트 이름(예: 'onUserGesture', 'pointerup', 'touchend', 'click')
  void _tryResume(String eventLabel) {
    if (_audioContext.state == 'running') return; // 이미 풀려있으면 할 일 없음
    logAudioError(
      'WebAudioBackend.resume',
      '호출(event=$eventLabel state=${_audioContext.state})',
    );
    _resumeInFlight = true;
    _audioContext.resume().toDart.then(
      (_) {
        _resumeInFlight = false;
        logAudioError(
          'WebAudioBackend.resume',
          '성공(event=$eventLabel state=${_audioContext.state})',
        );
        // _maybeRevivePendingFromState는 이미 떠 있는 노드가 있으면 아무것도 안 하는
        // 멱등 함수라, 여러 경로에서 겹쳐 불려도 안전함
        _maybeRevivePendingFromState();
      },
      onError: (Object e) {
        _resumeInFlight = false;
        logAudioError(
          'WebAudioBackend.resume',
          '실패(event=$eventLabel state=${_audioContext.state}): $e',
        );
      },
    );
  }

  // Flutter 웹 빌드는 pubspec assets를 '/assets/<에셋키>'로 서빙하는데, 에셋키 자체가 이미
  // 'assets/sounds/...' 형태라서(pubspec에 'assets/sounds/'로 등록했으니까) 최종 요청
  // 경로는 'assets/'가 두 번 겹친 'assets/assets/sounds/...'가 맞음 - audioplayers_web
  // 소스(AudioCache._sanitizeURLForWeb)도 똑같이 이렇게 두 번 붙여서 처리함. 실제
  // flutter build web 결과물(build/web/assets/assets/sounds/...)로도 확인한 경로임.
  //
  // (업데이트: 단순 상대경로 문자열 대신 document.baseURI 기준으로 명시적으로 절대경로를
  // 만들어서 fetch에 넘기게 바꿈 - gh-pages처럼 base href가 '/'가 아닌 서브경로(예:
  // '/emotional_bakery/')로 배포될 때, 상대경로가 혹시라도 엉뚱한 기준으로 풀릴 여지를
  // 아예 없애려는 거임. document.baseURI는 <base href>를 그대로 반영하니까 이걸 기준으로
  // resolve하면 배포 경로가 어디든 항상 올바른 절대 URL이 나옴)
  String _assetUrl(String path) {
    final Uri base = Uri.parse(web.document.baseURI);
    return base.resolve('assets/assets/$path').toString();
  }

  Future<web.AudioBuffer> _bgmBufferFor(String path) {
    final Future<web.AudioBuffer>? cached = _bgmBufferCache.remove(path);
    if (cached != null) {
      _bgmBufferCache[path] = cached; // 다시 넣어서 맨 뒤(최근 사용)로 옮김
      return cached;
    }
    // 새 디코딩을 큐에 올리기 전에 먼저 자리를 비움 - 디코딩이 끝난 뒤에 비우면 그 사이
    // 새 버퍼랑 오래된 버퍼가 둘 다 메모리에 떠있는 순간이 생기니까, 순서를 뒤집어서
    // "비우고 -> 디코딩 시작"으로 함. 지금 재생 중인 트랙(_activeBgmPath)은 예외
    _evictOldestBgmBufferIfNeeded(keepPath: _activeBgmPath);
    final Future<web.AudioBuffer> future = _decodeBgmQueued(path);
    _bgmBufferCache[path] = future;
    return future;
  }

  // 캐시가 한도를 넘으면 가장 오래 안 쓴 항목(맨 앞)부터 내림. 디코딩이 아직 안 끝난
  // Future를 내려도 문제없음 - 그 Future는 호출한 쪽(playBgm의 로컬 변수)이 이미 따로
  // 참조하고 있어서 디코딩 자체는 끝까지 진행되고, 여기서는 캐시에서만 빠짐(나중에 같은
  // 곡을 다시 요청하면 캐시에 없으니 처음부터 다시 디코딩함)
  //
  // keepPath는 절대 안 내림 - 지금 재생 중인 트랙을 챕터 선택 카드 prefetch 같은 걸로
  // 밀어내지 않으려는 용도. 호출 시점이 "새 디코딩을 큐에 올리기 전"으로 바뀌어서, 기준도
  // "넘으면"이 아니라 "넘을 예정이면"(= 지금 길이가 이미 한도 이상)으로 바뀜 - 비우고 난
  // 뒤에 새 항목 하나가 들어와야 한도를 맞출 수 있어서임
  void _evictOldestBgmBufferIfNeeded({String? keepPath}) {
    final List<String> candidates = _bgmBufferCache.keys
        .where((path) => path != keepPath)
        .toList();
    for (final String oldestPath in candidates) {
      if (_bgmBufferCache.length < _bgmBufferCacheLimit) break;
      _bgmBufferCache.remove(oldestPath);
      logAudioError(
        'WebAudioBackend._evictOldestBgmBufferIfNeeded',
        '캐시에서 내림: $oldestPath',
      );
    }
  }

  // _decode(path)를 직접 안 부르고 _bgmDecodeQueue에 체이닝해서, 앞서 요청된 BGM
  // 디코딩이 끝나야 이 디코딩의 실제 fetch+decodeAudioData가 시작되게 함. SFX는 파일이
  // 작아서 이 큐에 안 태우고 그대로 둠(_sfxBufferFor는 안 건드림)
  Future<web.AudioBuffer> _decodeBgmQueued(String path) {
    final Completer<web.AudioBuffer> completer = Completer<web.AudioBuffer>();
    _bgmDecodeQueue = _bgmDecodeQueue.then((_) async {
      try {
        completer.complete(await _decode(path));
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<web.AudioBuffer> _sfxBufferFor(String path) {
    return _sfxBufferCache.putIfAbsent(path, () => _decode(path));
  }

  Future<web.AudioBuffer> _decode(String path) async {
    final String url = _assetUrl(path);
    try {
      final web.Response response = await web.window.fetch(url.toJS).toDart;
      logAudioError(
        'WebAudioBackend._decode',
        'fetch $url -> status=${response.status} ok=${response.ok}',
      );
      if (!response.ok) {
        // fetch는 404/500 같은 HTTP 에러 상태를 reject가 아니라 "성공적으로 받은 응답"
        // 으로 돌려줌 - 여기서 직접 안 걸러내면 에러 페이지(HTML) 바이트를 decodeAudioData에
        // 넘기게 돼서, 진짜 원인(경로가 틀렸다는 것)이 안 보이고 디코딩 실패로만 찍힘
        throw Exception(
          'HTTP ${response.status}로 에셋을 못 받아옴 - 경로가 틀렸을 가능성이 큼: $url',
        );
      }
      final JSArrayBuffer arrayBuffer = await response.arrayBuffer().toDart;
      final web.AudioBuffer buffer = await _audioContext
          .decodeAudioData(arrayBuffer)
          .toDart;
      logAudioError(
        'WebAudioBackend._decode',
        '디코딩 성공: $url (길이 ${buffer.duration.toStringAsFixed(2)}초)',
      );
      return buffer;
    } catch (e) {
      logAudioError('WebAudioBackend._decode($path)', e);
      rethrow;
    }
  }

  // 곧 재생할 BGM을 재생 없이 디코딩만 당겨둠. 챕터 진입 화면이 "다음에 나올 곡"을 한
  // 발 먼저 요청해두는 용도(AudioService.prefetchBgm 참고) - _bgmBufferFor가 같은
  // Future를 공유하니 실제 playBgm 때 중복 디코딩은 안 되고, LRU 캐시 한도도 그대로 적용됨
  @override
  void prefetchBgm(String path) {
    unawaited(
      _bgmBufferFor(path).catchError((Object e) {
        // 실패해도 여기선 조용히 넘어감 - 실제 재생 시도(playBgm)에서 다시 에러가 찍히고
        // 거기서 정식으로 처리됨. 프리페치는 그냥 미리 당겨두는 최적화일 뿐
        throw e;
      }),
    );
  }

  @override
  Future<bool> playBgm({
    required String trackId,
    required String path,
    required double trackGain,
    required double bgmLevel,
    required Duration fadeDuration,
  }) async {
    if (_activeTrackId == trackId && _activeTrack != null) {
      // 이미 이 트랙이 실제로(소리 날 수 있는 노드까지) 떠 있음 - 더 할 일 없음
      return _audioContext.state == 'running';
    }

    // 같은 트랙을 다시 요청한 거면(= 전에 커밋만 해두고 context가 안 풀려서 노드를 아직
    // 못 띄운 경우) 토큰은 새로 안 받고 그대로 씀. 완전히 새로운 트랙 요청일 때만 토큰을
    // 올려서 "이전 요청은 이제 낡았다"고 표시함
    final bool isSameTrackRetry = _activeTrackId == trackId;
    final String? previousTrackId = _activeTrackId;
    final int token = isSameTrackRetry ? _fadeToken : ++_fadeToken;
    if (!isSameTrackRetry) {
      // 동시성 버그 방지: "이 트랙이 활성이어야 한다"는 의도를 디코딩(await) 전에 먼저
      // 동기적으로 커밋해둠 - 안 그러면 디코딩 기다리는 사이 같은 트랙이 또 요청됐을 때 위
      // 가드가 못 걸러서 중복 재생될 수 있음(예전 audioplayers 기반 구현에서 실제로 겪었던
      // 버그 - audio_service.dart 이전 버전 주석 참고)
      _activeTrackId = trackId;
    }

    web.AudioBuffer buffer;
    try {
      buffer = await _bgmBufferFor(path);
    } catch (e) {
      if (!isSameTrackRetry && token == _fadeToken)
        _activeTrackId = previousTrackId;
      return false;
    }
    // 디코딩을 기다리는 사이 더 최신 요청이 들어와서 이미 추월당했으면 조용히 포기
    if (token != _fadeToken) return false;

    // context가 아직 안 풀려있으면 여기서 노드를 만들어 바로 start()하지 않고 그냥 포기함
    // (_activeTrackId는 커밋된 채로 남아서, 다음 onUserGesture가 resume 성공 뒤에 이
    // 함수를 다시 불러줌). suspended 상태에서 미리 만들어 start()해둔 소스가 resume 이후에
    // 확실히 들리기 시작한다는 보장이 브라우저마다 다를 수 있어서, 안전하게 진짜 running일
    // 때만 실제로 노드를 만들고 재생을 시작함 - 디코딩은 이미 끝내놨으니(버퍼 캐시됨) 다음
    // 시도에서 다시 fetch/decode를 안 기다려도 됨
    if (_audioContext.state != 'running') {
      logAudioError(
        'WebAudioBackend.playBgm($trackId)',
        'AudioContext가 아직 running이 아님(${_audioContext.state}) - 재생 보류',
      );
      return false;
    }

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
    logAudioError('WebAudioBackend.playBgm($trackId)', 'source.start 성공');

    _activeTrack = _ActiveTrack(trackId, source, trackGainNode, trackGain);

    if (outgoing != null) {
      final web.AudioParam outGain = outgoing.gainNode.gain;
      final double currentOutValue = outGain.value; // 중간에 끊긴 상태여도 정확한 현재값
      outGain.cancelScheduledValues(now);
      outGain.setValueAtTime(currentOutValue, now);
      outGain.linearRampToValueAtTime(0.0, now + fadeSeconds);
      Future.delayed(effectiveFade, () => _safeStopTrack(outgoing));
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
    _lastBgmLevel = bgmLevel;
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
  Future<void> playSfx({
    required String path,
    required double sfxLevel,
    double playbackRate = 1.0,
  }) async {
    if (sfxLevel <= 0) return;
    web.AudioBuffer buffer;
    try {
      buffer = await _sfxBufferFor(path);
    } catch (e) {
      return; // 디코딩 실패는 _decode에서 이미 로그 남김
    }
    try {
      final web.AudioBufferSourceNode source = _audioContext
          .createBufferSource();
      source.buffer = buffer;
      // playBlip이랑 동일하게 AudioBufferSourceNode.playbackRate로 피치를 흔듦 -
      // stopBlip() 추적 대상(_activeBlipSources)에는 안 넣어서, playBlip이 재생한 것만
      // 끊고 여기서 재생한 건 전혀 안 건드림
      source.playbackRate.value = playbackRate;
      final web.GainNode gainNode = _audioContext.createGain();
      gainNode.gain.setValueAtTime(sfxLevel, _audioContext.currentTime);
      source.connect(gainNode);
      gainNode.connect(_audioContext.destination);
      source.start(0);
    } catch (e) {
      logAudioError('WebAudioBackend.playSfx', e);
    }
  }

  // 대사 블립 전용 재생. playSfx랑 거의 같은데 playbackRate를 추가로 받고, 재생한
  // 소스를 _activeBlipSources에 올려서 stopBlip()이 나중에 즉시 끊을 수 있게 해둠.
  // 디코딩/재생 어느 쪽에서 실패하든 조용히 넘어감 - 블립 하나 실패했다고 타이핑/대사
  // 진행이 막히면 안 됨(예: 백그라운드 복귀 직후 context가 아직 안 풀린 경우 등)
  @override
  Future<void> playBlip({
    required String path,
    required double sfxLevel,
    required double playbackRate,
  }) async {
    if (sfxLevel <= 0) return;
    web.AudioBuffer buffer;
    try {
      buffer = await _sfxBufferFor(path);
    } catch (e) {
      return;
    }
    try {
      final web.AudioBufferSourceNode source = _audioContext
          .createBufferSource();
      source.buffer = buffer;
      source.playbackRate.value = playbackRate;
      final web.GainNode gainNode = _audioContext.createGain();
      gainNode.gain.setValueAtTime(sfxLevel, _audioContext.currentTime);
      source.connect(gainNode);
      gainNode.connect(_audioContext.destination);
      source.onended = ((web.Event _) {
        _activeBlipSources.remove(source);
      }).toJS;
      _activeBlipSources.add(source);
      source.start(0);
    } catch (e) {
      logAudioError('WebAudioBackend.playBlip', e);
    }
  }

  @override
  void stopBlip() {
    if (_activeBlipSources.isEmpty) return;
    // stop()이 onended를 바로 동기적으로 쏘기도 해서, 순회 중 집합이 바뀌는 걸 피하려고
    // 복사본을 만들어 돈 다음 한 번에 clear함
    for (final web.AudioBufferSourceNode source
        in _activeBlipSources.toList()) {
      try {
        source.stop();
        source.disconnect();
      } catch (_) {
        // 이미 끝났거나 끊겨있으면 무시 - 어차피 끄려던 거라 실패해도 상관없음
      }
    }
    _activeBlipSources.clear();
  }

  @override
  bool get supportsSfxPlaybackRate => true;

  @override
  void prefetchSfx(String path) {
    unawaited(
      _sfxBufferFor(path).catchError((Object e) {
        // prefetchBgm이랑 같은 이유로 조용히 넘어감 - 실제 재생 시도(playBlip)에서
        // 다시 에러가 찍히고 거기서 정식으로 처리됨
        throw e;
      }),
    );
  }

  @override
  void onUserGesture({required bool canAttemptResume}) {
    // canAttemptResume=false면(pointerdown 등 iOS가 활성화로 안 쳐주는 이벤트) resume()
    // 시도 자체를 안 함 - 여기서 부르면 Promise가 안 풀리는 채로 남을 수 있음
    if (canAttemptResume) {
      _tryResume('onUserGesture');
    }

    // resume 성공을 기다릴 것도 없이, 지금 이미 running이면(예: 네이티브 리스너가 먼저
    // resume을 끝내놓은 경우) 바로 되살려봄 - 노드가 이미 있으면 멱등이라 아무 일도 안 함
    _maybeRevivePendingFromState();
  }

  // 지금 재생 "되어야 하는" 트랙(_activeTrackId)에 맞는 노드가 이미 떠 있으면(=정상
  // 재생 중) 더 할 일 없음. 노드가 아직 없는 경우(디코딩 중이거나, context가 아직
  // running이 아니라서 playBgm이 노드 생성 자체를 보류해둔 경우, 혹은 start가 실패했던
  // 경우) playBgm을 다시 불러서 시도함. trackId/path/trackGain을 바깥에서 안 받고
  // _activeTrackId + AudioIds + _lastBgmLevel로 전부 자체 조달하는 이유: 네이티브 DOM
  // 리스너(생성자 참고)는 AudioService를 거치지 않고 이 백엔드가 직접 받는 이벤트라서,
  // 바깥에서 값을 넘겨받을 방법이 없음 - 그래서 백엔드가 이미 들고 있는 장부만으로
  // 되살릴 수 있게 설계함. playBgm 쪽도 "같은 trackId면서 이미 노드가 있으면 바로
  // return"하는 가드가 있어서, 이 함수가 여러 경로에서 겹쳐 불려도 소스가 중복으로
  // 생기진 않음(멱등)
  void _maybeRevivePendingFromState() {
    final String? trackId = _activeTrackId;
    if (trackId == null) return;
    if (_activeTrack != null) return; // 이미 노드가 떠 있음 - 재생 불필요
    final String? path = AudioIds.bgmTracks[trackId];
    if (path == null) return;
    final double trackGain = AudioIds.trackGain[trackId] ?? 1.0;
    playBgm(
      trackId: trackId,
      path: path,
      trackGain: trackGain,
      bgmLevel: _lastBgmLevel,
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

  // 화면 진단 패널(?audiolog=1) 전용. 터치마다 찍는 로그 한 줄에 상태만 짧게 넣을 때 씀
  @override
  String get audioStateLabel => _audioContext.state;

  // 진단 패널 상태 줄에 쓰는 한 줄 요약. 1초마다 패널이 이걸 다시 불러서 화면에 갱신함
  @override
  String debugStatus() {
    final _ActiveTrack? track = _activeTrack;
    return 'state=${_audioContext.state} '
        'currentTime=${_audioContext.currentTime.toStringAsFixed(2)} '
        'sampleRate=${_audioContext.sampleRate.toStringAsFixed(0)} '
        'activeTrackId=${_activeTrackId ?? "-"} '
        'hasActiveSource=${track != null} '
        'masterGain=${_bgmMasterGain.gain.value.toStringAsFixed(3)} '
        'trackGain=${track?.gainNode.gain.value.toStringAsFixed(3) ?? "-"} '
        'resumeInFlight=$_resumeInFlight';
  }

  // "비프 테스트" 버튼 전용. BGM 디코딩/크로스페이드 경로를 아예 안 거치고
  // OscillatorNode로 순수하게 440Hz 0.5초 비프음만 냄 - 이게 안 들리면 오디오 출력
  // 자체가 막힌 거고, 이건 들리는데 mp3는 안 들리면 디코딩/에셋 경로 쪽 문제로 좁혀짐
  @override
  Future<void> playDiagnosticBeep() async {
    logAudioError(
      'WebAudioBackend.playDiagnosticBeep',
      '시작 전 state=${_audioContext.state}',
    );
    try {
      await _audioContext.resume().toDart;
    } catch (e) {
      logAudioError('WebAudioBackend.playDiagnosticBeep', 'resume 실패: $e');
    }
    logAudioError(
      'WebAudioBackend.playDiagnosticBeep',
      'resume 후 state=${_audioContext.state}',
    );
    try {
      final web.OscillatorNode osc = _audioContext.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, _audioContext.currentTime);
      final web.GainNode gain = _audioContext.createGain();
      gain.gain.setValueAtTime(0.3, _audioContext.currentTime);
      osc.connect(gain);
      gain.connect(_audioContext.destination);
      osc.start();
      osc.stop(_audioContext.currentTime + 0.5);
      logAudioError(
        'WebAudioBackend.playDiagnosticBeep',
        '시작 성공(state=${_audioContext.state})',
      );
    } catch (e) {
      logAudioError('WebAudioBackend.playDiagnosticBeep', '시작 실패: $e');
    }
  }
}
