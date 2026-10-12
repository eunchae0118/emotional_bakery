// lib/core/services/audio_service.dart
//
// 앱 전역 BGM/효과음 재생 서비스. ending_unlocks.dart랑 같은 패턴으로 static 클래스로
// 구현해서, 화면이 몇 번을 갈아끼워져도(Navigator push/pop) 재생 중인 BGM이 안 끊기게 함.
//
// 실제 오디오 엔진 작업(크로스페이드, 재생/정지)은 AudioBackend(audio_backend.dart)한테
// 맡기고, 여기는 "뭘 재생해야 하는지"(trackId 장부, 볼륨 단계, shared_preferences 저장)만
// 들고 있음 - 플랫폼별 구현(웹은 Web Audio API, 그 외는 audioplayers)은
// audio_backend_factory.dart가 조건부로 골라줌. (업데이트: 원래 audioplayers_web 기반
// 하나로만 돼있었는데, iOS Safari에서 HTMLAudioElement.volume을 못 바꾸고 멈췄다 다시
// play()하면 거부될 수 있는 문제가 있어서 Web Audio API 기반으로 갈아끼움)
//
// 지금은 assets/sounds/ 안에 음원 파일이 하나도 없는 상태라, 모든 재생 경로(playBgm/
// playSfx)는 "에셋이 없으면 예외를 삼키고 조용히 넘어간다"를 기본 전제로 짰음 - 나중에
// audio_ids.dart에 트랙/효과음을 추가하기 시작하면 코드 수정 없이 바로 소리가 남

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_backend.dart';
import 'package:emotional_bakery/core/services/audio_backend_factory.dart';
import 'package:emotional_bakery/core/services/audio_log.dart';

class AudioService {
  AudioService._();

  static const String _bgmVolumeKey = 'audio_bgm_volume_v1';
  static const String _sfxVolumeKey = 'audio_sfx_volume_v1';

  // 볼륨은 0~5단계(기본 3). main_setting_ex.png의 점 5칸이랑 그대로 맞춘 단계 수
  static const int maxVolumeStep = 5;
  static const int _defaultVolumeStep = 3;

  // playBgm에서 트랙이 바뀔 때 쓰는 크로스페이드 길이. stopBgm도 기본값으로 이걸 그대로 씀.
  // (첫 재생 전용 더 긴 페이드인은 백엔드 내부에서 알아서 처리함 - outgoing이 없으면
  // 자동으로 더 긴 값으로 바꿔치기함)
  static const Duration _crossfadeDuration = Duration(milliseconds: 600);

  static int bgmVolume = _defaultVolumeStep;
  static int sfxVolume = _defaultVolumeStep;

  static bool _isLoaded = false;

  // 실제 재생을 맡는 백엔드 - 플랫폼에 따라 Web Audio API 구현이나 audioplayers 구현이 들어옴
  static final AudioBackend _backend = createAudioBackend();

  // 지금 재생 "되어야 하는" 트랙(장부). 화면들이 playBgm을 부를 때 "같은 트랙이면 무시"
  // 가드로 씀
  static String? _activeBgmTrackId;
  // 재생을 시도했지만 아직 "실제로 들리기 시작했다"는 확인을 못 받은 트랙. null이 아니면
  // onUserGesture가 매 터치마다 되살리기를 시도함 - 예전엔 "unlock 전 대기"만 이 자리에
  // 썼는데, 이제는 iOS가 오디오 세션을 다시 잠가서 재생이 조용히 실패하는 경우까지 전부
  // 이 하나의 메커니즘으로 처리함
  static String? _pendingBgmTrackId;

  // 탭이 백그라운드로 갔다가(비활성화) 돌아왔을 때만 되살리기를 시도하게 구분하는 값
  static bool _wasPausedByLifecycle = false;

  static final _AudioLifecycleObserver _lifecycleObserver =
      _AudioLifecycleObserver();

  // main.dart에서 EndingUnlocks.load() 부르는 자리 근처에서 한 번만 호출하면 됨. 볼륨 값을
  // shared_preferences에서 불러오고, 앱 생명주기 감지를 등록함
  static Future<void> init() async {
    await _loadVolumes();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    // 첫 재생이 실제로 나기 전에도 마스터 볼륨이 저장된 값으로 미리 맞춰져 있게 함
    _backend.setBgmLevel(_volumeForStep(bgmVolume), 1.0);
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
      logAudioError('_loadVolumes', e);
    }
  }

  // 같은 트랙이 이미 재생 중(장부상)이면 아무것도 안 함. 다른 트랙이면 백엔드한테 크로스페이드
  // 재생을 맡김 - 아직 오디오가 실제로 안 풀린 상태거나(웹) 일시적으로 실패하면 백엔드가
  // false를 돌려주고, 그러면 보류 상태로 남겨둬서 다음 onUserGesture에서 다시 시도함
  static Future<void> playBgm(String trackId) async {
    final String? path = AudioIds.bgmTracks[trackId];
    if (path == null) return; // 등록 안 된(아직 음원이 없는) id는 조용히 무시
    if (_activeBgmTrackId == trackId) return; // 이미 같은 트랙이 재생 중(장부 기준)
    _activeBgmTrackId = trackId;
    _pendingBgmTrackId = trackId; // 재생 시도 전에 먼저 "아직 확인 안 됨"으로 표시해둠
    final double trackGain = AudioIds.trackGain[trackId] ?? 1.0;
    final bool started = await _backend.playBgm(
      trackId: trackId,
      path: path,
      trackGain: trackGain,
      bgmLevel: _volumeForStep(bgmVolume),
      fadeDuration: _crossfadeDuration,
    );
    if (started && _pendingBgmTrackId == trackId) {
      _pendingBgmTrackId = null;
    }
    // 실패했으면(started==false) _pendingBgmTrackId가 그대로 남아서, 다음 터치에서
    // onUserGesture가 자동으로 다시 시도함
  }

  // 재생 중인 BGM을 멈춤(백엔드가 fadeOut 동안 서서히 줄임). 재생 중이 아니면 아무것도 안 함
  static Future<void> stopBgm({
    Duration fadeOut = _crossfadeDuration,
  }) async {
    if (_activeBgmTrackId == null) return;
    _activeBgmTrackId = null;
    _pendingBgmTrackId = null;
    await _backend.stopBgm(fadeOut);
  }

  // 효과음 하나 재생. 동시에 여러 번 불려도(예: 연속 탭) 서로 안 끊기고 겹쳐서 남
  static Future<void> playSfx(String sfxId) async {
    if (sfxVolume <= 0) return; // 0단계(무음)면 재생 시도 자체를 안 함
    final String? path = AudioIds.sfxClips[sfxId];
    if (path == null) return; // 등록 안 된(아직 음원이 없는) id는 조용히 무시
    await _backend.playSfx(path: path, sfxLevel: _volumeForStep(sfxVolume));
  }

  // main.dart의 _AudioUnlockGate가 포인터 이벤트(사용자 제스처)마다 불러줌. 가벼워야 해서
  // 여기선 그냥 백엔드로 그대로 넘기기만 함 - "지금 뭐가 재생되어야 하는지"는 백엔드가
  // playBgm 호출 시점에 이미 자기 내부 장부로 들고 있어서 따로 안 넘겨줘도 됨.
  // canAttemptResume: pointerup/click처럼 iOS가 사용자 활성화로 인정하는 이벤트면 true,
  // pointerdown처럼 인정 안 하는 이벤트면 false - 호출하는 쪽(main.dart)이 결정해서 넘김
  static void onUserGesture({required bool canAttemptResume}) {
    _backend.onUserGesture(canAttemptResume: canAttemptResume);
  }

  // bgmVolume 단계를 바꾸고 저장함. 지금 BGM이 재생 중이면 그 자리에서 바로 음량을 반영함
  static Future<void> setBgmVolume(int step) async {
    final int clamped = step.clamp(0, maxVolumeStep);
    if (clamped == bgmVolume) return;
    bgmVolume = clamped;
    await _persistVolume(_bgmVolumeKey, bgmVolume);
    final double trackGain = _activeBgmTrackId == null
        ? 1.0
        : (AudioIds.trackGain[_activeBgmTrackId!] ?? 1.0);
    _backend.setBgmLevel(_volumeForStep(bgmVolume), trackGain);
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
      logAudioError('_persistVolume($key)', e);
    }
  }

  static double _volumeForStep(int step) =>
      step <= 0 ? 0.0 : step / maxVolumeStep;

  static Future<void> _handleLifecyclePause() async {
    _wasPausedByLifecycle = true;
    await _backend.pauseForLifecycle();
  }

  static Future<void> _handleLifecycleResume() async {
    if (!_wasPausedByLifecycle) return;
    _wasPausedByLifecycle = false;
    await _backend.resumeForLifecycle();
    // 포그라운드 복귀는 사용자 제스처가 아니라서 (특히 웹에서) resume이 거부될 수 있음 -
    // 실패해도 여기선 그냥 넘어가고, 재생 중이었어야 할 트랙을 보류 상태로 표시해둬서
    // 다음 터치(onUserGesture)에서 확실히 다시 시도되게 함
    if (_activeBgmTrackId != null) {
      _pendingBgmTrackId = _activeBgmTrackId;
    }
  }

  // 아래 넷은 화면 진단 패널(audio_diagnostics_overlay.dart, ?audiolog=1일 때만 보임)
  // 전용. 평소 호출 경로(화면들의 playBgm 등)랑은 무관하고, 패널의 버튼/상태 줄이 직접 씀

  // 터치할 때마다 찍는 로그 한 줄에 넣는 짧은 상태 값
  static String get audioStateLabel => _backend.audioStateLabel;

  // 패널 상태 줄(1초마다 갱신)에 쓰는 한 줄 요약
  static String debugAudioStatus() => _backend.debugStatus();

  // "비프 테스트" 버튼 전용
  static Future<void> playDiagnosticBeep() => _backend.playDiagnosticBeep();

  // "음악 재시작" 버튼 전용. 지금 재생 중이어야 할 트랙이 있으면 그걸, 없으면
  // main_theme을 기본값으로 돌려줌
  static String currentOrDefaultBgmTrackId() =>
      _activeBgmTrackId ?? AudioIds.mainTheme;
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
