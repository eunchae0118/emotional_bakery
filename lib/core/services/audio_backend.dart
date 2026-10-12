// lib/core/services/audio_backend.dart
//
// AudioService가 실제 오디오 엔진 작업(크로스페이드, 재생/정지, 되살리기)을 맡기는 대상.
// 플랫폼마다 구현이 다름 - 웹은 Web Audio API(AudioContext) 기반(audio_backend_web.dart),
// 그 외(안드로이드/iOS 네이티브/데스크톱)는 기존 audioplayers 기반(audio_backend_players.dart)
// 을 그대로 씀. 어느 쪽을 쓸지는 audio_backend_factory.dart의 조건부 export가 고름.
//
// AudioService는 "뭘 재생해야 하는지"(trackId, 볼륨 단계, trackGain)만 들고 있고, "어떻게
// 재생하는지"는 전부 이 인터페이스 뒤로 숨김 - 그래서 화면 쪽 호출 코드(playBgm 등)는 플랫폼이
// 뭐든 하나도 안 바뀜

abstract class AudioBackend {
  // BGM 트랙을 trackGain/bgmLevel이 반영된 음량으로 크로스페이드 재생함. fadeDuration은
  // 트랙 전환용 기본값(바깥에서 넘겨줌 - 첫 재생이면 더 긴 값을 넘겨받을 수도 있음).
  // 재생이 실제로 "들릴 수 있는 상태"로 시작됐으면 true, 아니면(예: 아직 사용자 제스처로
  // 안 풀려서 보류됐으면) false를 돌려줌 - AudioService가 false면 보류 상태로 기억해뒀다가
  // 다음 onUserGesture에서 다시 시도함
  Future<bool> playBgm({
    required String trackId,
    required String path,
    required double trackGain,
    required double bgmLevel,
    required Duration fadeDuration,
  });

  // 재생 중인 BGM을 fadeOut 동안 서서히 줄이면서 멈춤
  Future<void> stopBgm(Duration fadeOut);

  // 사용자 볼륨 단계가 바뀔 때 호출 - 지금 재생 중인 트랙에 바로 반영함
  void setBgmLevel(double bgmLevel, double trackGain);

  // 효과음 1회 재생(동시에 여러 번 불려도 서로 안 끊김)
  Future<void> playSfx({required String path, required double sfxLevel});

  // 포인터 다운(사용자 제스처)마다 호출됨 - 가벼워야 함. activeTrackId는 지금 재생 중이어야
  // 하는 트랙(없으면 null), path/trackGain/bgmLevel은 그 트랙을 되살릴 때 바로 쓸 값.
  // 백엔드가 자기 내부 상태(예: AudioContext.state)를 보고 실제로 안 들리고 있으면
  // 알아서 되살림 - 정상 재생 중이면 아무 일도 안 해야 함(터치마다 재시작되면 안 됨)
  void onUserGesture({
    required String? activeTrackId,
    required String? activePath,
    required double trackGain,
    required double bgmLevel,
  });

  // 탭/앱이 백그라운드로 갈 때·돌아올 때
  Future<void> pauseForLifecycle();
  Future<void> resumeForLifecycle();
}
