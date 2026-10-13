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

  // 챕터별 BGM/특정 구간 전용 BGM. 파일은 assets/sounds/ 안에 전부 이미 있음(badending만
  // 파일명이 'bad_ending.mp3'로 id랑 살짝 다르게 돼있어서 bgmTracks에서 그 실제 파일명을
  // 그대로 씀 - 나머지는 id랑 파일명이 동일)
  static const String chapter2Kitchen = 'chapter2_kitchen';
  static const String chapter3Kitchen = 'chapter3_kitchen';
  static const String chapter4Kitchen = 'chapter4_kitchen';
  static const String chapter5 = 'chapter5';
  static const String badending = 'badending';
  static const String dream = 'dream';
  static const String letter = 'letter';
  static const String past = 'past';
  // 채온의 방(ChaeonRoomScreen) 기본곡
  static const String chaeonRoom = 'chaeon_room';
  // 챕터1 기억 회상 미니게임(구름 치우기)
  static const String park = 'park';
  // 챕터2 시계 미니게임
  static const String clock = 'clock';
  // 챕터4에서 슬픔의 빵을 들고 자기 방으로 돌아온 두 번째 방문 전용
  static const String sadChaeonRoom = 'sad_chaeon_room';

  // BGM 트랙 id -> assets/sounds/ 안의 파일 경로('assets/' 뺀 상대 경로).
  // 예: 'main_menu': 'sounds/bgm_main_menu.mp3'
  static const Map<String, String> bgmTracks = {
    mainTheme: 'sounds/main_theme.mp3', // 시작 화면/챕터 선택/엔딩보기/빵집
    proTheme: 'sounds/pro_theme.mp3', // 프롤로그 본편(GamePlayScreen isPrologue)
    streetTheme: 'sounds/street_theme.mp3', // 골목길(TutorialScreen)
    chapter2Kitchen: 'sounds/chapter2_kitchen.mp3', // 챕터2 메인곡
    chapter3Kitchen: 'sounds/chapter3_kitchen.mp3', // 챕터3 메인곡
    chapter4Kitchen: 'sounds/chapter4_kitchen.mp3', // 챕터4 메인곡
    chapter5: 'sounds/chapter5.mp3', // 챕터5 메인곡
    badending: 'sounds/bad_ending.mp3', // 배드엔딩 구간
    dream: 'sounds/dream.mp3', // 챕터4 "슬픔의 빵을 먹고 꿈에서 엄마를 만나는" 구간
    letter: 'sounds/letter.mp3', // 챕터4 편지 읽기 구간(LetterScene)
    past: 'sounds/past.mp3', // 챕터4 과거 회상 구간
    chaeonRoom: 'sounds/chaeon_room.mp3', // 채온의 방(ChaeonRoomScreen)
    park: 'sounds/park.mp3', // 챕터1 기억 회상 미니게임(구름 치우기)
    clock: 'sounds/clock.mp3', // 챕터2 시계 미니게임
    sadChaeonRoom: 'sounds/sad_chaeon_room.mp3', // 챕터4 방 두 번째 방문
  };

  // 트랙별 음량 보정값(기본 1.0). AudioService가 실제 재생 음량을 "사용자 볼륨 단계 x
  // 이 값"으로 계산함 - 곡마다 원본 음원 자체의 체감 크기가 달라서, 나중에 들어보고 특정
  // 곡만 유독 크거나 작으면 숫자만 바꿔서 맞추면 됨(1.0보다 작으면 작게, 크면 크게)
  static const Map<String, double> trackGain = {
    mainTheme: 1.0,
    proTheme: 1.0,
    streetTheme: 1.0,
    chapter2Kitchen: 1.0,
    chapter3Kitchen: 1.0,
    chapter4Kitchen: 1.0,
    chapter5: 1.0,
    badending: 1.0,
    dream: 1.0,
    letter: 1.0,
    past: 1.0,
    chaeonRoom: 1.0,
    park: 1.0,
    clock: 1.0,
    sadChaeonRoom: 1.0,
  };

  // 파일이 실제로 assets/sounds/에 있는 트랙 id 집합. resolveReady가 이 집합 기준으로
  // "요청한 id를 그대로 쓸지, fallback으로 대신할지"를 가름. chaeonRoom/park/clock/
  // sadChaeonRoom도 파일이 생겨서 여기 추가됨 - 앞으로 새 트랙을 추가할 때도 파일이
  // 생기면 여기에 그 id를 추가하는 한 줄만 바꾸면 켜짐(다른 호출부는 전부 resolveReady를
  // 거치니까 손댈 필요 없음)
  //
  // ↓↓↓ 파일이 생기면 여기 추가 ↓↓↓
  static const Set<String> readyTracks = {
    mainTheme,
    proTheme,
    streetTheme,
    chapter2Kitchen,
    chapter3Kitchen,
    chapter4Kitchen,
    chapter5,
    badending,
    dream,
    letter,
    past,
    chaeonRoom,
    park,
    clock,
    sadChaeonRoom,
  };
  // ↑↑↑ 파일이 생기면 여기 추가 ↑↑↑

  // 요청한 트랙 id의 파일이 아직 없으면(readyTracks에 없으면) fallback을 대신 돌려줌 -
  // 파일 없는 트랙을 요청하는 곳들이 이 함수를 거치면, 파일이 생기기 전까지는 항상
  // fallback(그 지점에서 원래 나오던 곡)이 그대로 나와서 동작이 하나도 안 바뀜. 파일이
  // 생겨서 readyTracks에 추가되는 순간, 코드 수정 없이 자동으로 id 쪽이 재생됨
  static String resolveReady(String id, {required String fallback}) =>
      readyTracks.contains(id) ? id : fallback;

  // 루프 이음새 겹침 재생을 켤 트랙 id 집합. 여기 들어있는 트랙은 재생 길이를 구할 수
  // 있으면 끝나기 약 1초 전에 같은 곡을 처음부터 다른 슬롯에서 틀어서 크로스페이드로
  // 겹쳐지게 함(AudioPlayersBackend._watchForLoopOverlap 참고 - 비웹 전용. 웹은
  // AudioBufferSourceNode의 네이티브 loop=true가 이미 샘플 단위로 끊김이 없어서 이 집합과
  // 무관하게 전부 매끄러움). 지금 등록된 BGM 전부 켜둠
  static const Set<String> loopOverlapTracks = {
    mainTheme,
    proTheme,
    streetTheme,
    chapter2Kitchen,
    chapter3Kitchen,
    chapter4Kitchen,
    chapter5,
    badending,
    dream,
    letter,
    past,
    chaeonRoom,
    park,
    clock,
    sadChaeonRoom,
  };

  // 챕터 번호 -> 그 챕터 메인곡 id. KitchenScreen/ChaeonRoomScreen처럼 챕터 내용을
  // 보여주는 화면들이 진입 시점에 이거 하나로 통일해서 playBgm을 호출하게 하려고 모아둠
  static String themeForChapter(int chapter) {
    switch (chapter) {
      case 1:
        return mainTheme;
      case 2:
        return chapter2Kitchen;
      case 3:
        return chapter3Kitchen;
      case 4:
        return chapter4Kitchen;
      case 5:
        return chapter5;
      default:
        return mainTheme;
    }
  }

  // 효과음 id -> assets/sounds/ 안의 파일 경로('assets/' 뺀 상대 경로).
  // 예: 'button_tap': 'sounds/sfx_button_tap.mp3'
  static const Map<String, String> sfxClips = {};

  // 대사 한 줄 넘길 때 울릴 효과음 id. sfxClips에 같은 키로 등록하기 전까지는 조용히 무시됨
  static const String dialogueAdvance = 'dialogue_advance';

  // 설정 메뉴에서 효과음 볼륨을 바꿀 때 확인용으로 재생하는 효과음 id. 마찬가지로
  // sfxClips에 등록하기 전까지는 조용히 무시됨
  static const String volumePreview = 'volume_preview';
}
