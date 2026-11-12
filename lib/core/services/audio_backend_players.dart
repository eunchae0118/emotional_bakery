// lib/core/services/audio_backend_players.dart
//
// 웹이 아닌 플랫폼(안드로이드/iOS 네이티브 앱/데스크톱)용 AudioBackend 구현. audioplayers
// 패키지의 네이티브 플레이어를 그대로 씀 - 예전 audio_service.dart에 있던 크로스페이드/루프
// 겹침 재생 로직을 거의 그대로 옮겨왔음(동작은 그대로, AudioService의 static 메서드였던 걸
// 이 클래스의 인스턴스 메서드로 옮긴 것뿐). 이 플랫폼들은 iOS Safari류의 "요소가 멈췄다가
// 다시 재생될 때 거부되는" 문제가 없어서(네이티브 MediaPlayer/AVPlayer 기반), onUserGesture는
// 할 일이 없음

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_backend.dart';
import 'package:emotional_bakery/core/services/audio_log.dart';

AudioBackend createAudioBackend() => AudioPlayersBackend();

class AudioPlayersBackend implements AudioBackend {
  static const int _fadeSteps = 20;

  // 지금 아무 곡도 안 흐르고 있다가 처음 소리가 나는 순간 전용 페이드인 길이. 트랙 전환
  // 크로스페이드(바깥에서 넘어오는 fadeDuration)보다 더 길게 잡아서 부드럽게 시작하게 함
  static const Duration _firstPlayFadeInDuration = Duration(milliseconds: 1500);

  // 루프 이음새 겹침 재생용. AudioIds.loopOverlapTracks에 속한 트랙은 끝나기 이만큼 전에
  // 같은 곡을 처음부터 다른 슬롯에서 틀어서 이 시간 동안 크로스페이드로 겹침
  static const Duration _loopOverlapLeadTime = Duration(seconds: 1);
  StreamSubscription<Duration>? _loopOverlapPositionSub;

  // BGM 전용 플레이어 2개. 트랙이 바뀔 때 끊김 없이 크로스페이드하려면 순간적으로 두 개가
  // 동시에 재생 중이어야 해서 내부적으로 둘을 번갈아 씀(핑퐁)
  final AudioPlayer _bgmPlayerA = AudioPlayer();
  final AudioPlayer _bgmPlayerB = AudioPlayer();
  bool _isPlayerAActive = false;
  AudioPlayer? _activeBgmPlayer;
  String? _activeBgmTrackId;
  double _activeBgmGain = 1.0;
  int _fadeToken = 0;

  final Map<String, Future<AudioPool>> _sfxPools = {};

  @override
  Future<bool> playBgm({
    required String trackId,
    required String path,
    required double trackGain,
    required double bgmLevel,
    required Duration fadeDuration,
  }) async {
    if (_activeBgmTrackId == trackId) return true; // 이미 같은 트랙이 재생 중
    return _crossfadeToTrack(trackId, path, trackGain, bgmLevel, fadeDuration);
  }

  Future<bool> _crossfadeToTrack(
    String trackId,
    String path,
    double trackGain,
    double bgmLevel,
    Duration fadeDuration,
  ) async {
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = null;
    final int token = ++_fadeToken;
    final AudioPlayer incoming = _isPlayerAActive ? _bgmPlayerB : _bgmPlayerA;
    final AudioPlayer? outgoing = _activeBgmPlayer;
    final String? outgoingTrackId = _activeBgmTrackId;
    final double outgoingGain = _activeBgmGain;
    // outgoing이 없으면(지금 아무 곡도 안 흐르던 상태) 첫 재생 전용 페이드인으로 바꿔치기함
    final Duration effectiveFadeDuration = outgoing == null
        ? _firstPlayFadeInDuration
        : fadeDuration;

    _activeBgmTrackId = trackId;
    _activeBgmPlayer = incoming;
    _activeBgmGain = trackGain;
    _isPlayerAActive = !_isPlayerAActive;

    try {
      await incoming.setReleaseMode(ReleaseMode.loop);
      await incoming.setVolume(0.0);
      await incoming.play(AssetSource(path));
    } catch (e) {
      logAudioError('AudioPlayersBackend.playBgm($trackId)', e);
      if (token == _fadeToken) {
        _activeBgmTrackId = outgoingTrackId;
        _activeBgmPlayer = outgoing;
        _activeBgmGain = outgoingGain;
        _isPlayerAActive = !_isPlayerAActive;
      }
      return false;
    }

    _watchForLoopOverlap(trackId, path, incoming, token);

    final double targetVolumeIncoming = bgmLevel * trackGain;
    final double targetVolumeOutgoing = bgmLevel * outgoingGain;
    final Duration stepDuration = Duration(
      microseconds: effectiveFadeDuration.inMicroseconds ~/ _fadeSteps,
    );
    for (int i = 1; i <= _fadeSteps; i++) {
      if (token != _fadeToken) {
        await _safeStop(outgoing);
        return true;
      }
      await Future.delayed(stepDuration);
      final double t = i / _fadeSteps;
      try {
        await incoming.setVolume(targetVolumeIncoming * t);
        if (outgoing != null) {
          await outgoing.setVolume(targetVolumeOutgoing * (1 - t));
        }
      } catch (e) {
        logAudioError('AudioPlayersBackend._crossfadeToTrack($trackId)', e);
        return true;
      }
    }
    if (outgoing != null && token == _fadeToken) {
      await _safeStop(outgoing);
    }
    return true;
  }

  Future<void> _watchForLoopOverlap(
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
      logAudioError('AudioPlayersBackend._watchForLoopOverlap($trackId)', e);
      return;
    }
    if (duration == null || duration <= _loopOverlapLeadTime) return;
    if (token != _fadeToken) return;

    final Duration threshold = duration - _loopOverlapLeadTime;
    bool hasFired = false;
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = player.onPositionChanged.listen((
      Duration position,
    ) async {
      if (hasFired || position < threshold) return;
      hasFired = true;
      await _loopOverlapPositionSub?.cancel();
      _loopOverlapPositionSub = null;
      if (token != _fadeToken || _activeBgmTrackId != trackId) return;
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        logAudioError(
          'AudioPlayersBackend._watchForLoopOverlap($trackId) setReleaseMode',
          e,
        );
      }
      await _crossfadeToTrack(
        trackId,
        path,
        _activeBgmGain,
        _lastBgmLevel,
        _loopOverlapLeadTime,
      );
    });
  }

  // 겹침 재생이 스스로 자기 자신을 다시 트는 경로(_watchForLoopOverlap)에선 바깥에서
  // bgmLevel을 새로 안 넘겨주기 때문에, setBgmLevel이 마지막으로 받은 값을 기억해뒀다가 씀
  double _lastBgmLevel = 0.6;

  @override
  Future<void> stopBgm(Duration fadeOut) async {
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null || _activeBgmTrackId == null) return;
    _loopOverlapPositionSub?.cancel();
    _loopOverlapPositionSub = null;
    final int token = ++_fadeToken;
    _activeBgmTrackId = null;
    _activeBgmPlayer = null;

    final double startVolume = _lastBgmLevel * _activeBgmGain;
    const int steps = _fadeSteps;
    final Duration stepDuration = Duration(
      microseconds: fadeOut.inMicroseconds ~/ steps,
    );
    for (int i = 1; i <= steps; i++) {
      if (token != _fadeToken) return;
      await Future.delayed(stepDuration);
      try {
        await player.setVolume(startVolume * (1 - i / steps));
      } catch (e) {
        logAudioError('AudioPlayersBackend.stopBgm', e);
        return;
      }
    }
    if (token == _fadeToken) {
      await _safeStop(player);
    }
  }

  Future<void> _safeStop(AudioPlayer? player) async {
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      logAudioError('AudioPlayersBackend._safeStop', e);
    }
  }

  @override
  void setBgmLevel(double bgmLevel, double trackGain) {
    _lastBgmLevel = bgmLevel;
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null) return;
    player.setVolume(bgmLevel * trackGain).catchError((e) {
      logAudioError('AudioPlayersBackend.setBgmLevel', e);
    });
  }

  // playbackRate는 받아만 두고 씀 - AudioPool.start()에 재생 속도를 넘길 방법이 없어서
  // playBlip이랑 동일한 이유로 그냥 무시함(supportsSfxPlaybackRate가 false라서 호출하는
  // 쪽도 애초에 흔들린 값을 안 넘겨줌)
  @override
  Future<void> playSfx({
    required String path,
    required double sfxLevel,
    double playbackRate = 1.0,
  }) async {
    if (sfxLevel <= 0) return;
    try {
      final AudioPool pool = await _poolFor(path);
      await pool.start(volume: sfxLevel);
    } catch (e) {
      logAudioError('AudioPlayersBackend.playSfx', e);
      _sfxPools.remove(path);
    }
  }

  Future<AudioPool> _poolFor(String path) {
    return _sfxPools.putIfAbsent(
      path,
      () => AudioPool.createFromAsset(path: path, maxPlayers: 4),
    );
  }

  // 대사 블립 전용 재생. audioplayers의 AudioPool.start()는 재생 속도를 받는 파라미터가
  // 없어서 playbackRate는 그냥 무시함(supportsSfxPlaybackRate가 false라서 호출하는 쪽도
  // 애초에 흔들린 값을 안 넘겨줌 - 여기선 받아만 두고 씀)
  @override
  Future<void> playBlip({
    required String path,
    required double sfxLevel,
    required double playbackRate,
  }) async {
    if (sfxLevel <= 0) return;
    try {
      final AudioPool pool = await _poolFor(path);
      await pool.start(volume: sfxLevel);
    } catch (e) {
      logAudioError('AudioPlayersBackend.playBlip', e);
      _sfxPools.remove(path);
    }
  }

  // AudioPool은 지금 재생 중인 개별 인스턴스를 밖에서 즉시 멈추는 API가 없음(maxPlayers
  // 개수만큼 내부적으로 돌려쓸 뿐, 핸들을 안 돌려줌) - 그래서 네이티브에선 못 끊고 그냥
  // 둠. 블립 길이가 0.1초 미만이라 끝까지 울려도 거슬릴 정도는 아님
  @override
  void stopBlip() {}

  @override
  bool get supportsSfxPlaybackRate => false;

  // AudioPool.createFromAsset가 내부적으로 에셋을 미리 로드해두므로, 재생 전에 한 번
  // 미리 만들어두면 첫 재생 지연을 줄일 수 있음
  @override
  void prefetchSfx(String path) {
    unawaited(
      _poolFor(path).catchError((Object e) {
        throw e;
      }),
    );
  }

  // 네이티브 플레이어는 play() 호출 시점에 그때그때 에셋을 읽어서 재생하고, 웹처럼
  // fetch+decodeAudioData 같은 별도의 느린 디코딩 단계가 없어서 미리 당겨둘 게 없음
  @override
  void prefetchBgm(String path) {}

  // 네이티브 플랫폼은 요소 재잠금 문제가 없어서 할 일이 없음
  @override
  void onUserGesture({required bool canAttemptResume}) {}

  @override
  Future<void> pauseForLifecycle() async {
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null) return;
    try {
      if (player.state == PlayerState.playing) {
        await player.pause();
      }
    } catch (e) {
      logAudioError('AudioPlayersBackend.pauseForLifecycle', e);
    }
  }

  @override
  Future<void> resumeForLifecycle() async {
    final AudioPlayer? player = _activeBgmPlayer;
    if (player == null) return;
    try {
      await player.resume();
    } catch (e) {
      logAudioError('AudioPlayersBackend.resumeForLifecycle', e);
    }
  }

  // 화면 진단 패널은 웹(?audiolog=1)에서만 뜨는 기능이라 이 플랫폼에선 의미가 없음 -
  // 그냥 아무 영향 없는 더미로 구현해둠
  @override
  String get audioStateLabel => 'n/a(native)';

  @override
  String debugStatus() =>
      'native backend - activeTrackId=${_activeBgmTrackId ?? "-"}';

  @override
  Future<void> playDiagnosticBeep() async {}
}
