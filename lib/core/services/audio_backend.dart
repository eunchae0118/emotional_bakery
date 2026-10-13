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

  // 곧 재생할 BGM을 미리 디코딩만 해둠(재생은 안 함) - 챕터 진입 화면에서 다음에 나올
  // 곡을 한 발 먼저 당겨두면, 실제로 playBgm이 불릴 때 디코딩 대기 없이 바로 소리가
  // 남. 웹 백엔드는 디코딩 자체가 시간이 걸려서 의미가 있고, 네이티브 백엔드는 할 일이
  // 없어서 아무것도 안 해도 됨
  void prefetchBgm(String path);

  // 포인터 이벤트(사용자 제스처)마다 호출됨 - 가벼워야 함. 지금 재생 "되어야 하는" 트랙이
  // 뭔지는 백엔드가 이미 playBgm 호출 시점에 자기 내부 상태로 커밋해둬서, 여기서 따로 안
  // 넘겨받아도 됨(웹 구현 쪽은 네이티브 DOM 리스너에서도 같은 복구 로직을 타야 해서,
  // 외부에서 매번 값을 받는 방식 대신 백엔드가 스스로 기억한 값을 쓰게 함).
  //
  // canAttemptResume: 이 호출을 일으킨 이벤트가 iOS에서 "사용자 활성화"로 인정되는
  // 종류(pointerup/touchend/click)면 true, 아니면(pointerdown처럼 iOS가 활성화로 안
  // 쳐주는 이벤트) false - resume()은 활성화로 인정되는 이벤트에서만 시도해야 함
  void onUserGesture({required bool canAttemptResume});

  // 탭/앱이 백그라운드로 갈 때·돌아올 때
  Future<void> pauseForLifecycle();
  Future<void> resumeForLifecycle();

  // 아래 셋은 화면 진단 패널(audio_diagnostics_overlay.dart, ?audiolog=1일 때만 보임) 전용.
  // 비웹 플랫폼(AudioPlayersBackend)에선 진단 패널 자체가 의미 없어서 전부 간단한 더미로
  // 구현해도 됨

  // 터치할 때마다 찍는 로그용으로 쓰는 아주 짧은 상태 한 단어(웹이면 AudioContext.state,
  // 그 외엔 "n/a" 같은 값)
  String get audioStateLabel;

  // 진단 패널 상태 줄에 쓰는 좀 더 자세한 한 줄 요약(state/currentTime/sampleRate/
  // 활성 트랙/소스 유무/게인 값 등)
  String debugStatus();

  // "비프 테스트" 버튼 전용. 기존 BGM 재생 경로(디코딩/크로스페이드)를 아예 안 거치고
  // 순수하게 짧은 테스트음만 내서, 오디오 출력 자체가 막혔는지 vs mp3 재생 경로만
  // 문제인지 구분하는 용도
  Future<void> playDiagnosticBeep();
}
