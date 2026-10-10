// lib/core/constants/audio_ids.dart
//
// BGM 트랙/효과음 id랑 실제 에셋 경로를 한 곳에 모아둔 파일. sfxClips는 아직 효과음 파일이
// 하나도 없어서 비어있는데, AudioService.playBgm/playSfx가 등록 안 된 id로 불려도 조용히
// 무시하게 돼있어서 비어있는 채로 둬도 앱은 평소처럼 동작함. 나중에 효과음 넣을 때 여기
// 한 줄만 추가하면 바로 재생 가능함
//
// 주의: 여기 적는 경로는 Image.asset('assets/images/...')처럼 'assets/' 접두사를 붙이면 안
// 됨. audioplayers의 AssetSource는 기본 prefix로 'assets/'를 자기가 알아서 붙이기 때문에,
// 여기선 'sounds/bgm_main.mp3'처럼 그 뒤쪽 경로만 적어야 함(앞에 'assets/'를 또 붙이면
// 'assets/assets/...'를 찾아서 로드 실패함)

class AudioIds {
  AudioIds._();

  // BGM 트랙 id. 문자열을 직접 여기저기 타이핑하는 대신 이 상수로 참조하면 오타로
  // 조용히 무음 처리되는 일을 막을 수 있음
  static const String mainTheme = 'main_theme';
  static const String proTheme = 'pro_theme';
  static const String streetTheme = 'street_theme';

  // BGM 트랙 id -> assets/sounds/ 안의 파일 경로('assets/' 뺀 상대 경로).
  // 예: 'main_menu': 'sounds/bgm_main_menu.mp3'
  static const Map<String, String> bgmTracks = {
    mainTheme: 'sounds/main_theme.mp3', // 시작 화면/챕터 선택/엔딩보기/빵집
    proTheme: 'sounds/pro_theme.mp3', // 프롤로그 본편(GamePlayScreen isPrologue)
    streetTheme: 'sounds/street_theme.mp3', // 골목길(TutorialScreen)
  };

  // 트랙별 음량 보정값(기본 1.0). AudioService가 실제 재생 음량을 "사용자 볼륨 단계 x
  // 이 값"으로 계산함 - 곡마다 원본 음원 자체의 체감 크기가 달라서, 나중에 들어보고 특정
  // 곡만 유독 크거나 작으면 숫자만 바꿔서 맞추면 됨(1.0보다 작으면 작게, 크면 크게)
  static const Map<String, double> trackGain = {
    mainTheme: 1.0,
    proTheme: 1.0,
    streetTheme: 1.0,
  };

  // 루프 이음새 겹침 재생을 켤 트랙 id 집합. 여기 들어있는 트랙은 재생 길이를 구할 수
  // 있으면 끝나기 약 1초 전에 같은 곡을 처음부터 다른 슬롯에서 틀어서 크로스페이드로
  // 겹쳐지게 함(AudioService._scheduleLoopOverlap 참고) - 곡이 짧아서 반복 이음새가
  // 티 나는 걸 완화하려는 용도. 지금은 등록된 3곡 다 켜둠
  static const Set<String> loopOverlapTracks = {
    mainTheme,
    proTheme,
    streetTheme,
  };

  // 효과음 id -> assets/sounds/ 안의 파일 경로('assets/' 뺀 상대 경로).
  // 예: 'button_tap': 'sounds/sfx_button_tap.mp3'
  static const Map<String, String> sfxClips = {};

  // 대사 한 줄 넘길 때 울릴 효과음 id. sfxClips에 같은 키로 등록하기 전까지는 조용히 무시됨
  static const String dialogueAdvance = 'dialogue_advance';

  // 설정 메뉴에서 효과음 볼륨을 바꿀 때 확인용으로 재생하는 효과음 id. 마찬가지로
  // sfxClips에 등록하기 전까지는 조용히 무시됨
  static const String volumePreview = 'volume_preview';
}
