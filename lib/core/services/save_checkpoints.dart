// lib/core/services/save_checkpoints.dart
//
// 저장/불러오기 체크포인트 목록. kitchen_screen.dart/chaeon_room_screen.dart/
// game_play_screen.dart 전수조사(SceneDialogueController.loadDialogue 호출 지점) 결과를
// 기준으로, 실제로 로드되는 JSON 파일 하나하나에 체크포인트 하나씩 대응시킴. 프롤로그는
// SceneDialogueController를 아예 안 쓰고 Flame 오버레이(DialogueOverlay(game: game))로
// 따로 도는 구조라 저장 대상에서 제외함.
//
// 이 파일은 아직 어디서도 안 씀 - 이번 단계는 체크포인트 값 자체만 정의해두는 거고, 실제로
// 화면 진입 시 이 값을 읽어서 분기하는 로직은 나중 단계에서 만듦

enum SaveCheckpoint {
  // --- kitchen_screen.dart (20개) ---
  // KitchenScreenMode.chapter2Start 진입 시 걷기 없이 바로 로드됨(chapter2_ready.json)
  chapter2Ready,
  // KitchenScreenMode.chapter1End, dpad로 트리거 지점 도달(kitchen_arrival.json)
  chapter1KitchenArrival,
  // KitchenScreenMode.chapter3Start, dpad로 트리거 지점 도달(chapter3_chaeon_room_after.json)
  chapter3ChaeonRoomAfter,
  // KitchenScreenMode.chapter4Start, dpad로 트리거 지점 도달(chapter4_before_cutscene.json)
  chapter4BeforeCutscene,
  // KitchenScreenMode.chapter5Start, dpad로 트리거 지점 도달(chapter5_bear.json)
  chapter5Bear,
  // chapter2_ready.json 끝난 뒤(chapter2_ingredient_quiz.json)
  chapter2IngredientQuiz,
  // 재료 획득 팝업 탭해서 닫은 뒤(chapter2_after_quiz.json)
  chapter2AfterQuiz,
  // 빵만들기 미니게임(BreadMakingScene) 완료 후(chapter2_making_bread.json)
  chapter2MakingBread,
  // 완성된 빵(salt_bread) 팝업 탭해서 닫은 뒤(chapter2_after_first_game.json)
  chapter2AfterFirstGame,
  // 시계 미니게임 후 감정 gif 재생 끝난 뒤(chapter2_after_second_game.json)
  chapter2AfterSecondGame,
  // chapter3_chaeon_room_after.json 끝난 뒤(chapter3_before_game.json)
  chapter3BeforeGame,
  // 챕터3 빵 팝업 탭해서 닫은 뒤(chapter3_after_first_game.json)
  chapter3AfterFirstGame,
  // 일기장 퍼즐 시퀀스 끝난 뒤(chapter3_after_eat.json)
  chapter3AfterEat,
  // 챕터4 오프닝 회상 컷씬(chapter4CutsceneData) 끝난 뒤(chapter4_after_past.json)
  chapter4AfterPast,
  // choice_001에서 "...알겠어요."를 골라 line_015a1로 끝난 뒤(chapter4_making_bread.json)
  chapter4MakingBread,
  // 편지 컷씬(LetterScene) 끝난 뒤(chapter4_after_letter.json)
  chapter4AfterLetter,
  // 챕터4 빵 팝업 탭해서 닫은 뒤(chapter4_after_making.json)
  chapter4AfterMaking,
  // 챕터5 빵(pie) 팝업 탭해서 닫은 뒤(chapter5_eat.json)
  chapter5Eat,
  // 곰인형 팔 붙이기 미니게임(BearArmPuzzleScene) 완료 후(chapter5_after_eat.json)
  chapter5AfterEat,
  // 히든엔딩 분기, chapter5_after_eat.json 끝난 뒤(resolveChapter5EndingType()==hidden,
  // chapter5_hidden.json)
  chapter5Hidden,

  // --- chaeon_room_screen.dart (5개) ---
  // ChaeonRoomMode.chapter3(기본), enterFromDoor 아닐 때 직접 진입(chapter3_chaeon_room.json)
  chapter3ChaeonRoom,
  // ChaeonRoomMode.chapter4, enterFromDoor 아닐 때 직접 진입(chapter4_start_room.json)
  chapter4StartRoom,
  // enterFromDoor=true, 문으로 걸어 들어오는 연출 끝난 뒤(chapter4_room_choice.json)
  chapter4RoomChoice,
  // chapter4_room_choice.json 끝난 뒤, 온도 3 이하 분기(chapter4_temp_low.json)
  chapter4TempLow,
  // chapter4_room_choice.json 끝난 뒤, 온도 4 이상 분기(chapter4_temp_high.json)
  chapter4TempHigh,

  // --- game_play_screen.dart (5개) ---
  // 릴리안 계단 등장 애니메이션 끝난 뒤(table.json)
  chapter1Table,
  // skipChapter1Events 모드, 골목 계단 트리거 도달(chapter3_door.json)
  chapter3Door,
  // reentryChapter==chapter5, 릴리안 도착 트리거(chapter5_start.json)
  chapter5Start,
  // 릴리안 걷기 애니메이션 끝난 뒤, 첫 만남(first_meet.json)
  chapter1FirstMeet,
  // 구름 드래그 미니게임(MemoryFlashbackScene) 완료 후(first_bread.json)
  chapter1FirstBread,
}
