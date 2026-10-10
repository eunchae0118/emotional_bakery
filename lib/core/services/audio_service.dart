// lib/core/services/audio_service.dart
//
// 앱 전역 BGM/효과음 재생 서비스. ending_unlocks.dart랑 같은 패턴으로 static 클래스로
// 구현해서, 화면이 몇 번을 갈아끼워져도(Navigator push/pop) 재생 중인 BGM이 안 끊기게 함.
//
// 지금은 assets/sounds/ 안에 음원 파일이 하나도 없는 상태라, 모든 재생 경로(playBgm/
// playSfx)는 "에셋이 없으면 예외를 삼키고 조용히 넘어간다"를 기본 전제로 짰음 - 나중에
// audio_ids.dart에 트랙/효과음을 추가하기 시작하면 코드 수정 없이 바로 소리가 남

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';

class AudioService {
  AudioService._();

  static const String _bgmVolumeKey = 'audio_bgm_volume_v1';
  static const String _sfxVolumeKey = 'audio_sfx_volume_v1';

  // 볼륨은 0~5단계(기본 3). main_setting_ex.png의 점 5칸이랑 그대로 맞춘 단계 수
  static const int maxVolumeStep = 5;
  static const int _defaultVolumeStep = 3;

  // playBgm에서 트랙이 바뀔 때 쓰는 크로스페이드 길이. stopBgm도 기본값으로 이걸 그대로 씀
  static const Duration _crossfadeDuration = Duration(milliseconds: 600);
  static const int _fadeSteps = 20;

  // 지금 아무 곡도 안 흐르고 있다가(outgoing이 없는 경우) 처음 소리가 나는 순간 전용 페이드인
  // 길이. 앱 켜고 나서 첫 재생(콘텐츠 경고 화면 터치 등)뿐 아니라 stopBgm 이후 다시 트는
  // 경우에도 적용됨 - "조용하다가 갑자기 트랙 전환처럼 훅 들어오는" 대신 더 부드럽게 시작하려는
  // 용도라, 호출하는 쪽에서 fadeDuration을 따로 안 넘겨도 자동으로 적용됨
  static const Duration _firstPlayFadeInDuration = Duration(milliseconds: 1500);

  // 루프 이음새 겹침 재생용. AudioIds.loopOverlapTracks에 속한 트랙은 끝나기 이만큼 전에
  // 같은 곡을 처음부터 다른 슬롯에서 틀어서 이 시간 동안 크로스페이드로 겹침 - 즉 겹침
  // 재생의 크로스페이드 길이 자체도 이 값을 그대로 씀(겹치는 구간만큼만 섞여야 하니까)
  static const Duration _loopOverlapLeadTime = Duration(seconds: 1);
  // 겹침 재생을 걸 때 쓰던 시간(wall-clock) 기준 Timer를 없애고 실제 재생 위치
  // (onPositionChanged) 기준으로 바꿈 - Timer 방식은 "트랙이 시작한 뒤 얼마나 지났는지"를
  // 페이드인 끝난 시점부터 거꾸로 추정하는 구조라, 페이드인 길이(_firstPlayFadeInDuration
  // 등)만큼 오차가 생기고, 탭이 배경으로 가서 플레이어가 일시정지돼도 시간은 계속 흘러서
  // 엉뚱한 지점에서 겹침이 발동하는 문제가 있었음. 위치 기반이면 플레이어가 실제로 멈춰있는
  // 동안엔 position 이벤트 자체가 안 오니까 이런 어긋남이 구조적으로 생기지 않음
  static StreamSubscription<Duration>? _loopOverlapPositionSub;

  static int bgmVolume = _defaultVolumeStep;
  static int sfxVolume = _defaultVolumeStep;

  static bool _isLoaded = false;

  // BGM 전용 플레이어 2개. 겉으로는 "BGM 하나가 재생된다"지만, 트랙이 바뀔 때 끊김 없이
  // 크로스페이드(두 트랙이 잠깐 동시에 들리면서 섞임)하려면 순간적으로 두 개가 동시에
  // 재생 중이어야 해서 내부적으로 둘을 번갈아 씀(핑퐁). 밖에서 보기엔 playBgm/stopBgm만
  // 있는 BGM 슬롯 하나처럼 동작함
  static final AudioPlayer _bgmPlayerA = AudioPlayer();
  static final AudioPlayer _bgmPlayerB = AudioPlayer();
  static bool _isPlayerAActive = false;
  static AudioPlayer? _activeBgmPlayer; // 크로스페이드 끝나고 현재 들리고 있는 쪽
  static String? _activeBgmTrackId;
  // 지금 재생 중인 트랙의 trackGain 값. setBgmVolume이 실시간으로 음량을 바꿀 때나
  // 페이드아웃 시작 음량을 잡을 때, 매번 AudioIds.trackGain을 다시 찾지 않고 바로 씀
  static double _activeBgmGain = 1.0;

  // 크로스페이드/페이드아웃 도중에 새 playBgm/stopBgm이 또 불리면, 먼저 돌던 페이드 루프는
  // 이 토큰이 바뀐 걸 보고 스스로 멈춤(안 그러면 두 개의 페이드가 동시에 볼륨을 건드려서
  // 꼬임)
  static int _fadeToken = 0;

  // 웹(특히 아이패드 Safari)은 사용자 제스처 없이는 오디오 재생이 막혀있어서, 첫 탭이
  // 일어나기 전까지 재생 요청이 와도 기억만 해뒀다가 unlock() 시점에 실제로 재생함
  static bool _isUnlocked = false;
  static String? _pendingBgmTrackId;

  // 탭이 백그라운드로 가거나(비활성화) AudioService가 스스로 BGM을 멈춘 건지 구분하는 값.
  // 이게 true일 때만 포그라운드 복귀 시 이어서 재생함 - 유저가 직접 stopBgm을 부른 경우까지
  // 되살리면 안 되니까
  static bool _wasPausedByLifecycle = false;

  static final _AudioLifecycleObserver _lifecycleObserver =
      _AudioLifecycleObserver();

  // 효과음은 동시에 여러 개가 겹쳐 나도 서로 끊기지 않아야 해서 AudioPool(효과음 id별로
  // 재생 전용 플레이어 여러 개를 풀로 돌려쓰는 방식)을 씀. id별로 첫 재생 때 지연 생성해서
  // 캐시해두고, 생성에 실패하면(에셋 없음 등) 캐시에서 빼서 다음 호출 때 다시 시도하게 함
  static final Map<String, Future<AudioPool>> _sfxPools = {};

  // main.dart에서 EndingUnlocks.load() 부르는 자리 근처에서 한 번만 호출하면 됨. 볼륨 값을
  // shared_preferences에서 불러오고, 앱 생명주기 감지를 등록함
  static Future<void> init() async {
    await _loadVolumes();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  static Future<void> _loadVolumes() async {
    if (_isLoaded) return;
    _isLoaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      bgmVolume = (prefs.getInt(_bgmVolumeKey) ?? _defaultVolumeStep).clamp(
        0,
        maxVolumeStep,
      );
      sfxVolume = (prefs.getInt(_sfxVolumeKey) ?? _defaultVolumeStep).clamp(
        0,
        maxVolumeStep,
      );
    } catch (e) {
      _logError('_loadVolumes', e);
    }
  }

  // 화면 전체의 첫 포인터 다운에서 한 번만 호출됨(main.dart의 Listener 참고). 이미 잠금
  // 해제됐으면 아무것도 안 함 - 여러 번 불려도 안전함
  static Future<void> unlock() async {
    if (_isUnlocked) return;
    _isUnlocked = true;
    final String? pending = _pendingBgmTrackId;
    _pendingBgmTrackId = null;
    if (pending != null) {
      await playBgm(pending);
    }
  }

  // 같은 트랙이 이미 재생 중이면 아무것도 안 함. 다른 트랙이면 크로스페이드로 교체함.
  // 아직 unlock 전이면 재생 요청만 기억해두고 실제 재생은 unlock() 시점으로 미룸
  static Future<void> playBgm(String trackId) async {
    final String? path = AudioIds.bgmTracks[trackId];
    if (path == null) return; // 등록 안 된(아직 음원이 없는) id는 조용히 무시
    if (!_isUnlocked) {
      _pendingBgmTrackId = trackId;
      return;
    }
    if (_activeBgmTrackId == trackId) return; // 이미 같은 트랙이 재생 중
    await _crossfadeToTrack(trackId, path);
  }

  // fadeDuration을 따로 받는 이유: 트랙이 바뀌는 평소 크로스페이드는 _crossfadeDuration
  // (600ms)을 쓰지만, 같은 곡의 루프 이음새를 겹쳐 재생할 때(_watchForLoopOverlap)는 겹치는
  // 구간 자체가 _loopOverlapLeadTime(1초)이라 크로스페이드 길이도 그만큼이어야 함 - 둘 다
  // 결국 "두 플레이어를 섞어서 바꿔치기한다"는 같은 동작이라 로직 자체는 재사용함
  static Future<void> _crossfadeToTrack(
    String trackId,
    String path, {
    Duration fadeDuration = _crossfadeDuration,
  }) async {
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = null;
    final int token = ++_fadeToken;
    final AudioPlayer incoming = _isPlayerAActive ? _bgmPlayerB : _bgmPlayerA;
    final AudioPlayer? outgoing = _activeBgmPlayer;
    // 나가는 트랙은 지금까지 쓰던 gain(_activeBgmGain)으로 페이드아웃해야 하고, 들어오는
    // 트랙은 자기 자신의 gain으로 페이드인해야 함 - 둘이 다른 곡이면 보정값도 서로 다를 수
    // 있어서 미리 각각 구해둠. 루프 겹침 재생이면 trackId가 같아서 두 값도 항상 같음
    final String? outgoingTrackId = _activeBgmTrackId;
    final double outgoingGain = _activeBgmGain;
    final double incomingGain = AudioIds.trackGain[trackId] ?? 1.0;
    // outgoing이 없으면(= 지금 아무 곡도 안 흐르던 상태) 첫 재생 전용 페이드인으로 바꿔치기함
    final Duration effectiveFadeDuration =
        outgoing == null ? _firstPlayFadeInDuration : fadeDuration;

    // 동시성 버그 수정: 이 트랙/플레이어를 "지금 재생 중인 것"으로 await 전에(=동기적으로)
    // 먼저 확정해둠. 예전엔 incoming.play()가 끝난 뒤에야 _activeBgmTrackId 등을 갱신했는데,
    // 그러면 play()가 끝나길 기다리는 동안(특히 웹에서 파일을 fetch하는 시간) 또 다른 playBgm
    // 호출이 들어오면 "이미 같은 트랙 재생 중" 가드가 옛날 값을 보고 통과시켜버리고, 심지어
    // 두 호출이 incoming 플레이어까지 똑같이 골라버려서 나중에 play()가 resolve되는 쪽이
    // 먼저 건 트랙을 덮어써버리는 문제가 있었음(프롤로그 pro_theme이 간헐적으로 안 들리던
    // 원인 - 챕터 선택 initState의 main_theme 요청이랑 겹쳤을 때 재현됨)
    _activeBgmTrackId = trackId;
    _activeBgmPlayer = incoming;
    _activeBgmGain = incomingGain;
    _isPlayerAActive = !_isPlayerAActive;

    try {
      await incoming.setReleaseMode(ReleaseMode.loop);
      await incoming.setVolume(0.0);
      await incoming.play(AssetSource(path));
    } catch (e) {
      _logError('playBgm($trackId)', e);
      // 재생 자체가 실패했으면, 그 사이 또 다른 호출이 끼어들지 않았을 때만(token 그대로)
      // 위에서 먼저 확정해둔 상태를 이전 값으로 되돌림 - 끼어들었으면 그 새 호출이 이미 최신
      // 상태를 들고 있을 거라 여기서 되돌리면 오히려 그걸 덮어써버림
      if (token == _fadeToken) {
        _activeBgmTrackId = outgoingTrackId;
        _activeBgmPlayer = outgoing;
        _activeBgmGain = outgoingGain;
        _isPlayerAActive = !_isPlayerAActive;
      }
      return;
    }

    // 재생이 실제로 시작되자마자(페이드가 끝나길 기다리지 않고) 위치 구독을 걸어둠 - 예전
    // Timer 방식은 페이드가 다 끝난 뒤에야 걸어서, 그 시점부터 거꾸로 "곡 길이 - 1초"를
    // 계산하다 보니 페이드인 길이만큼 통째로 어긋났었음. 위치 기준은 그 문제가 아예 없어서
    // 언제 걸든 상관없지만, 짧은 곡(겹치는 구간보다 페이드인이 긴 극단적인 경우)까지
    // 안전하게 커버하려고 가장 이른 시점에 걸어둠
    _watchForLoopOverlap(trackId, path, incoming, token);

    final double userLevel = _volumeForStep(bgmVolume);
    final double targetVolumeIncoming = userLevel * incomingGain;
    final double targetVolumeOutgoing = userLevel * outgoingGain;
    final Duration stepDuration = Duration(
      microseconds: effectiveFadeDuration.inMicroseconds ~/ _fadeSteps,
    );
    for (int i = 1; i <= _fadeSteps; i++) {
      if (token != _fadeToken) {
        // 페이드 도중에 또 다른 playBgm/stopBgm이 끼어듦 - 나가는 트랙만 바로 멈추고 빠짐
        // (들어오는 트랙은 그 새 호출이 알아서 처리함)
        await _safeStop(outgoing);
        return;
      }
      await Future.delayed(stepDuration);
      final double t = i / _fadeSteps;
      try {
        await incoming.setVolume(targetVolumeIncoming * t);
        if (outgoing != null) {
          await outgoing.setVolume(targetVolumeOutgoing * (1 - t));
        }
      } catch (e) {
        _logError('_crossfadeToTrack($trackId)', e);
        return;
      }
    }
    if (outgoing != null && token == _fadeToken) {
      await _safeStop(outgoing);
    }
  }

  // AudioIds.loopOverlapTracks에 등록된 트랙이면, 재생 길이를 구해서 player의 실제 재생
  // 위치(onPositionChanged)를 지켜보다가 "길이 - _loopOverlapLeadTime" 지점에 닿는 순간
  // 같은 트랙으로 또 한 번 _crossfadeToTrack을 걸어서 겹쳐 재생함. 그 크로스페이드가 끝나면
  // 거기서 또 다음 겹침을 지켜보는 식으로 트랙이 안 바뀌는 한 계속 이어짐. 길이를 못 구하면
  // (웹에서 메타데이터 로드 전이거나 너무 짧으면) 그냥 포기하고 player에 이미 걸려있는
  // ReleaseMode.loop 기본 반복으로 돌아감
  static Future<void> _watchForLoopOverlap(
    String trackId,
    String path,
    AudioPlayer player,
    int token,
  ) async {
    if (!AudioIds.loopOverlapTracks.contains(trackId)) return;
    Duration? duration;
    try {
      duration = await player.getDuration();
    } catch (e) {
      _logError('_watchForLoopOverlap($trackId)', e);
      return;
    }
    // 길이를 못 구했거나 겹치는 구간보다 짧은(비정상) 트랙이면 포기하고 기본
    // ReleaseMode.loop 반복으로 둠
    if (duration == null || duration <= _loopOverlapLeadTime) return;
    // getDuration()을 기다리는 사이 다른 크로스페이드가 이미 끼어들었으면 더 볼 것도 없음
    if (token != _fadeToken) return;

    final Duration threshold = duration - _loopOverlapLeadTime;
    bool hasFired = false;
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = player.onPositionChanged.listen((
      Duration position,
    ) async {
      // 한 바퀴에서 두 번 걸리지 않게 막는 플래그. 기준을 넘은 뒤에도 position 이벤트가
      // 몇 번 더 올 수 있어서 필요함
      if (hasFired || position < threshold) return;
      hasFired = true;
      await _loopOverlapPositionSub?.cancel();
      _loopOverlapPositionSub = null;
      // 그 사이 다른 곡으로 바뀌었거나 stopBgm이 불렸으면(토큰이 달라짐) 겹침을 걸지 않음 -
      // 이미 떠난 트랙 위에 겹쳐 틀면 안 되니까
      if (token != _fadeToken || _activeBgmTrackId != trackId) return;
      if (kDebugMode) {
        debugPrint(
          '[AudioService] 루프 겹침 시작: trackId=$trackId position=$position '
          'duration=$duration at=${DateTime.now()}',
        );
      }
      // 나가는 슬롯(지금 이 player)이 끝에 닿아도 스스로 되감지 않게 stop 모드로 바꿔둠 -
      // 크로스페이드가 끝나면 아래 _crossfadeToTrack이 알아서 명시적으로 stop()을 부름
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        _logError('_watchForLoopOverlap($trackId) setReleaseMode', e);
      }
      await _crossfadeToTrack(trackId, path, fadeDuration: _loopOverlapLeadTime);
    });
  }

  // 재생 중인 BGM을 fadeOut 시간 동안 서서히 줄이면서 멈춤. 재생 중이 아니면 아무것도 안 함
  static Future<void> stopBgm({Duration fadeOut = _crossfadeDuration}) async {
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null || _activeBgmTrackId == null) return;
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = null;
    final int token = ++_fadeToken;
    _activeBgmTrackId = null;
    _activeBgmPlayer = null;

    final double startVolume = _volumeForStep(bgmVolume) * _activeBgmGain;
    final int steps = _fadeSteps;
    final Duration stepDuration = Duration(
      microseconds: fadeOut.inMicroseconds ~/ steps,
    );
    for (int i = 1; i <= steps; i++) {
      if (token != _fadeToken) return; // 그 사이 새 playBgm이 이 플레이어를 이미 이어받음
      await Future.delayed(stepDuration);
      try {
        await player.setVolume(startVolume * (1 - i / steps));
      } catch (e) {
        _logError('stopBgm', e);
        return;
      }
    }
    if (token == _fadeToken) {
      await _safeStop(player);
    }
  }

  static Future<void> _safeStop(AudioPlayer? player) async {
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      _logError('_safeStop', e);
    }
  }

  // 효과음 하나 재생. 동시에 여러 번 불려도(예: 연속 탭) 서로 안 끊기고 겹쳐서 남
  static Future<void> playSfx(String sfxId) async {
    if (sfxVolume <= 0) return; // 0단계(무음)면 재생 시도 자체를 안 함
    final String? path = AudioIds.sfxClips[sfxId];
    if (path == null) return; // 등록 안 된(아직 음원이 없는) id는 조용히 무시
    try {
      final AudioPool pool = await _poolFor(sfxId, path);
      await pool.start(volume: _volumeForStep(sfxVolume));
    } catch (e) {
      _logError('playSfx($sfxId)', e);
      // 실패한 풀은 캐시에서 빼서, 나중에 에셋이 생긴 뒤 다시 호출하면 재시도하게 함
      _sfxPools.remove(sfxId);
    }
  }

  static Future<AudioPool> _poolFor(String sfxId, String path) {
    return _sfxPools.putIfAbsent(
      sfxId,
      () => AudioPool.createFromAsset(path: path, maxPlayers: 4),
    );
  }

  // bgmVolume 단계를 바꾸고 저장함. 지금 BGM이 재생 중이면 그 자리에서 바로 음량을 반영함
  static Future<void> setBgmVolume(int step) async {
    final int clamped = step.clamp(0, maxVolumeStep);
    if (clamped == bgmVolume) return;
    bgmVolume = clamped;
    await _persistVolume(_bgmVolumeKey, bgmVolume);
    final AudioPlayer? player = _activeBgmPlayer;
    if (player != null) {
      try {
        await player.setVolume(_volumeForStep(bgmVolume) * _activeBgmGain);
      } catch (e) {
        _logError('setBgmVolume', e);
      }
    }
  }

  // sfxVolume 단계를 바꾸고 저장함. 효과음은 재생 순간에 그때그때 볼륨을 적용하는 구조라
  // 재생 중인 걸 realtime으로 조절할 필요는 없음
  static Future<void> setSfxVolume(int step) async {
    final int clamped = step.clamp(0, maxVolumeStep);
    if (clamped == sfxVolume) return;
    sfxVolume = clamped;
    await _persistVolume(_sfxVolumeKey, sfxVolume);
  }

  static Future<void> _persistVolume(String key, int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      _logError('_persistVolume($key)', e);
    }
  }

  static double _volumeForStep(int step) =>
      step <= 0 ? 0.0 : step / maxVolumeStep;

  static Future<void> _handleLifecyclePause() async {
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null) return;
    try {
      if (player.state == PlayerState.playing) {
        _wasPausedByLifecycle = true;
        await player.pause();
      }
    } catch (e) {
      _logError('_handleLifecyclePause', e);
    }
  }

  static Future<void> _handleLifecycleResume() async {
    if (!_wasPausedByLifecycle) return;
    _wasPausedByLifecycle = false;
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null) return;
    try {
      await player.resume();
    } catch (e) {
      _logError('_handleLifecycleResume', e);
    }
  }

  static void _logError(String where, Object error) {
    if (kDebugMode) {
      debugPrint('[AudioService] $where 실패: $error');
    }
  }
}

// AudioService는 static 전용 클래스라 WidgetsBindingObserver를 직접 구현할 수 없어서,
// 등록용으로만 쓰는 작은 private 클래스를 따로 둠. init()에서 딱 한 번 등록됨
class _AudioLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        AudioService._handleLifecyclePause();
        break;
      case AppLifecycleState.resumed:
        AudioService._handleLifecycleResume();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }
}
