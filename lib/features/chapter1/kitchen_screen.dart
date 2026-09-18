// lib/features/chapter1/kitchen_screen.dart
//
// 앞치마 갈아입고 계단을 내려와 도착하는 주방 화면. tutorial_screen.dart처럼 Flame 없이
// 순수 Flutter Positioned/Transform으로만 그림. kitchen_main.png가 화면 한 프레임에
// 다 들어가는 단일 배경이라 카메라 스크롤도 따로 안 둠 (bakery_bg_main.png 같은 와이드 맵이 아님)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/interaction_loader.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/dialogue_overlay.dart';
import 'package:emotional_bakery/core/widgets/menu_overlay.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/core/services/app_exit.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart';
import 'package:emotional_bakery/features/chapter2/bread_making_scene.dart';
import 'package:emotional_bakery/features/chapter2/clock_minigame_scene.dart';
import 'package:emotional_bakery/features/chapter3/chaeon_room_screen.dart';
import 'package:emotional_bakery/features/chapter3/diary_puzzle_scene.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/chapter4/chapter4_cutscene_data.dart';
import 'package:emotional_bakery/features/chapter4/chapter4_bad_ending_data.dart';
import 'package:emotional_bakery/features/chapter4/chapter4_making_bread_cutscene_data.dart';
import 'package:emotional_bakery/features/chapter4/letter_scene.dart';
import 'package:emotional_bakery/features/chapter5/bear_arm_puzzle_scene.dart';
import 'package:emotional_bakery/features/chapter5/chapter5_ending_happy_data.dart';
import 'package:emotional_bakery/features/chapter5/chapter5_ending_hidden_data.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';

// 채온이가 계단 하강 애니메이션 끝나고 서는 시작 위치 (kitchen_main.png 실측값, 874x464 캔버스 기준)
const double kChaeonKitchenStartX = 60;
const double kChaeonKitchenTopY = 220;
// 릴리안이 고정으로 서있는 위치 (실측값)
const double kLillianKitchenX = 467;
const double kLillianKitchenTopY = 213;
// 채온이가 이 위치 이상 도달하면 이동이 잠기고 kitchen_arrival.json 대사가 자동으로 시작됨
const double kKitchenDialogueTriggerX = 232;
// 모바일에 가까운 화면(가로가 길고 세로가 짧은 화면)에서만 채온/릴리안을 추가로
// 아래로 내리는 양(874x402 기준, rH로 스케일됨). 늘리면 더 아래로, 0이면 원래 위치 그대로
const double kKitchenMobileCharacterDropRef = 10;
// 채온이가 좌우로 움직일 수 있는 범위 (배경 밖으로 안 나가게)
const double kChaeonKitchenMinX = 60;
const double kChaeonKitchenMaxX = 814;
// 채온이 이동 속도(px/초, 논리 좌표 기준). 챕터1 본편/튜토리얼이랑 동일한 값
const double kChaeonKitchenSpeed = 225;
const Duration _moveTickInterval = Duration(milliseconds: 40);

// 계단을 다시 올라가 빵집으로 돌아가는 연출: 내려올 때(game_play_screen.dart의
// _triggerChaeonStairsDescent)와 동일한 패턴으로, kitchen_main.png 좌표계(874x464) 기준
// 시작/끝 지점과 재생 시간을 지정
const Offset _stairsAscentStart = Offset(60, 220);
const Offset _stairsAscentEnd = Offset(-120, 154);
const Duration _stairsAscentDuration = Duration(milliseconds: 700);

// chapter2_making_bread.json 끝나고 암전 페이드인/유지/페이드아웃 타이밍.
// 유지 시간은 임시값, 나중에 실제 연출 보면서 조정 예정
const Duration _memoryBlackoutFadeInDuration = Duration(milliseconds: 300);
const Duration _memoryBlackoutHoldDuration = Duration(seconds: 2);
const Duration _memoryBlackoutFadeOutDuration = Duration(milliseconds: 300);

// 챕터3 일기장 퍼즐 시퀀스(chapter3_after_first_game.json 끝난 뒤) 단계별 대기 시간.
// chapter3_making_bread 암전이랑 별개로 여기 전용 상수로 분리함
// 이 값을 조정하면 chapter3_after_first_game.json 대화가 끝나고 화면이 암전됐다가
// 일기장 인트로 이미지(chapter3_diary_intro.png)가 뜨기까지의 대기 시간이 바뀜.
// 챕터1 먹구름 미니게임 전환 암전(game_play_screen.dart의 _memoryFadeInDuration +
// _memoryFadeHoldDuration + _memoryFadeOutDuration = 300+1000+300ms)과 동일한 총 시간
const Duration _chapter3DiaryBlackoutHoldDuration = Duration(milliseconds: 1600);
const Duration _chapter3DiaryIntroHoldDuration = Duration(seconds: 2);
const Duration _chapter3DiarySuccessAfterHoldDuration = Duration(
  milliseconds: 1800,
);
// 이 값을 조정하면 퍼즐 결과 이미지(chapter3_diary_success_after.png) 노출이 끝나고
// 암전됐다가 chapter3_after_eat.json 대화가 시작되기까지의 대기 시간이 바뀜.
// 기존 3초는 다른 미니게임들의 암전(400ms~2초)보다 유독 길어서, 같은 파일의 비슷한
// 패턴인 _memoryBlackoutHoldDuration(챕터1 결과물 이후 암전, 2초)에 맞춤
const Duration _chapter3DiaryEndBlackoutHoldDuration = Duration(seconds: 2);

// 챕터5 회상씬(곰인형 팔 붙이기)에서 bear_bg+팔이 뜬 채로 안내창이 뜨기 전까지 잠깐
// 보여주는 시간
const Duration _chapter5BearIntroGuideDelay = Duration(seconds: 1);
// 챕터5 회상씬에서 playground_bg 노출 시간. 챕터3의 _chapter3DiaryIntroHoldDuration(2초)을
// 재사용했었는데 실제로 켜보니 너무 짧아서 챕터5 전용으로 따로 뺌
const Duration _chapter5PlaygroundHoldDuration = Duration(seconds: 3);

// "저장되었습니다" 배지가 뜨는 top 위치(874x402 기준, rH로 스케일됨). 임시값이라 화면
// 보면서 조정 예정
const double _saveConfirmationBadgeTopRef = 80;

// 이 화면이 챕터1 엔딩용인지 챕터2 시작용인지 구분. 배경/캐릭터는 같은 주방을 재사용하고
// 이동 가능 여부, 처음 로드하는 대사만 다름
enum KitchenScreenMode {
  // 챕터1 엔딩: dpad로 걸어가서 릴리안 근처에 도달하면 kitchen_arrival.json이 자동 시작됨
  chapter1End,
  // 챕터2 시작: 걷기 없이 화면 들어오자마자 바로 chapter2_ready.json 대사가 시작됨
  chapter2Start,
  // 챕터3 시작: 걷기 없이 화면 들어오자마자 바로 chapter3_chaeon_room_after.json 대사가 시작됨
  chapter3Start,
  // 챕터4 시작: chapter3Start랑 동일하게 dpad로 걸어가서 트리거 지점(kKitchenDialogueTriggerX)에
  // 도달하면 chapter4_before_cutscene.json이 자동 시작됨
  chapter4Start,
  // 챕터5 시작: game_play_screen.dart(빵집)에서 chapter5_start.json 대사 -> 앞치마 착용 ->
  // 계단 하강까지 다 끝난 뒤 도달함. 아직 다음 대사가 없어서 들어오자마자 바로 임시 종료 화면 표시
  // (업데이트: chapter5_bear.json이 준비돼서 이제 chapter3Start/chapter4Start랑 동일하게
  // dpad로 걸어가서 트리거 지점 도달 시 자동 시작하는 방식으로 바뀜)
  chapter5Start,
}

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({
    super.key,
    this.initialTemperature = 3,
    this.mode = KitchenScreenMode.chapter1End,
    this.resumeCheckpoint,
  });

  // GamePlayScreen에서 이어받는 온도계 값 (화면이 바뀌어도 온도계가 끊기지 않게)
  final int initialTemperature;
  final KitchenScreenMode mode;
  // 저장된 세이브를 불러와서 들어온 경우에만 넘어옴. mode는 이 체크포인트가 속한 모드랑
  // 맞게 호출부에서 같이 넘겨줘야 함(체크포인트 하나가 어느 파일을 로드할지는 정해주지만,
  // 그 이후 onDialogueEnd 체이닝이 어느 챕터 분기를 탈지는 여전히 mode가 결정하기 때문).
  // null이면(기본값) 지금까지와 100% 동일하게 동작함
  final SaveCheckpoint? resumeCheckpoint;

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with SingleTickerProviderStateMixin {
  double _chaeonX = kChaeonKitchenStartX;
  String _chaeonState = 'idle';
  bool _isChaeonFacingLeft = false;

  Timer? _moveTimer;
  // 대사 트리거 이후로는 이동 잠금 (dpad도 같이 숨김)
  bool _movementLocked = false;
  // chapter2_after_first_game.json이 끝나면 chaeon_0_eat.gif로 2초간 고정해서 보여줌
  bool _showChaeonEating = false;
  Timer? _chaeonEatingTimer;
  Timer? _chaeonEmotion0to20Timer;
  // kitchen_arrival.json 자동 로드가 중복 실행되지 않게 막는 플래그
  bool _hasTriggeredDialogue = false;

  // 왼쪽 끝에서 계단을 다시 올라가 빵집으로 돌아가는 연출
  late final AnimationController _stairsUpController;
  Animation<Offset>? _stairsUpAnimation;
  bool _isChaeonAscendingStairs = false;
  // true면 계단 오르기 애니메이션이 끝났을 때 Navigator.pop 대신 암전 후
  // 채온이 방(ChaeonRoomScreen)으로 넘어감(chapter4_after_making.json 끝난 뒤 퇴장 연출)
  bool _pendingChapter4RoomExit = false;

  bool _isSettingOpen = false;
  // 메뉴 "저장" 버튼 누르면 잠깐 뜨는 확인 문구. null이면 안 보임
  String? _saveConfirmationText;
  Timer? _saveConfirmationTimer;
  // kitchen_arrival.json(챕터1)이나 chapter2_ingredient_quiz.json(챕터2)이 끝나면 true.
  // 지금은 안내 문구만 있는 임시 화면으로 대체함
  bool _showChapterEndPlaceholder = false;
  // 챕터4 모드에서 chapter4_before_cutscene.json 끝나면 뜨는 오프닝 컷씬(과거 회상).
  // 프롤로그의 DialogueOverlay를 data/onComplete만 다르게 넘겨서 그대로 재사용함
  bool _showChapter4Cutscene = false;
  // 챕터4 모드에서 오프닝 컷씬 끝나고 chapter4_after_past.json을 이미 이어붙였는지
  bool _hasLoadedChapter4AfterPast = false;
  // chapter4_after_past.json의 choice_001에서 "아뇨... 싫어요."(line_015b1)를 골라서
  // 끝난 경우에만 뜨는 배드엔딩 컷씬. 오프닝 컷씬(_showChapter4Cutscene)이랑 동일한
  // DialogueOverlay 재사용 패턴
  bool _showChapter4BadEndingCutscene = false;
  // 배드엔딩 컷씬까지 다 본 상태인지. true면 챕터 종료 임시 화면 문구를 "배드엔딩"으로 바꿈
  bool _isChapter4BadEnding = false;
  // chapter4_after_past.json의 choice_001에서 "...알겠어요."(line_015a1)를 골라서
  // 끝난 경우, chapter4_making_bread.json을 이미 이어붙였는지
  bool _hasLoadedChapter4MakingBread = false;
  // chapter4_making_bread.json이 끝나면(line_014, "그럼...") 뜨는 편지 컷씬
  bool _showChapter4Letter = false;
  // 편지 컷씬(LetterScene)이 끝나고 chapter4_after_letter.json을 이미 이어붙였는지
  bool _hasLoadedChapter4AfterLetter = false;
  // chapter4_after_letter.json이 끝나면(line_003) 뜨는 빵만들기 컷씬(과거 회상 컷씬이랑
  // 동일하게 DialogueOverlay 재사용)
  bool _showChapter4MakingBreadCutscene = false;
  // 빵만들기 컷씬이 끝나면 뜨는 완성된 빵(croissant) 팝업. 챕터2 _showBreadPopup/챕터3
  // _showChapter3BreadPopup이랑 동일한 패턴. 탭하면 닫힘
  bool _showChapter4BreadPopup = false;
  // 완성된 빵 팝업이 끝나고 chapter4_after_making.json을 이미 이어붙였는지
  bool _hasLoadedChapter4AfterMaking = false;
  // chapter5_bear.json(line_019)이 끝나면 뜨는 빵만들기 미니게임. 챕터2/3이랑 동일한
  // BreadMakingScene 재사용, 완성 빵 이미지만 pie.png로 고정함
  bool _showChapter5BreadMakingGame = false;
  // 빵만들기 미니게임이 끝나면 뜨는 완성된 빵(pie) 팝업. 챕터2/3/4 팝업이랑 동일한 패턴.
  // 탭하면 닫히고 chapter5_eat.json으로 이어짐
  bool _showChapter5BreadPopup = false;
  // 완성 빵 팝업이 끝나고 chapter5_eat.json을 이미 이어붙였는지
  bool _hasLoadedChapter5Eat = false;
  // 곰인형 팔 붙이기+바느질 미니게임(BearArmPuzzleScene)이 끝나고 chapter5_after_eat.json을
  // 이미 이어붙였는지
  bool _hasLoadedChapter5AfterEat = false;
  // chapter5_after_eat.json이 끝나고, StoryState.resolveChapter5EndingType()이 happy일 때
  // 뜨는 해피엔딩 컷씬. 챕터4 노말엔딩(chaeon_room_screen.dart)이랑 동일하게
  // DialogueOverlay + chapter5EndingHappyData 재사용
  bool _showChapter5EndingHappyCutscene = false;
  // chapter5_after_eat.json이 끝나고, StoryState.resolveChapter5EndingType()이 hidden일 때
  // chapter5_hidden.json을 이미 이어붙였는지
  bool _hasLoadedChapter5Hidden = false;
  // chapter5_hidden.json이 끝나고(line_006) 암전 후 뜨는 히든엔딩 컷씬. 해피엔딩이랑
  // 동일하게 DialogueOverlay + chapter5EndingHiddenData 재사용
  bool _showChapter5EndingHiddenCutscene = false;
  // chapter5_eat.json이 끝나면(chaeon_80_eat.gif 재생 후) 시작되는 회상씬 앞부분:
  // 암전 -> playground_bg -> bear_bg+팔 -> 안내창 순으로 이어짐. 퍼즐 자체는
  // BearArmPuzzleScene이 이어받음
  bool _showChapter5Playground = false;
  bool _showChapter5BearIntro = false;
  bool _showChapter5BearIntroGuide = false;
  bool _showChapter5BearArmPuzzle = false;
  Timer? _chapter5PlaygroundTimer;
  Timer? _chapter5BearIntroGuideTimer;
  // 챕터2 모드에서 chapter2_ready.json 다음 chapter2_ingredient_quiz.json을 이미 이어붙였는지
  bool _hasLoadedIngredientQuiz = false;
  // 챕터3 모드에서 chapter3_chaeon_room_after.json 다음 chapter3_before_game.json을 이미 이어붙였는지
  bool _hasLoadedBeforeGame = false;
  // chapter3_before_game.json이 끝나면 뜨는 빵만들기 미니게임. 챕터2 BreadMakingScene을
  // 그대로 재사용함(완성 반죽 이미지도 챕터2랑 동일하게 재료 조합 기준으로 결정됨)
  bool _showChapter3BreadMakingGame = false;
  // 챕터3 빵만들기 미니게임에서 완성된 반죽 화면을 탭하면(BreadMakingScene.onComplete) 뜨는,
  // 완성된 빵(onion_bread) 팝업. 챕터2 _showBreadPopup이랑 동일한 패턴. 탭하면 닫힘
  bool _showChapter3BreadPopup = false;
  // 챕터3 빵만들기 미니게임 끝나고 chapter3_after_first_game.json을 이미 이어붙였는지
  bool _hasLoadedChapter3AfterFirstGameDialogue = false;
  // chapter3_after_first_game.json 끝나고 일기장 퍼즐 시퀀스 시작 전 뜨는 첫 암전
  bool _showChapter3DiaryBlackout = false;
  Timer? _chapter3DiaryBlackoutTimer;
  // 첫 암전 끝나고 뜨는 일기장 인트로 이미지(chapter3_diary_intro.png)
  bool _showChapter3DiaryIntro = false;
  Timer? _chapter3DiaryIntroTimer;
  // 인트로 끝나고 뜨는 사진 조각 맞추기 미니게임(DiaryPuzzleScene)
  bool _showChapter3DiaryPuzzle = false;
  // 퍼즐 완성 후 뜨는 결과 이미지(chapter3_diary_success_after.png)
  bool _showChapter3DiarySuccessAfter = false;
  Timer? _chapter3DiarySuccessAfterTimer;
  // 결과 이미지 끝나고 chapter3_after_eat.json 로드하기 전 뜨는 두 번째 암전
  bool _showChapter3DiaryEndBlackout = false;
  Timer? _chapter3DiaryEndBlackoutTimer;
  // 일기장 퍼즐 시퀀스 끝나고 chapter3_after_eat.json을 이미 이어붙였는지
  bool _hasLoadedChapter3AfterEatDialogue = false;
  // chapter2_ingredient_quiz.json의 재료 이름 대사(line_ingredient_reveal)가 끝나고 탭하면 뜨는,
  // 선택한 재료 이미지 팝업. 탭하면 닫힘
  bool _showIngredientPopup = false;
  // 재료 팝업 닫고 chapter2_after_quiz.json을 이미 이어붙였는지
  bool _hasLoadedAfterQuizDialogue = false;
  // chapter2_after_quiz.json 대화가 끝나면 뜨는 빵만들기 미니게임
  bool _showBreadMakingGame = false;
  // chapter2_making_bread.json 대사가 끝나고, 암전 -> 재점등 후에 뜨는 완성된 빵(salt_bread)
  // 팝업. 탭하면 닫히고 chapter2_after_first_game.json으로 이어짐
  bool _showBreadPopup = false;
  // 빵 팝업 닫고 chapter2_after_first_game.json을 이미 이어붙였는지
  bool _hasLoadedAfterFirstGameDialogue = false;
  // 빵만들기 미니게임 완료 직후(BreadMakingScene.onComplete) chapter2_making_bread.json을
  // 이미 로드했는지. 이 대사가 끝나야 암전 -> 재점등을 거쳐서 빵 팝업이 뜸
  bool _hasLoadedMakingBreadDialogue = false;
  // chapter2_making_bread.json 끝나고 빵 팝업(salt_bread) 뜨기 전 잠깐 화면을 덮는 암전.
  // 페이드인/아웃은 _memoryBlackoutOpacity를 AnimatedOpacity로 애니메이션함
  bool _showMemoryBlackout = false;
  double _memoryBlackoutOpacity = 0.0;
  Timer? _memoryBlackoutTimer;
  // chaeon_0_eat.gif 노출이 끝나면 뜨는 시계 맞추기 미니게임. 끝나면(onComplete) 임시 종료 화면으로 넘어감
  bool _showClockMinigame = false;
  // 시계 맞추기 미니게임이 끝나면, chapter2_after_second_game.json을 로드하기 전에
  // chaeon_emotion_0to20.gif를 2.5초간 보여줌 (챕터1 chaeon_emotion_0to100.gif와 재생 시간 동일)
  bool _showChaeonEmotion0to20 = false;
  // chapter2_after_second_game.json부터는 채온이가 chaeon_20.gif 상태로 고정됨
  bool _showChaeon20 = false;
  // 시계 맞추기 미니게임 끝나고 chapter2_after_second_game.json을 이미 이어붙였는지
  bool _hasLoadedAfterSecondGameDialogue = false;

  bool _imagesPrecached = false;

  // 배경 오브젝트 클릭 정보 팝업. chapter_kitchen.json에서 불러온 히트박스 목록이고,
  // 방향키가 나와있을 때(!_movementLocked)만 클릭해서 정보를 얻을 수 있음
  List<InteractionObject> _interactionObjects = [];
  String? _interactionText;

  late final SceneDialogueController _sceneController;

  @override
  void initState() {
    super.initState();
    _stairsUpController =
        AnimationController(vsync: this, duration: _stairsAscentDuration)
          ..addListener(() {
            if (mounted) setState(() {});
          });
    _stairsUpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (_pendingChapter4RoomExit) {
          Navigator.push(
            context,
            fadeThroughBlackRoute(
              ChaeonRoomScreen(
                mode: ChaeonRoomMode.chapter4,
                enterFromDoor: true,
                // 온도계는 누적형이라 챕터4 방으로 넘어갈 때도 지금까지 쌓인 온도를 그대로 이어받아야 함.
                // 여기서 안 넘기면 ChaeonRoomScreen 기본값(3)으로 초기화돼버림
                initialTemperature: _sceneController.temperature,
              ),
              // 계단 다 올라간 뒤 방으로 넘어가는 연출이라 다른 화면 전환보다 암전을
              // 조금 더 길게 줌
              fadeOutDuration: const Duration(milliseconds: 400),
              holdDuration: const Duration(milliseconds: 1200),
              fadeInDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
    });
    // 챕터2는 걷기 없이 바로 대사부터 시작하니까, 이동을 처음부터 잠그고 릴리안 근처에
    // 이미 도착해있는 걸로 시작함
    if (widget.mode == KitchenScreenMode.chapter2Start) {
      _movementLocked = true;
      _chaeonX = kKitchenDialogueTriggerX;
    }
    // 챕터3은 chapter1End랑 동일하게 기본 시작 위치(kChaeonKitchenStartX)에서 dpad로 걸어가서
    // 트리거 지점에 도달해야 대사가 시작됨. 그래서 여기선 따로 잠그지 않음
    // 챕터5도 chapter5_bear.json이 준비돼서 이제 chapter3Start/chapter4Start랑 동일하게
    // dpad로 걸어가서 트리거 지점에 도달하는 방식으로 시작함. 그래서 여기선 안 잠금
    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        // 챕터2 모드는 ready -> ingredient_quiz -> (재료 팝업) -> after_quiz ->
        // (빵만들기 미니게임) -> making_bread -> (암전/재점등) -> (빵 팝업) -> after_first_game
        // 순서로 자동 이어붙이고(table.json -> 회상컷씬 -> first_bread.json처럼 대화 끝나면
        // 다음 대화 자동 로드하는 패턴), 그 다음에 끝나면 임시 안내 화면을 띄움
        if (widget.mode == KitchenScreenMode.chapter2Start) {
          if (!_hasLoadedIngredientQuiz) {
            _hasLoadedIngredientQuiz = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter2/chapter2_ingredient_quiz.json',
            );
          } else if (!_hasLoadedAfterQuizDialogue) {
            // line_ingredient_reveal 대사가 끝나면(next: null) 여기로 옴.
            // 선택한 재료 이미지 팝업을 띄우고, 팝업을 닫으면 다음 대사(after_quiz)로 이어짐
            setState(() => _showIngredientPopup = true);
          } else if (_hasLoadedMakingBreadDialogue &&
              !_hasLoadedAfterFirstGameDialogue) {
            // chapter2_making_bread.json이 끝나면(line_001) 여기로 옴. 암전 잠깐 띄웠다가
            // 재점등 후 salt_bread 팝업을 띄움. 실제 처리는 _startMemoryBlackout에서 함
            _startMemoryBlackout(
              onComplete: () => setState(() => _showBreadPopup = true),
            );
          } else if (!_hasLoadedAfterFirstGameDialogue) {
            // chapter2_after_quiz.json이 끝나면(line_021) 여기로 옴. 빵만들기 미니게임 시작.
            // 미니게임 완료(BreadMakingScene.onComplete) -> chapter2_making_bread.json 로드까지는
            // 미니게임 콜백에서 처리하고, 그 대사가 끝나면 위 _hasLoadedMakingBreadDialogue
            // 분기가 암전 -> 재점등 -> salt_bread 팝업으로 이어받음
            setState(() => _showBreadMakingGame = true);
          } else if (!_hasLoadedAfterSecondGameDialogue) {
            // chapter2_after_first_game.json이 끝나면(line_008) 여기로 옴.
            // 채온이를 chaeon_0_eat.gif로 2초간 고정해서 보여준 뒤 시계 맞추기 미니게임으로 넘어감.
            // 미니게임이 끝나면(ClockMinigameScene.onComplete) chapter2_after_second_game.json으로 이어짐
            setState(() => _showChaeonEating = true);
            _chaeonEatingTimer = Timer(const Duration(milliseconds: 2000), () {
              if (!mounted) return;
              setState(() {
                _showChaeonEating = false;
                _showClockMinigame = true;
              });
            });
          } else {
            // chapter2_after_second_game.json이 끝나면(line_013) 여기로 옴. 임시 종료 화면 표시
            setState(() => _showChapterEndPlaceholder = true);
          }
          return;
        }
        // 챕터3 모드는 chaeon_room_after -> before_game 순으로 자동 이어붙이고
        // (chapter2Start랑 동일한 체이닝 패턴), 아직 미니게임이 없어서 끝나면 임시 안내 화면을 띄움
        if (widget.mode == KitchenScreenMode.chapter3Start) {
          if (!_hasLoadedBeforeGame) {
            _hasLoadedBeforeGame = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter3/chapter3_before_game.json',
            );
          } else if (!_hasLoadedChapter3AfterFirstGameDialogue) {
            // chapter3_before_game.json이 끝나면(line_028, "그럼 만들어볼까요?") 여기로 옴.
            // 빵만들기 미니게임 시작. 미니게임 완료 -> after_first_game.json 로드까지는
            // 미니게임 쪽 콜백(onComplete)에서 처리함
            setState(() => _showChapter3BreadMakingGame = true);
          } else if (!_hasLoadedChapter3AfterEatDialogue) {
            // chapter3_after_first_game.json이 끝나면(line_014, 릴리안 빵 먹는 GIF까지) 여기로
            // 옴. 일기장 퍼즐 시퀀스 시작(암전 -> 인트로 -> 퍼즐 -> 결과 이미지 -> 암전 ->
            // chapter3_after_eat.json). 실제 로드는 _startChapter3DiarySequence 체인 끝에서 처리
            _startChapter3DiarySequence();
          } else {
            // (참고: 이제 이 분기는 빵만들기 미니게임도, chapter3_after_first_game.json도 아니라
            // 일기장 퍼즐 시퀀스 끝에 로드되는 chapter3_after_eat.json이 끝나면 옴)
            // chapter3_before_game.json이 끝나면(line_029, "네!") 여기로 옴. 임시 종료 화면 표시
            setState(() => _showChapterEndPlaceholder = true);
          }
          return;
        }
        // 챕터4 모드는 chapter4_before_cutscene.json -> 오프닝 컷씬(과거 회상) ->
        // chapter4_after_past.json 순으로 자동 이어붙이고(chapter2Start/chapter3Start랑
        // 동일한 체이닝 패턴), 그 다음 choice_001에서 고른 분기에 따라 배드엔딩 컷씬 또는
        // chapter4_making_bread.json으로 갈라짐. 컷씬 -> chapter4_after_past.json 로드는
        // DialogueOverlay onComplete 쪽에서 처리함
        if (widget.mode == KitchenScreenMode.chapter4Start) {
          if (!_hasLoadedChapter4AfterPast) {
            setState(() => _showChapter4Cutscene = true);
          } else if (_sceneController.lastLineNode?.id == 'line_015b1') {
            // choice_001에서 "아뇨... 싫어요."를 골라 line_015b1로 끝난 경우만 배드엔딩 컷씬 표시
            setState(() => _showChapter4BadEndingCutscene = true);
          } else if (!_hasLoadedChapter4MakingBread) {
            // choice_001에서 "...알겠어요."를 골라 line_015a1로 끝난 경우.
            // chapter4_making_bread.json으로 이어붙임
            _hasLoadedChapter4MakingBread = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter4/chapter4_making_bread.json',
            );
          } else if (!_hasLoadedChapter4AfterLetter) {
            // chapter4_making_bread.json이 끝나면(line_014, "그럼...") 여기로 옴. 편지 컷씬 표시
            setState(() => _showChapter4Letter = true);
          } else if (!_hasLoadedChapter4AfterMaking) {
            // chapter4_after_letter.json이 끝나면(line_003) 여기로 옴. 빵만들기 컷씬 표시
            setState(() => _showChapter4MakingBreadCutscene = true);
          } else {
            // chapter4_after_making.json이 끝나면(line_003) 여기로 옴. 채온이가 왼쪽으로
            // 걸어서 나가고 -> 암전 -> 채온이 방으로 넘어감
            _startChapter4ExitWalk();
          }
          return;
        }
        // 챕터5는 chapter5_bear.json(line_019, "자, 그럼 이제 빵을 만들어볼까요?")이 끝나면
        // 빵만들기 미니게임을 띄움. 미니게임 완료 -> 완성 빵 팝업 -> chapter5_eat.json까지는
        // 미니게임/팝업 쪽 콜백에서 처리하고, chapter5_eat.json이 끝나면(마지막 노드,
        // chaeon_80_eat.gif 재생 후) 여기로 다시 옴 - 회상씬(곰인형 팔 붙이기) 시작.
        // chapter5_after_eat.json은 BearArmPuzzleScene의 onComplete(9-22층)에서 이어붙이고,
        // 그게 끝나면 다시 여기로 옴 - StoryState.resolveChapter5EndingType()으로 해피엔딩
        // 컷씬을 보여줄지, 히든엔딩 쪽 chapter5_hidden.json을 이어붙일지 갈림. 챕터5까지 온
        // 경우 온도는 항상 최고치라 여기선 온도 조건 없이 resolveChapter5EndingType() 결과로만 분기함
        if (widget.mode == KitchenScreenMode.chapter5Start) {
          if (!_hasLoadedChapter5Eat) {
            setState(() => _showChapter5BreadMakingGame = true);
          } else if (!_hasLoadedChapter5AfterEat) {
            _startChapter5MemorySequence();
          } else if (StoryState.resolveChapter5EndingType() ==
              Chapter5EndingType.happy) {
            setState(() => _showChapter5EndingHappyCutscene = true);
          } else if (!_hasLoadedChapter5Hidden) {
            // hidden 분기: chapter2Start/chapter3Start랑 동일한 체이닝 패턴으로
            // chapter5_hidden.json을 이어붙임
            _hasLoadedChapter5Hidden = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter5/chapter5_hidden.json',
            );
          } else {
            // chapter5_hidden.json이 끝나면(line_006, "그렇다면 엣헴! 제가 도와줄게요.") 여기로
            // 옴. 암전 후 히든엔딩 컷씬 표시
            _startChapter5HiddenEndingSequence();
          }
          return;
        }
        // kitchen_arrival.json 종료 = 챕터 1 종료 시점.
        // TODO: 나중에 진짜 챕터1 종료 연출/다음 챕터 연결로 교체할 예정. 지금은 임시 안내 문구만 표시
        setState(() => _showChapterEndPlaceholder = true);
      },
      // kitchen_arrival.json에는 hop 트리거용 animation 필드가 없어서 둘 다 안 씀
      onLillianHop: () {},
      onChaeonHop: () {},
      // widget.initialTemperature 대신 전역값을 읽음 - 챕터 경계(ChapterSelectScreen 경유)를
      // 넘어갈 때도 온도가 안 끊기게 하려면 여기서 위젯 파라미터를 안 쓰고 StoryState를 직접
      // 봐야 함. widget.initialTemperature는 이제 여기서 안 쓰이지만, 같은 챕터 안에서 화면끼리
      // 명시적으로 넘겨주던 기존 호출부들이 있어서 파라미터 자체는 그대로 둠(각 호출부 주석 참고)
      initialTemperature: StoryState.currentTemperature,
    );
    _sceneController.addListener(_onSceneControllerChanged);
    // 배경 오브젝트 클릭 정보(chapter_kitchen.json) 로드
    InteractionLoader.loadStageObjects('kitchen_main.png').then((objects) {
      if (mounted) setState(() => _interactionObjects = objects);
    });
    // 세이브 불러와서 들어온 경우, 정상 진입 흐름(아래) 대신 체크포인트가 가리키는 지점부터
    // 바로 시작함. resumeCheckpoint가 null이면 이 분기 자체를 안 타서 기존 동작 그대로임
    if (widget.resumeCheckpoint != null) {
      _resumeFromCheckpoint(widget.resumeCheckpoint!);
    } else {
      // 챕터2는 걷기 없이 화면 들어오자마자 바로 대사 시작
      if (widget.mode == KitchenScreenMode.chapter2Start) {
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_ready.json',
        );
      }
      // 챕터3은 chapter1End처럼 트리거 지점 도달 시 _checkDialogueTrigger에서 로드하므로 여기선 안 함
    }
  }

  // resumeCheckpoint로 들어온 경우 initState에서 호출됨. 원래는 dpad 트리거(_checkDialogueTrigger)나
  // onDialogueEnd 체이닝이 순서대로 _hasLoadedXxx 플래그를 하나씩 켜가면서 도달하는 지점들인데,
  // "이미 여기까지 왔다"고 치고 그 체크포인트 이전에 있었어야 할 플래그들을 한 번에 미리 켜준
  // 다음 해당 파일을 바로 로드함. StoryState/ChapterProgress(온도, 선택 변수, 해금 상태)는
  // 이 화면 진입 전에 SaveManager.load()로 이미 복원되어 있는 걸 전제로 함 - 여기선 안 건드림
  void _resumeFromCheckpoint(SaveCheckpoint checkpoint) {
    // 챕터3/4/5는 원래 dpad로 걸어가서 kKitchenDialogueTriggerX 트리거 지점에 도달해야
    // 첫 대사가 시작되는데(_checkDialogueTrigger 참고), 저장된 지점부터 재생할 땐 그 워킹
    // 과정을 다시 시킬 필요가 없어서 이미 트리거를 통과한 걸로 쳐줌. 챕터2는 원래도
    // initState 맨 위에서 무조건 movementLocked라 따로 안 건드려도 됨
    void lockAtTrigger() {
      _hasTriggeredDialogue = true;
      _movementLocked = true;
      _chaeonX = kKitchenDialogueTriggerX;
    }

    switch (checkpoint) {
      case SaveCheckpoint.chapter2Ready:
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_ready.json',
        );
        break;
      case SaveCheckpoint.chapter1KitchenArrival:
        lockAtTrigger();
        _sceneController.loadDialogue(
          'assets/lines/chapter1/kitchen_arrival.json',
        );
        break;
      case SaveCheckpoint.chapter3ChaeonRoomAfter:
        lockAtTrigger();
        _sceneController.loadDialogue(
          'assets/lines/chapter3/chapter3_chaeon_room_after.json',
        );
        break;
      case SaveCheckpoint.chapter4BeforeCutscene:
        lockAtTrigger();
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_before_cutscene.json',
        );
        break;
      case SaveCheckpoint.chapter5Bear:
        lockAtTrigger();
        _sceneController.loadDialogue('assets/lines/chapter5/chapter5_bear.json');
        break;
      case SaveCheckpoint.chapter2IngredientQuiz:
        _hasLoadedIngredientQuiz = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_ingredient_quiz.json',
        );
        break;
      case SaveCheckpoint.chapter2AfterQuiz:
        _hasLoadedIngredientQuiz = true;
        _hasLoadedAfterQuizDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_after_quiz.json',
        );
        break;
      case SaveCheckpoint.chapter2MakingBread:
        _hasLoadedIngredientQuiz = true;
        _hasLoadedAfterQuizDialogue = true;
        _hasLoadedMakingBreadDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_making_bread.json',
        );
        break;
      case SaveCheckpoint.chapter2AfterFirstGame:
        _hasLoadedIngredientQuiz = true;
        _hasLoadedAfterQuizDialogue = true;
        _hasLoadedMakingBreadDialogue = true;
        _hasLoadedAfterFirstGameDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_after_first_game.json',
        );
        break;
      case SaveCheckpoint.chapter2AfterSecondGame:
        _hasLoadedIngredientQuiz = true;
        _hasLoadedAfterQuizDialogue = true;
        _hasLoadedMakingBreadDialogue = true;
        _hasLoadedAfterFirstGameDialogue = true;
        _hasLoadedAfterSecondGameDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter2/chapter2_after_second_game.json',
        );
        break;
      case SaveCheckpoint.chapter3BeforeGame:
        lockAtTrigger();
        _hasLoadedBeforeGame = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter3/chapter3_before_game.json',
        );
        break;
      case SaveCheckpoint.chapter3AfterFirstGame:
        lockAtTrigger();
        _hasLoadedBeforeGame = true;
        _hasLoadedChapter3AfterFirstGameDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter3/chapter3_after_first_game.json',
        );
        break;
      case SaveCheckpoint.chapter3AfterEat:
        lockAtTrigger();
        _hasLoadedBeforeGame = true;
        _hasLoadedChapter3AfterFirstGameDialogue = true;
        _hasLoadedChapter3AfterEatDialogue = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter3/chapter3_after_eat.json',
        );
        break;
      case SaveCheckpoint.chapter4AfterPast:
        lockAtTrigger();
        _hasLoadedChapter4AfterPast = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_after_past.json',
        );
        break;
      case SaveCheckpoint.chapter4MakingBread:
        lockAtTrigger();
        _hasLoadedChapter4AfterPast = true;
        _hasLoadedChapter4MakingBread = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_making_bread.json',
        );
        break;
      case SaveCheckpoint.chapter4AfterLetter:
        lockAtTrigger();
        _hasLoadedChapter4AfterPast = true;
        _hasLoadedChapter4MakingBread = true;
        _hasLoadedChapter4AfterLetter = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_after_letter.json',
        );
        break;
      case SaveCheckpoint.chapter4AfterMaking:
        lockAtTrigger();
        _hasLoadedChapter4AfterPast = true;
        _hasLoadedChapter4MakingBread = true;
        _hasLoadedChapter4AfterLetter = true;
        _hasLoadedChapter4AfterMaking = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_after_making.json',
        );
        break;
      case SaveCheckpoint.chapter5Eat:
        lockAtTrigger();
        _hasLoadedChapter5Eat = true;
        _sceneController.loadDialogue('assets/lines/chapter5/chapter5_eat.json');
        break;
      case SaveCheckpoint.chapter5AfterEat:
        lockAtTrigger();
        _hasLoadedChapter5Eat = true;
        _hasLoadedChapter5AfterEat = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter5/chapter5_after_eat.json',
        );
        break;
      case SaveCheckpoint.chapter5Hidden:
        lockAtTrigger();
        _hasLoadedChapter5Eat = true;
        _hasLoadedChapter5AfterEat = true;
        _hasLoadedChapter5Hidden = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter5/chapter5_hidden.json',
        );
        break;
      default:
        // 이 화면(kitchen_screen.dart) 소관이 아닌 체크포인트(chaeon_room_screen.dart/
        // game_play_screen.dart 쪽)가 잘못 넘어온 경우를 대비한 방어적 분기 - 그냥 이
        // mode의 정상 진입 흐름으로 흘려보냄
        if (widget.mode == KitchenScreenMode.chapter2Start) {
          _sceneController.loadDialogue(
            'assets/lines/chapter2/chapter2_ready.json',
          );
        }
    }
  }

  // 지금 mode 기준으로, _hasLoadedXxx 플래그들을 훑어서 "가장 최근에 통과한 체크포인트"를
  // 찾음. onDialogueEnd 체이닝이랑 동일한 순서로, 가장 나중 단계 플래그부터 거꾸로 확인함.
  // 저장 버튼(MenuOverlay.onSave)이 이 화면에 떠 있다는 것 자체가 컷씬/미니게임/팝업 같은
  // 중간 연출이 아니라 안정된 상태라는 뜻이라(그런 연출 중엔 설정 버튼 자체가 안 눌림),
  // 이 시점의 플래그 조합만으로 체크포인트를 확정할 수 있음
  SaveCheckpoint _detectCurrentCheckpoint() {
    switch (widget.mode) {
      case KitchenScreenMode.chapter2Start:
        if (_hasLoadedAfterSecondGameDialogue) {
          return SaveCheckpoint.chapter2AfterSecondGame;
        }
        if (_hasLoadedAfterFirstGameDialogue) {
          return SaveCheckpoint.chapter2AfterFirstGame;
        }
        if (_hasLoadedMakingBreadDialogue) {
          return SaveCheckpoint.chapter2MakingBread;
        }
        if (_hasLoadedAfterQuizDialogue) return SaveCheckpoint.chapter2AfterQuiz;
        if (_hasLoadedIngredientQuiz) return SaveCheckpoint.chapter2IngredientQuiz;
        return SaveCheckpoint.chapter2Ready;
      case KitchenScreenMode.chapter3Start:
        if (_hasLoadedChapter3AfterEatDialogue) {
          return SaveCheckpoint.chapter3AfterEat;
        }
        if (_hasLoadedChapter3AfterFirstGameDialogue) {
          return SaveCheckpoint.chapter3AfterFirstGame;
        }
        if (_hasLoadedBeforeGame) return SaveCheckpoint.chapter3BeforeGame;
        return SaveCheckpoint.chapter3ChaeonRoomAfter;
      case KitchenScreenMode.chapter4Start:
        if (_hasLoadedChapter4AfterMaking) {
          return SaveCheckpoint.chapter4AfterMaking;
        }
        if (_hasLoadedChapter4AfterLetter) {
          return SaveCheckpoint.chapter4AfterLetter;
        }
        if (_hasLoadedChapter4MakingBread) {
          return SaveCheckpoint.chapter4MakingBread;
        }
        if (_hasLoadedChapter4AfterPast) return SaveCheckpoint.chapter4AfterPast;
        return SaveCheckpoint.chapter4BeforeCutscene;
      case KitchenScreenMode.chapter5Start:
        if (_hasLoadedChapter5Hidden) return SaveCheckpoint.chapter5Hidden;
        if (_hasLoadedChapter5AfterEat) return SaveCheckpoint.chapter5AfterEat;
        if (_hasLoadedChapter5Eat) return SaveCheckpoint.chapter5Eat;
        return SaveCheckpoint.chapter5Bear;
      case KitchenScreenMode.chapter1End:
        // 이 모드는 체크포인트가 chapter1KitchenArrival 하나뿐임(kitchen_arrival.json이
        // 끝나면 바로 임시 종료 화면으로 감, 그 사이 추가 체크포인트 없음)
        return SaveCheckpoint.chapter1KitchenArrival;
    }
  }

  // 메뉴 "저장" 버튼(MenuOverlay.onSave)이 부름. 지금 통과한 체크포인트를 판단해서 저장하고,
  // 메뉴를 닫은 뒤 확인 문구를 2초간 띄움
  void _handleSave() async {
    final SaveCheckpoint checkpoint = _detectCurrentCheckpoint();
    await SaveManager.save(checkpoint);
    if (!mounted) return;
    setState(() {
      _isSettingOpen = false;
      _saveConfirmationText = '저장되었습니다';
    });
    _saveConfirmationTimer?.cancel();
    _saveConfirmationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _saveConfirmationText = null);
    });
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  // 시계 맞추기 미니게임이 끝나면 chaeon_emotion_0to20.gif를 3초간 보여준 뒤,
  // chaeon_20.gif 상태로 넘어가면서 chapter2_after_second_game.json을 이어붙임.
  void _loadSecondGameDialogueAfterEmotionGif() {
    _chaeonEmotion0to20Timer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      setState(() {
        _showChaeonEmotion0to20 = false;
        _showChaeon20 = true;
      });
      _hasLoadedAfterSecondGameDialogue = true;
      _sceneController.loadDialogue(
        'assets/lines/chapter2/chapter2_after_second_game.json',
      );
    });
  }

  // 빵만들기 미니게임이 끝나면 화면을 페이드인으로 암전시켰다가, 잠깐 유지 후
  // 페이드아웃으로 다시 밝아지면서 완성된 빵 팝업을 띄움. 챕터2(salt_bread)/챕터3
  // (onion_bread) 둘 다 이 암전을 공유해서 쓰고, 암전이 끝난 뒤 어떤 팝업을 띄울지는
  // onComplete 콜백으로 호출부가 정함. onFullyBlack은 화면이 완전히 까매진 순간(페이드인
  // 완료, hold 시작 직전)에 호출되는데, 이때 뒤에 깔린 위젯을 갈아끼우면(예: 미니게임 ->
  // 주방) 화면이 새까만 채라 전환이 안 보이고 자연스러움. onComplete도 마찬가지로 hold가
  // 끝나고 페이드아웃이 "시작되기 직전"(아직 화면은 새까만 상태)에 호출해서 팝업을 미리
  // 띄워두면, 페이드아웃될 때 주방이 아니라 팝업이 서서히 드러남(주방이 잠깐 보였다가
  // 팝업이 뜨는 끊김 방지). 유지 시간은 _memoryBlackoutHoldDuration 임시값, 나중에
  // 실제 연출 보면서 조정 예정. game_play_screen.dart의 _transitionToMemoryFlashback과
  // 동일한 페이드 패턴
  void _startMemoryBlackout({
    VoidCallback? onFullyBlack,
    required VoidCallback onComplete,
  }) {
    setState(() {
      _showMemoryBlackout = true;
      _memoryBlackoutOpacity = 0.0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _memoryBlackoutOpacity = 1.0);
    });
    _memoryBlackoutTimer = Timer(_memoryBlackoutFadeInDuration, () {
      if (!mounted) return;
      onFullyBlack?.call();
      _memoryBlackoutTimer = Timer(_memoryBlackoutHoldDuration, () {
        if (!mounted) return;
        onComplete();
        setState(() => _memoryBlackoutOpacity = 0.0);
        _memoryBlackoutTimer = Timer(_memoryBlackoutFadeOutDuration, () {
          if (!mounted) return;
          setState(() => _showMemoryBlackout = false);
        });
      });
    });
  }

  // chapter5_eat.json 끝나고 시작되는 회상씬 앞부분: 암전(_startMemoryBlackout 재사용) ->
  // playground_bg(_chapter5PlaygroundHoldDuration만큼 노출) -> bear_bg+팔로 컷 전환 ->
  // 안내창 순으로 이어짐. 안내창을 탭하면(렌더링 쪽에서 처리) BearArmPuzzleScene으로 넘어감.
  // playground_bg는 onFullyBlack(화면이 진짜로 완전히 까매진 순간)에서 켜야 함 - onComplete는
  // hold가 끝나고 페이드아웃 "시작 직전"이라 아직 까맣긴 하지만, 그 전에 이미 화면이 까만
  // 채로 유지되는 hold 구간 내내 떠있어야 하는 playground_bg를 그때서야 켜면 너무 늦음
  void _startChapter5MemorySequence() {
    _startMemoryBlackout(
      onFullyBlack: () {
        setState(() => _showChapter5Playground = true);
      },
      onComplete: () {
        _chapter5PlaygroundTimer = Timer(_chapter5PlaygroundHoldDuration, () {
          if (!mounted) return;
          setState(() {
            _showChapter5Playground = false;
            _showChapter5BearIntro = true;
          });
          _chapter5BearIntroGuideTimer = Timer(_chapter5BearIntroGuideDelay, () {
            if (!mounted) return;
            setState(() => _showChapter5BearIntroGuide = true);
          });
        });
      },
    );
  }

  // chapter5_hidden.json 끝나면(line_006) 시작되는 히든엔딩 전환: 암전(_startMemoryBlackout
  // 재사용, 기본 유지 시간 그대로) -> 히든엔딩 컷씬(_showChapter5EndingHiddenCutscene) 순으로 이어짐
  void _startChapter5HiddenEndingSequence() {
    _startMemoryBlackout(
      onComplete: () {
        setState(() => _showChapter5EndingHiddenCutscene = true);
      },
    );
  }

  // chapter3_after_first_game.json 끝나면 시작되는 일기장 퍼즐 시퀀스 앞부분: 암전 ->
  // 일기장 인트로 이미지 -> DiaryPuzzleScene 순으로 이어짐. 퍼즐 완성 이후는
  // _onChapter3DiaryPuzzleComplete에서 이어받음
  void _startChapter3DiarySequence() {
    setState(() => _showChapter3DiaryBlackout = true);
    _chapter3DiaryBlackoutTimer = Timer(_chapter3DiaryBlackoutHoldDuration, () {
      if (!mounted) return;
      setState(() {
        _showChapter3DiaryBlackout = false;
        _showChapter3DiaryIntro = true;
      });
      // DiaryPuzzleScene은 자기가 마운트되는 시점(=이 인트로가 끝나는 시점)에야 자체
      // didChangeDependencies에서 프리캐싱을 시작하는데, diary_puzzle_bg.png가 약 8MB로
      // 퍼즐 조각 이미지(장당 100~140KB, 60~80배 작음)보다 디코딩이 훨씬 오래 걸려서
      // 조각들이 먼저 뜨고 배경이 뒤늦게 뜨는 것처럼 보였음. 인트로가 떠 있는 동안(2초)
      // 미리 디코딩을 시작해두면, 퍼즐 화면으로 넘어갈 때는 이미 캐시돼 있어서 한 번에
      // 뜸(precacheImage는 이미 캐시된 이미지를 다시 불러도 그냥 즉시 반환되므로,
      // DiaryPuzzleScene 쪽 프리캐싱 호출과 중복돼도 문제 없음)
      _precacheChapter3DiaryPuzzleAssets();
      _chapter3DiaryIntroTimer = Timer(_chapter3DiaryIntroHoldDuration, () {
        if (!mounted) return;
        setState(() {
          _showChapter3DiaryIntro = false;
          _showChapter3DiaryPuzzle = true;
        });
      });
    });
  }

  // DiaryPuzzleScene(diary_puzzle_scene.dart)이 쓰는 이미지들을 여기서 미리 한 번 더
  // 프리캐싱. 목록은 diary_puzzle_scene.dart의 assetsToPrecache와 동일하게 맞춰둠(그
  // 파일이 바뀌면 여기도 같이 바꿔줘야 함)
  void _precacheChapter3DiaryPuzzleAssets() {
    const List<String> assetsToPrecache = [
      'assets/images/diary_puzzle_bg.png',
      'assets/images/diary_puzzle_completed_bg.png',
      'assets/images/diary_puzzle_completed.png',
      'assets/images/minigame_success.png',
      'assets/images/diary_puzzle_piece_1.png',
      'assets/images/diary_puzzle_piece_2.png',
      'assets/images/diary_puzzle_piece_3.png',
      'assets/images/diary_puzzle_piece_4.png',
      'assets/images/diary_puzzle_piece_5.png',
      'assets/images/diary_puzzle_piece_6.png',
    ];
    for (final asset in assetsToPrecache) {
      precacheImage(AssetImage(asset), context);
    }
  }

  // DiaryPuzzleScene.onComplete에서 호출됨: 완성 결과 이미지 -> 암전 ->
  // chapter3_after_eat.json 로드 순으로 이어짐
  void _onChapter3DiaryPuzzleComplete() {
    setState(() {
      _showChapter3DiaryPuzzle = false;
      _showChapter3DiarySuccessAfter = true;
    });
    _chapter3DiarySuccessAfterTimer = Timer(
      _chapter3DiarySuccessAfterHoldDuration,
      () {
        if (!mounted) return;
        setState(() {
          _showChapter3DiarySuccessAfter = false;
          _showChapter3DiaryEndBlackout = true;
        });
        _chapter3DiaryEndBlackoutTimer = Timer(
          _chapter3DiaryEndBlackoutHoldDuration,
          () {
            if (!mounted) return;
            setState(() => _showChapter3DiaryEndBlackout = false);
            _hasLoadedChapter3AfterEatDialogue = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter3/chapter3_after_eat.json',
            );
          },
        );
      },
    );
  }

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/kitchen_main.png',
        'assets/images/chaeon_apron_putting_on.gif',
        'assets/images/chaeon_apron_idle.gif',
        'assets/images/lillian_idle.gif',
        // 챕터3 일기장 퍼즐 시퀀스 앞뒤로 뜨는 인트로/결과 이미지. 프리캐싱이 안 돼있으면
        // Image.asset이 디코딩 끝날 때까지 몇 프레임 동안 아무것도 안 그려서 그 밑에 깔려있던
        // 이전 화면이 잠깐 비쳐 보임(부자연스러운 화면 전환의 원인)
        'assets/images/chapter3_diary_intro.png',
        'assets/images/chapter3_diary_success_after.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
      // kitchen_arrival.json / 챕터2 대화 파일들 특정 노드에서 잠깐 바뀌는 릴리안
      // 스프라이트도 미리 프리캐싱
      for (final asset in widgets.kitchenArrivalLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      for (final overrides
          in widgets.chapter2LillianSpriteOverridesByDialogueId.values) {
        for (final asset in overrides.values) {
          precacheImage(AssetImage(asset), context);
        }
      }
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _chaeonEatingTimer?.cancel();
    _chaeonEmotion0to20Timer?.cancel();
    _memoryBlackoutTimer?.cancel();
    _chapter3DiaryBlackoutTimer?.cancel();
    _chapter3DiaryIntroTimer?.cancel();
    _chapter3DiarySuccessAfterTimer?.cancel();
    _chapter3DiaryEndBlackoutTimer?.cancel();
    _chapter5PlaygroundTimer?.cancel();
    _chapter5BearIntroGuideTimer?.cancel();
    _saveConfirmationTimer?.cancel();
    _stairsUpController.dispose();
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    super.dispose();
  }

  // 채온이를 delta만큼 옮기고(배경 밖으로는 안 나가게 clamp), 대사 트리거/왼쪽 끝(계단) 트리거 확인
  void _moveChaeonBy(double delta) {
    setState(() {
      _chaeonX = (_chaeonX + delta).clamp(
        kChaeonKitchenMinX,
        kChaeonKitchenMaxX,
      );
    });
    _checkDialogueTrigger();
    _checkStairsUpTrigger(delta);
  }

  // 릴리안 근처(대사 트리거 x좌표)에 도달하면 이동 잠그고 kitchen_arrival.json 자동 시작
  void _checkDialogueTrigger() {
    if (_hasTriggeredDialogue) return;
    if (_chaeonX >= kKitchenDialogueTriggerX) {
      _hasTriggeredDialogue = true;
      _moveTimer?.cancel();
      setState(() {
        _movementLocked = true;
        _chaeonState = 'idle';
      });
      // 챕터3 모드는 kitchen_arrival.json 대신 chapter3_chaeon_room_after.json을,
      // 챕터4 모드는 chapter4_before_cutscene.json을,
      // 챕터5 모드는 chapter5_bear.json을 로드함
      _sceneController.loadDialogue(
        widget.mode == KitchenScreenMode.chapter3Start
            ? 'assets/lines/chapter3/chapter3_chaeon_room_after.json'
            : widget.mode == KitchenScreenMode.chapter4Start
            ? 'assets/lines/chapter4/chapter4_before_cutscene.json'
            : widget.mode == KitchenScreenMode.chapter5Start
            ? 'assets/lines/chapter5/chapter5_bear.json'
            : 'assets/lines/chapter1/kitchen_arrival.json',
      );
    }
  }

  // 왼쪽 끝(계단 있는 곳)까지 계속 왼쪽으로 이동하려 하면 다시 계단을 올라가 빵집으로 돌아감.
  // chapter1End/chapter3Start 둘 다 GamePlayScreen에서 Navigator.push로 열린 경우라
  // 돌아갈 화면이 있으므로 둘 다 동작함. chapter2Start는 그렇지 않아서 제외
  bool _hasTriggeredStairsUp = false;
  void _checkStairsUpTrigger(double delta) {
    if (_hasTriggeredStairsUp) return;
    if (widget.mode == KitchenScreenMode.chapter2Start) return;
    if (delta < 0 && _chaeonX <= kChaeonKitchenMinX) {
      _hasTriggeredStairsUp = true;
      _moveTimer?.cancel();
      setState(() {
        _movementLocked = true;
        _chaeonState = 'idle';
      });
      _triggerChaeonStairsAscent();
    }
  }

  // 내려올 때(game_play_screen.dart의 _triggerChaeonStairsDescent)와 동일한 패턴으로,
  // _stairsAscentStart에서 _stairsAscentEnd로 이동하는 애니메이션을 재생. 끝나면 보통은
  // 화면을 pop하는데, _pendingChapter4RoomExit이면 대신 채온이 방으로 넘어감(위 상태
  // 리스너 참고)
  void _triggerChaeonStairsAscent() {
    _stairsUpAnimation =
        Tween<Offset>(begin: _stairsAscentStart, end: _stairsAscentEnd).animate(
          CurvedAnimation(parent: _stairsUpController, curve: Curves.easeIn),
        );
    setState(() => _isChaeonAscendingStairs = true);
    _stairsUpController.forward(from: 0);
  }

  // chapter4_after_making.json 끝나고 나오는 스크립트 연출: 플레이어 입력 없이 채온이가
  // 자동으로 왼쪽 계단 위치(kChaeonKitchenMinX)까지 걸어간 다음, 계단 올라가기 애니메이션
  // (_triggerChaeonStairsAscent, dpad로 계단까지 걸어갔을 때랑 동일한 연출)을 그대로
  // 재생함. 다 올라가면 _pendingChapter4RoomExit 덕분에 pop 대신 암전 후 채온이 방으로 넘어감
  void _startChapter4ExitWalk() {
    _moveTimer?.cancel();
    setState(() {
      _movementLocked = true;
      _chaeonState = 'walk';
      _isChaeonFacingLeft = true;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      setState(() => _chaeonX -= 9.0);
      if (_chaeonX <= kChaeonKitchenMinX) {
        timer.cancel();
        setState(() {
          _chaeonX = kChaeonKitchenMinX;
          _chaeonState = 'idle';
          _pendingChapter4RoomExit = true;
        });
        _triggerChaeonStairsAscent();
      }
    });
  }

  void _startMoving(int direction) {
    if (_movementLocked) return;
    _moveTimer?.cancel();
    setState(() {
      _chaeonState = 'walk';
      _isChaeonFacingLeft = direction < 0;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      // 225px/초 * 40ms = 9px, 튜토리얼 화면이랑 동일한 틱당 이동량
      _moveChaeonBy(direction * 9.0);
    });
  }

  void _stopMoving() {
    _moveTimer?.cancel();
    if (!_movementLocked) {
      setState(() => _chaeonState = 'idle');
    }
  }

  // 현재 노드에 expression이 있으면 그 표정으로, 없으면 기본 idle GIF로
  String _resolveLillianSprite(String? sceneNodeId) {
    final DialogueNode? node =
        _sceneController.sceneDialogue?.nodes[sceneNodeId];
    // speaker가 lillian인 노드의 expression만 반영함. 안 그러면 채온이 대사 노드에 달린
    // expression(예: chapter3_after_first_game.json의 빵 먹는 GIF)까지 릴리안한테 새어감
    final String? expressionAsset = node?.speaker == 'lillian'
        ? node?.expression?.asset
        : null;
    if (expressionAsset != null) return expressionAsset;
    return 'assets/images/lillian_idle.gif';
  }

  // 채온이 스프라이트 오버라이드 우선순위: chaeonExpression(발화자 무관, 예:
  // chapter3_after_eat.json line_002 이후 chaeon_50.gif로 고정) > 노드 발화자가
  // 채온이일 때의 expression(예: chapter3_after_first_game.json의 빵 먹는 GIF).
  // game_play_screen.dart의 _resolveChaeonExpressionSprite와 동일한 우선순위 규칙.
  // 아무것도 없으면 null을 반환하고, 호출부의 기존 삼항연산자 체인을 그대로 타서
  // 원래대로(_showChaeonEating 등 플래그 기반) 표시됨
  String? _resolveChaeonExpressionSprite(String? sceneNodeId) {
    final DialogueNode? node =
        _sceneController.sceneDialogue?.nodes[sceneNodeId];
    if (node == null) return null;
    if (node.chaeonExpression != null) return node.chaeonExpression!.asset;
    if (node.speaker != 'chaeon') return null;
    return node.expression?.asset;
  }

  // 채온이 스프라이트 위젯. 릴리안(_resolveLillianSprite, 항상 PopInImage로 그림)과
  // 달리 예전엔 "expression이 있을 때만 PopInImage, 없으면 그냥 Image.asset"으로 위젯
  // 타입 자체가 바뀌었었음. Flutter는 위젯 타입이 바뀌면 이전 PopInImage를 버리고
  // 새로 만들기 때문에, chaeon_20_eat처럼 expression으로 처음 들어가는 순간 크로스페이드
  // 없이 뚝 튀어 나타나는 문제가 있었음(릴리안은 항상 같은 PopInImage 인스턴스가
  // 유지되니까 문제 없었음). 그래서 이제 채온이도 항상 PopInImage 하나로 그리되,
  // duration으로 구간을 구분함: expression으로 들어가거나 나갈 때(표정 전환)는 페이드,
  // 걷기/정지 전환(기본 상태끼리)은 dpad에 바로 반응해야 자연스러워서 즉시(0ms) 전환됨
  Widget _buildChaeonSprite({
    required String? sceneNodeId,
    required double size,
  }) {
    // chapter2_after_first_game.json 종료 직후엔 chaeon_0_eat.gif, 시계 미니게임 이후엔
    // chaeon_emotion_0to20.gif -> chaeon_20.gif 순으로, 다른 상태와 무관하게 우선 보여줌.
    // 계단을 올라가는 중엔 그 시점 _chaeonState와 무관하게 항상 apron_idle.gif로 고정
    // (game_play_screen.dart의 하강 연출과 동일한 규칙)
    final String defaultSprite = _showChaeonEating
        ? 'assets/images/chaeon_0_eat.gif'
        : _showChaeonEmotion0to20
        ? 'assets/images/chaeon_emotion_0to20.gif'
        : _showChaeon20
        ? 'assets/images/chaeon_20.gif'
        // 챕터3 주방(kitchen_main)에서는 idle 기본값을 chaeon_20.gif로,
        // 걷는 중/계단 올라가는 중엔 chaeon_apron_20.gif로 씀
        // (계단 내려가는 쪽은 game_play_screen.dart에서 chaeon_20_normal_walk.gif)
        : widget.mode == KitchenScreenMode.chapter3Start
        ? (_isChaeonAscendingStairs || _chaeonState == 'walk'
              ? 'assets/images/chaeon_apron_20.gif'
              : 'assets/images/chaeon_20.gif')
        // 챕터4는 감정 온도가 더 오른 상태라 기본 스프라이트를 50% 버전으로 씀
        : widget.mode == KitchenScreenMode.chapter4Start
        ? (_isChaeonAscendingStairs || _chaeonState == 'walk'
              ? 'assets/images/chaeon_apron_50.gif'
              : 'assets/images/chaeon_50.gif')
        // 챕터5는 감정 온도가 더 오른 상태라 기본 스프라이트를 80% 버전으로 씀
        : widget.mode == KitchenScreenMode.chapter5Start
        ? (_isChaeonAscendingStairs || _chaeonState == 'walk'
              ? 'assets/images/chaeon_apron_80.gif'
              : 'assets/images/chaeon_80.gif')
        : _isChaeonAscendingStairs || _chaeonState == 'walk'
        ? 'assets/images/chaeon_apron_idle.gif'
        : 'assets/images/chaeon_apron_putting_on.gif';

    // 채온이 대사 노드에 expression이 있으면(예: chapter3_after_first_game.json의
    // 빵 먹는 GIF) 이 체인보다도 우선순위 높게 그걸 먼저 보여줌
    final String? expressionSprite = _resolveChaeonExpressionSprite(
      sceneNodeId,
    );
    final String finalChaeonSprite = expressionSprite ?? defaultSprite;
    return PopInImage(
      imagePath: finalChaeonSprite,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 120ms는 팔을 내린/올린 자세처럼 포즈 차이가 큰 표정 사이에서 크로스페이드가
      // 눈에 띄게 느적거려 보여서(팔이 흐릿하게 걸쳐 있다가 올라가는 것처럼 보임) 50ms로
      // 줄임. widgets.chaeonEatingSprites(빵 먹는 진행 단계 GIF)로 바뀔 때는 그마저도
      // 어색해서 아예 즉시(0ms) 전환되도록 예외 처리함
      duration: widgets.chaeonEatingSprites.contains(finalChaeonSprite)
          ? Duration.zero
          : expressionSprite != null
          ? const Duration(milliseconds: 50)
          : Duration.zero,
    );
  }

  // 뒤로가기 버튼: 타이핑 중이면 텍스트 다 보여주고, 아니면 이전 대사로 되돌아감
  void _handleBackButtonTap() {
    _sceneController.goBackScene();
  }

  // 챕터 1 종료 임시 화면 탭하면 챕터 선택창으로 이동. tutorial_screen.dart에서 빵집 문 클릭 시
  // GamePlayScreen으로 넘어가는 것과 동일하게 pushReplacement로 스택 정리
  void _handleChapterEndTap() {
    // 챕터1 엔딩을 다 봤으니 챕터2 해금. 챕터2 모드(이미 해금된 상태)에서 탭할 땐 안 해도 됨
    if (widget.mode == KitchenScreenMode.chapter1End) {
      ChapterProgress.isChapter2Unlocked = true;
    } else if (widget.mode == KitchenScreenMode.chapter2Start) {
      // 챕터2 완전 종료(chapter2_after_second_game.json까지 다 봄)했으니 챕터3 해금
      ChapterProgress.isChapter3Unlocked = true;
    } else if (widget.mode == KitchenScreenMode.chapter3Start) {
      // 챕터3 완전 종료(일기장 퍼즐 시퀀스 끝)했으니 챕터4 해금
      ChapterProgress.isChapter4Unlocked = true;
    }
    Navigator.pushReplacement(
      context,
      fadeThroughBlackRoute(const ChapterSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;
    // UI 크롬(온도계, 버튼, dpad 등 화면 가장자리에 고정되는 요소)은 game_play_screen.dart(빵집)와
    // 완전히 동일한 기준(874x402)으로 스케일해야 크기/위치가 두 화면에서 똑같이 보임
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 배경(kitchen_main.png)이 항상 화면을 빈틈없이 꽉 채우도록, 가로/세로 중 더 많이
    // 확대해야 하는 쪽 기준으로 스케일함(cover). 가로 기준(w/874)만 쓰면 창을 세로로
    // 늘렸을 때 계산된 배경 높이가 실제 화면 높이보다 작아져서 위쪽에 빈 공간이 생겼음
    final double worldScale = (w / 874) > (h / 464) ? (w / 874) : (h / 464);
    // 가로가 남으면(세로로 긴 창) 좌우를 대칭으로 잘라내고, 세로가 남으면(원래 케이스)
    // 이미지 하단에서 8px 위 지점(월드 좌표 464-8=456)이 화면 하단에 오도록 맞춤
    final double worldOffsetX = (w - 874 * worldScale) / 2;
    final double worldOffsetY = h - (464 - 8) * worldScale;
    // 배경 이미지 안 좌표(월드 좌표)를 실제 화면 좌표로 바꿔줌. 위치는 레터박스 오프셋을 더해야 하고,
    // 크기(width/height)는 오프셋 없이 scale만 곱하면 됨
    double wX(double px) => worldOffsetX + px * worldScale;
    double wY(double px) => worldOffsetY + px * worldScale;
    double wSize(double px) => px * worldScale;
    // 채온/릴리안 전용 크기: 배경(kitchen_main.png)을 채우는 worldScale(가로/세로 중 큰 쪽
    // 기준 cover)이 아니라, game_play_screen.dart(빵집)와 동일하게 화면 높이에만 비례하는
    // rH를 그대로 씀. worldScale을 쓰면 화면 비율에 따라 가로 기준으로 걸릴 때(예: 가로로
    // 넓은 모바일 화면) 캐릭터 크기가 세로 변화에 반응하지 않아 빵집과 다르게 보이는 문제가
    // 있었음. kChaeonKitchenTopY/kLillianKitchenTopY는 캐릭터가 wSize(172) 크기로 그려질
    // 때를 기준으로 맞춰둔 발(바닥) 위치라서, characterSize가 그보다 커지거나 작아진 만큼
    // top을 위/아래로 당겨야 발이 바닥에 그대로 붙어 보임. 차이의 "절반"만 당기면 발이 계속
    // 뜨거나 파고들어 보이므로(세로 중심만 맞고 발 위치는 안 맞음), 차이 전체를 당겨야 함
    final double characterSize = rH(172);
    final double characterTopShift = characterSize - wSize(172);
    // 모바일에 가까운 화면(가로가 길고 세로가 짧은 화면, worldScale이 w/874로 걸리는
    // 경우 — 배경 위쪽이 잘리는 와이드한 화면. 실제 모바일 가로모드 대부분 여기 해당)
    // 에서만 채온/릴리안을 살짝 더 아래로 내림. worldScale이 h/464로 걸리는 화면(일반
    // 데스크톱 16:9 창 등)은 기존 위치 그대로 유지. 숫자를 늘리면 더 아래로, 줄이면 덜
    // 내려감(kKitchenMobileCharacterDropRef는 874x402 기준 rH로 스케일되는 값)
    final bool isMobileLikeAspect = (w / 874) > (h / 464);
    final double mobileCharacterDrop = isMobileLikeAspect
        ? rH(kKitchenMobileCharacterDropRef)
        : 0;
    // top 계산에 쓰는 최종 보정값. mobileCharacterDrop만큼 덜 끌어올려서 그만큼 아래로 내려감
    final double characterVerticalOffset =
        characterTopShift - mobileCharacterDrop;

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;

    // 채온이/릴리안 둘 다 Positioned의 left가 스프라이트 왼쪽 끝 기준이라(중앙 기준 보정 없음),
    // 말풍선 가로 중심은 거기에 스프라이트 폭의 절반을 더해야 실제 캐릭터 중심과 맞음
    final double chaeonCenterX = wX(_chaeonX) + characterSize / 2;
    final double lillianCenterX = wX(kLillianKitchenX) + characterSize / 2;
    // 말풍선 앵커: 각 캐릭터가 실제로 서있는 kitchen_main.png 좌표(wY) 기준.
    // 캐릭터 렌더링 top과 동일하게 characterVerticalOffset만큼 위로 보정해야 커진
    // 스프라이트 머리 위치랑 어긋나지 않음
    final double chaeonSpriteTopY =
        wY(kChaeonKitchenTopY) - characterVerticalOffset;
    final double lillianSpriteTopY =
        wY(kLillianKitchenTopY) - characterVerticalOffset;

    // 챕터5 회상씬(곰인형 팔 붙이기) 전용 좌표계. bear_arm_puzzle_scene.dart의
    // kBearArmCanvasWidth/kBearArmCanvasHeight(874x507)랑 동일하게 맞춰서, 여기서 보여주는
    // bear_bg+팔 미리보기가 실제 BearArmPuzzleScene 시작 화면이랑 완전히 똑같이 보이게 함
    final double chapter5BearScale = w / kBearArmCanvasWidth;
    final double chapter5BearAnchorY =
        (h - kBearArmCanvasHeight * chapter5BearScale) / 2;
    double chapter5BearWX(double refX) => refX * chapter5BearScale;
    double chapter5BearWY(double refY) =>
        chapter5BearAnchorY + refY * chapter5BearScale;
    double chapter5BearWSize(double refSize) => refSize * chapter5BearScale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 배경. 874:464 비율 유지한 채로 화면을 빈틈없이 꽉 채움
            // (화면 비율이 안 맞으면 초과분은 좌우 또는 위쪽이 화면 밖으로 잘려나감)
            Positioned(
              left: worldOffsetX,
              top: worldOffsetY,
              width: wSize(874),
              height: wSize(464),
              child: Image.asset(
                'assets/images/kitchen_main.png',
                fit: BoxFit.fill,
              ),
            ),

            // 2층: 릴리안. 화면 안 고정된 위치에 정지 상태(idle)로 서있음
            Positioned(
              key: const ValueKey('kitchen_lillian'),
              left: wX(kLillianKitchenX),
              top: wY(kLillianKitchenTopY) - characterVerticalOffset,
              child: PopInImage(
                imagePath: _resolveLillianSprite(sceneNodeId),
                width: characterSize,
                height: characterSize,
                fit: BoxFit.contain,
              ),
            ),

            // 3층: 채온이. dpad로 좌우 이동, 대사 트리거 이후로는 제자리에 고정.
            // 앞치마 입고 걷는 전용 애니메이션 에셋이 아직 없어서, game_play_screen.dart의
            // kitchenApproach 단계와 동일하게 walk 상태일 땐 chaeon_apron_idle.gif를,
            // idle 상태일 땐 chaeon_apron_putting_on.gif를 대신 보여줌
            Positioned(
              key: const ValueKey('kitchen_chaeon'),
              left: wX(
                _isChaeonAscendingStairs
                    ? (_stairsUpAnimation?.value.dx ?? _chaeonX)
                    : _chaeonX,
              ),
              top:
                  wY(
                    _isChaeonAscendingStairs
                        ? (_stairsUpAnimation?.value.dy ?? kChaeonKitchenTopY)
                        : kChaeonKitchenTopY,
                  ) -
                  characterVerticalOffset,
              child: Transform.flip(
                flipX: _isChaeonFacingLeft,
                child: _buildChaeonSprite(
                  sceneNodeId: sceneNodeId,
                  size: characterSize,
                ),
              ),
            ),

            // 3-2층: 배경 오브젝트 클릭 히트박스. 방향키가 나와있을 때(!_movementLocked)만 활성화.
            // 온도계/뒤로가기/설정 버튼(5~7층)보다 아래에 있어야 버튼 영역과 겹치는 히트박스가
            // 버튼 탭을 가로채지 않음 (겹치면 버튼이 안 눌리는 문제가 생김)
            if (!_movementLocked)
              for (final obj in _interactionObjects)
                Positioned(
                  key: ValueKey('kitchen_interaction_${obj.id}'),
                  left: wX(obj.clickX),
                  top: wY(obj.clickY),
                  width: wSize(obj.width),
                  height: wSize(obj.height),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => _interactionText = obj.dialogue.join('\n'),
                    ),
                  ),
                ),

            // 4층: kitchen_arrival.json 대사창. SceneDialogueController + buildSceneBubble 그대로 재사용
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('kitchen_dialogue_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sceneController.advanceScene,
                  child: Stack(
                    children: [
                      if (currentSceneNode.spans.isNotEmpty &&
                          _sceneController.bubbleRevealed)
                        widgets.buildSceneBubble(
                          node: currentSceneNode,
                          rW: rW,
                          rH: rH,
                          chaeonCenterX: chaeonCenterX,
                          lillianCenterX: lillianCenterX,
                          typedCharCount: _sceneController.typedCharCount,
                          // 각 캐릭터 머리 위에 바로 붙도록 실제 스프라이트 top을 넘겨줌
                          chaeonSpriteTopY: chaeonSpriteTopY,
                          lillianSpriteTopY: lillianSpriteTopY,
                        ),
                    ],
                  ),
                ),
              ),

            // 4-2층: choice 노드 대사창. game_play_screen.dart 13층이랑 동일한 패턴으로
            // 직전 line 노드 말풍선(lastLineNode)은 어두운 배경 아래 계속 보여주고, 그 위에
            // 선택지 버튼을 띄움. onChooseOption에서 chooseSceneOption 호출해서 다음 노드로 진행
            if (currentSceneNode != null && currentSceneNode.type == 'choice')
              Positioned.fill(
                key: const ValueKey('kitchen_choice_layer'),
                child: Stack(
                  children: [
                    if (_sceneController.lastLineNode != null)
                      widgets.buildSceneBubble(
                        node: _sceneController.lastLineNode!,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: chaeonCenterX,
                        lillianCenterX: lillianCenterX,
                        typedCharCount: _sceneController.typedCharCount,
                        charCount: _sceneController.lastLineNode!.spans
                            .fold<int>(0, (sum, s) => sum + s.text.length),
                        // 각 캐릭터 머리 위에 바로 붙도록 실제 스프라이트 top을 넘겨줌
                        chaeonSpriteTopY: chaeonSpriteTopY,
                        lillianSpriteTopY: lillianSpriteTopY,
                      ),
                    widgets.buildSceneChoices(
                      node: currentSceneNode,
                      rW: rW,
                      rH: rH,
                      onChooseOption: _sceneController.chooseSceneOption,
                    ),
                  ],
                ),
              ),

            // 5층: 온도계 (기존 화면들이랑 톤 맞추려고 그대로 재사용)
            widgets.buildThermometer(
              key: 'kitchen_thermometer',
              rW: rW,
              rH: rH,
              temperature: _sceneController.temperature,
              temperatureChangeText: _sceneController.temperatureChangeText,
            ),

            // 6층: 뒤로가기 버튼
            widgets.buildBackButton(
              key: 'kitchen_back',
              rW: rW,
              rH: rH,
              onTap: _handleBackButtonTap,
            ),

            // 7층: 설정 버튼
            widgets.buildSettingButton(
              key: 'kitchen_setting',
              rW: rW,
              rH: rH,
              onTap: () => setState(() => _isSettingOpen = true),
            ),

            // 8층: 가상 패드. 이동 잠기면(대사 트리거 이후) 숨김
            if (!_movementLocked) ...[
              Positioned(
                key: const ValueKey('kitchen_dpad_left'),
                left: rW(686),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_left.png',
                  onTapDown: () => _startMoving(-1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                ),
              ),
              Positioned(
                key: const ValueKey('kitchen_dpad_right'),
                left: rW(778),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_right.png',
                  onTapDown: () => _startMoving(1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                ),
              ),
            ],

            // 8-2층: 오브젝트 클릭 정보성 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('kitchen_interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 8-3층: 오브젝트 클릭 정보성 팝업 텍스트창
            if (_interactionText != null)
              widgets.buildInteractionBox(
                text: _interactionText!,
                rW: rW,
                rH: rH,
              ),

            // 9층: 공용 메뉴 오버레이. 다른 화면들이랑 동일한 MenuOverlay 재사용
            if (_isSettingOpen)
              MenuOverlay(
                rW: rW,
                rH: rH,
                isAutoAdvanceEnabled: StoryState.isAutoAdvanceEnabled,
                onClose: () => setState(() => _isSettingOpen = false),
                onToggleAuto: () => setState(
                  () => StoryState.isAutoAdvanceEnabled =
                      !StoryState.isAutoAdvanceEnabled,
                ),
                onSave: _handleSave,
                onGoToMainScreen: () => Navigator.of(context).pushAndRemoveUntil(
                  fadeThroughBlackRoute(const ChoiceScreen()),
                  (route) => false,
                ),
                onExitGame: exitGame,
              ),

            // 9-1층: 저장 완료 안내 배지. _handleSave가 저장 끝내고 잠깐(2초) 띄웠다가 스스로 지움.
            // 딤을 더 진하게 주려고 buildSaveConfirmationBadge(0.7) 재사용, 위치는 화면 상단 중앙
            if (_saveConfirmationText != null)
              Positioned(
                top: rH(_saveConfirmationBadgeTopRef),
                left: 0,
                right: 0,
                child: Center(
                  child: widgets.buildSaveConfirmationBadge(
                    _saveConfirmationText!,
                    rW: rW,
                    rH: rH,
                  ),
                ),
              ),

            // 9-2층: 재료 획득 팝업. chapter2_ingredient_quiz.json의 재료 이름 대사가 끝나고
            // 탭하면 뜸. tutorial_dialogue_box(570x300) 뒤에 검은 50% 배경, 그 위에
            // 선택한 재료 이미지 표시. 탭하면 닫히고 chapter2_after_quiz.json으로 이어짐
            if (_showIngredientPopup)
              Positioned.fill(
                key: const ValueKey('ingredient_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showIngredientPopup = false);
                    _hasLoadedAfterQuizDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter2/chapter2_after_quiz.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 그냥 Image.asset + BoxFit.fill로 그리면 원본 이미지 비율
                            // (1119x285)이랑 팝업 비율이 많이 달라서 테두리가 가로/세로로
                            // 다르게 늘어나 깨져 보임. DialogueBoxFrame이랑 동일하게
                            // centerSlice(9-slice)로 그려서 모서리 두께를 유지함
                            SizedBox(
                              width: rW(570),
                              height: rH(300),
                              // widgets.ScaledNineSliceImage로 그리면 화면 배율이 달라져도
                              // 테두리 두께가 다른 UI 요소들과 똑같이 같이 얇아지거나
                              // 두꺼워짐(기존 DecorationImage+centerSlice는 테두리가 항상
                              // 원본 픽셀 크기로 고정되는 문제가 있었음)
                              child: ScaledNineSliceImage(
                                imagePath: 'assets/images/tutorial_dialogue_box.png',
                                sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                                scaleX: rW(1),
                                scaleY: rH(1),
                              ),
                            ),
                            if (StoryState.resolveIngredientImage() != null)
                              Image.asset(
                                StoryState.resolveIngredientImage()!,
                                width: rW(300),
                                height: rH(300),
                                fit: BoxFit.contain,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-3층: 빵만들기 미니게임. chapter2_after_quiz.json 대화가 끝나면 뜨고,
            // 최상단에서 화면을 전부 덮음. 완성된 반죽 화면을 탭하면 주방으로 돌아가고
            // 바로 chapter2_making_bread.json 대사가 이어짐(onComplete). 그 대사가 끝나면
            // onDialogueEnd의 _hasLoadedMakingBreadDialogue 분기가 암전 -> 재점등 ->
            // salt_bread 팝업으로 이어받음
            if (_showBreadMakingGame)
              Positioned.fill(
                key: const ValueKey('bread_making_game'),
                child: BreadMakingScene(
                  onComplete: () {
                    setState(() => _showBreadMakingGame = false);
                    _hasLoadedMakingBreadDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter2/chapter2_making_bread.json',
                    );
                  },
                ),
              ),

            // 9-4층: 완성된 빵(salt_bread) 팝업. chapter2_making_bread.json 대사 ->
            // 암전 -> 재점등 후에 뜸(_startMemoryBlackout). 재료 획득 팝업이랑 동일한 연출
            // (검은 50% 배경 + tutorial_dialogue_box 570x300 + 이미지 300x300).
            // 탭하면 닫히고 chapter2_after_first_game.json으로 이어짐
            if (_showBreadPopup)
              Positioned.fill(
                key: const ValueKey('bread_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showBreadPopup = false);
                    _hasLoadedAfterFirstGameDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter2/chapter2_after_first_game.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: rW(570),
                              height: rH(300),
                              // widgets.ScaledNineSliceImage로 그리면 화면 배율이 달라져도
                              // 테두리 두께가 다른 UI 요소들과 똑같이 같이 얇아지거나
                              // 두꺼워짐(기존 DecorationImage+centerSlice는 테두리가 항상
                              // 원본 픽셀 크기로 고정되는 문제가 있었음)
                              child: ScaledNineSliceImage(
                                imagePath: 'assets/images/tutorial_dialogue_box.png',
                                sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                                scaleX: rW(1),
                                scaleY: rH(1),
                              ),
                            ),
                            Image.asset(
                              'assets/images/salt_bread.png',
                              width: rW(300),
                              height: rH(300),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-5층: 시계 맞추기 미니게임. 빵 팝업 -> chapter2_after_first_game.json ->
            // chaeon_0_eat.gif 노출이 다 끝나면 뜨고, 최상단에서 화면을 전부 덮음.
            // 끝나면(onComplete) chaeon_emotion_0to20.gif를 보여준 뒤
            // chapter2_after_second_game.json으로 이어짐
            if (_showClockMinigame)
              Positioned.fill(
                key: const ValueKey('clock_minigame'),
                child: ClockMinigameScene(
                  onComplete: () {
                    setState(() {
                      _showClockMinigame = false;
                      _showChaeonEmotion0to20 = true;
                    });
                    _loadSecondGameDialogueAfterEmotionGif();
                  },
                ),
              ),

            // 9-7층: 챕터3 첫 번째 미니게임. chapter3_before_game.json이 끝나면 뜨고, 최상단에서
            // 화면을 전부 덮음. 챕터2 BreadMakingScene을 forcedCompletedDoughAsset 없이 그대로
            // 재사용해서, 미니게임 안 완성 반죽 이미지도 챕터2랑 동일하게 재료 조합에 따라
            // StoryState.resolveCompletedDoughImage()로 결정됨. onion_bread.png 고정은 미니게임
            // 자체가 아니라 미니게임 끝나고 뜨는 9-8층 팝업에서만 함
            // 완성 화면을 탭하면 주방으로 돌아가고 빵 팝업이 뜸(onComplete).
            // 다음 대사 로드는 팝업 탭에서 처리함
            if (_showChapter3BreadMakingGame)
              Positioned.fill(
                key: const ValueKey('chapter3_bread_making_game'),
                child: BreadMakingScene(
                  // 챕터3는 SUCCESS 배너를 좀 더 오래 보여줌(챕터2 800ms + 1초)
                  successHoldDurationOverride: const Duration(
                    milliseconds: 1800,
                  ),
                  onComplete: () {
                    // 성공 화면 위로 바로 암전이 덮이도록, 미니게임은 화면이 완전히
                    // 까매진 뒤(onFullyBlack)에야 끔. 그래야 미니게임 -> 주방 화면 전환이
                    // 암전에 가려져서 안 보임
                    _startMemoryBlackout(
                      onFullyBlack: () =>
                          setState(() => _showChapter3BreadMakingGame = false),
                      onComplete: () =>
                          setState(() => _showChapter3BreadPopup = true),
                    );
                  },
                ),
              ),

            // 9-8층: 완성된 빵(onion_bread) 팝업. 챕터2 9-4층(bread_popup_layer)이랑 동일한
            // 연출(검은 50% 배경 + tutorial_dialogue_box 570x300 + 이미지 300x300).
            // 탭하면 닫히고 chapter3_after_first_game.json으로 이어짐
            if (_showChapter3BreadPopup)
              Positioned.fill(
                key: const ValueKey('chapter3_bread_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showChapter3BreadPopup = false);
                    _hasLoadedChapter3AfterFirstGameDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter3/chapter3_after_first_game.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: rW(570),
                              height: rH(300),
                              // widgets.ScaledNineSliceImage로 그리면 화면 배율이 달라져도
                              // 테두리 두께가 다른 UI 요소들과 똑같이 같이 얇아지거나
                              // 두꺼워짐(기존 DecorationImage+centerSlice는 테두리가 항상
                              // 원본 픽셀 크기로 고정되는 문제가 있었음)
                              child: ScaledNineSliceImage(
                                imagePath: 'assets/images/tutorial_dialogue_box.png',
                                sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                                scaleX: rW(1),
                                scaleY: rH(1),
                              ),
                            ),
                            Image.asset(
                              'assets/images/onion_bread.png',
                              width: rW(300),
                              height: rH(300),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-7-1층: 챕터5 회상씬 - bear_bg + 팔(bear_hand.png) 미리보기. _showChapter5Playground
            // 시점(=암전이 완전히 까매진 onFullyBlack 순간)부터 이미 마운트해둬서(안 보이게
            // 9-7-2/9-8-1층 밑에 깔림) Image 위젯이 미리 프레임을 그려둔 상태로 대기하게 함.
            // 챕터3 일기장 인트로(9-9층 주석 참고)랑 동일한 이유·동일한 패턴: 그렇게 안 하면
            // 자기 차례가 됐을 때(playground_bg가 꺼질 때) 막 마운트되면서 첫 프레임을 그리기까지
            // 한 프레임 정도 아무것도 안 그려서, 그 사이 밑에 깔린 주방(kitchen_main)이 잠깐
            // 비쳐 보임. playground_bg(9-7-2층)보다 먼저 그려야(더 아래) playground_bg가
            // 떠있는 동안은 이 레이어가 가려져 있다가, playground_bg가 꺼지는 순간 이미
            // 다 그려진 상태로 바로 드러남.
            // 주의: _showMemoryBlackout을 조건에 넣으면 안 됨 - 이 플래그는 암전이 페이드인
            // 시작하는(아직 안 까매진, opacity=0인) 순간부터 true라서, 그걸로 미리 그려버리면
            // 아직 투명한 암전 너머로 이 레이어가 그대로 비쳐 보이는 버그가 남(실제로 났던 버그)
            if (widget.mode == KitchenScreenMode.chapter5Start &&
                (_showChapter5Playground || _showChapter5BearIntro))
              Positioned.fill(
                key: const ValueKey('chapter5_bear_intro'),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: chapter5BearAnchorY,
                      width: w,
                      height: chapter5BearWSize(kBearArmCanvasHeight),
                      child: Image.asset(
                        'assets/images/bear_bg.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // 안내창. _chapter5BearIntroGuideDelay만큼 있다가 뜨고, 탭하면 닫히고
                    // BearArmPuzzleScene으로 넘어감. 다른 튜토리얼/안내창(memory_flashback_scene.dart,
                    // bread_making_scene.dart)이랑 동일하게 검은 반투명 딤 배경을 안내창 밑에 깔아줌
                    //
                    // 딤 레이어를 bear_hand보다 먼저(아래에) 그림. bear_hand는 딤 레이어 다음에
                    // 그려야 어두워지지 않고 원래 색 그대로 보임 - memory_flashback_scene.dart
                    // 구름 게임에서 인터랙티브한 마지막 구름을 딤 위에 그리는 거랑 같은 패턴
                    if (_showChapter5BearIntroGuide)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _showChapter5BearIntro = false;
                              _showChapter5BearIntroGuide = false;
                              _showChapter5BearArmPuzzle = true;
                            });
                          },
                          child: Container(color: Colors.black.withOpacity(0.5)),
                        ),
                      ),
                    Positioned(
                      left: chapter5BearWX(kBearArmStartX),
                      top: chapter5BearWY(kBearArmStartY),
                      width: chapter5BearWSize(kBearArmSize),
                      height: chapter5BearWSize(kBearArmSize),
                      child: Image.asset(
                        'assets/images/bear_hand.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    // 안내 문구는 화면 가로 중앙 정렬(CenteredDialogueBox) - clock_minigame_scene.dart
                    // 튜토리얼이랑 같은 패턴. bear_hand보다도 위에 그려서 항상 다 보이게 함.
                    // IgnorePointer로 감싸서 탭이 그대로 밑 딤 레이어(GestureDetector)로 전달되게 함
                    if (_showChapter5BearIntroGuide)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CenteredDialogueBox(
                            textWidget: Text(
                              '곰인형의 팔이 떨어졌어요.\n드래그해서 팔을 붙여주세요',
                              textAlign: TextAlign.center,
                              style: dialogueTextStyle(rW),
                            ),
                            rW: rW,
                            rH: rH,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 9-7-2층: 챕터5 회상씬 - playground_bg. _showChapter5Playground가 켜지는 시점(위
            // 9-7-1층 주석 참고 - 암전이 완전히 까매진 onFullyBlack 순간)부터 마운트해둠.
            // bear_bg+팔(9-7-1층)보다 나중에(더 위에) 그려서, 이 레이어가 떠있는 동안은 그
            // 밑에 미리 그려둔 bear_bg+팔을 가려줌
            if (widget.mode == KitchenScreenMode.chapter5Start &&
                _showChapter5Playground)
              Positioned.fill(
                key: const ValueKey('chapter5_playground'),
                child: Image.asset(
                  'assets/images/playground_bg.png',
                  fit: BoxFit.fitWidth,
                ),
              ),

            // 9-8-1층: 빵만들기 미니게임 성공 화면 -> 완성된 빵(salt_bread/onion_bread) 팝업
            // 사이에 잠깐 띄우는 암전. 9-3/9-7층(빵만들기 미니게임)보다 위에 그려야 성공
            // 화면 위로 바로 암전이 덮이고, 화면이 주방으로 바뀐 뒤에야 어두워지는 것처럼
            // 보이지 않음. game_play_screen.dart의 memory_fade_overlay(20층)와 동일한
            // AnimatedOpacity 페이드인/아웃 패턴
            if (_showMemoryBlackout)
              Positioned.fill(
                key: const ValueKey('memory_blackout'),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _memoryBlackoutOpacity,
                    duration: _memoryBlackoutOpacity == 1.0
                        ? _memoryBlackoutFadeInDuration
                        : _memoryBlackoutFadeOutDuration,
                    child: Container(color: Colors.black),
                  ),
                ),
              ),

            // 9-9층: 일기장 인트로 이미지. 암전 단계(9-9-1)에서부터 이미 마운트해둬서(안 보이게
            // 암전 밑에 깔림) Image 위젯이 미리 프레임을 그려둔 상태로 대기하게 함. 그렇게
            // 안 하면 암전이 꺼지는 순간 이 이미지가 막 마운트되면서 첫 프레임을 그리기까지
            // 한 프레임 정도 아무것도 안 그려서, 그 사이 밑에 깔린 주방이 잠깐 비쳐 보였음
            if (_showChapter3DiaryBlackout || _showChapter3DiaryIntro)
              Positioned.fill(
                key: const ValueKey('chapter3_diary_intro'),
                child: Image.asset(
                  'assets/images/chapter3_diary_intro.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

            // 9-9-1층: chapter3_after_first_game.json 끝나고 일기장 퍼즐 시퀀스 시작할 때 뜨는
            // 첫 암전. 9-6층 memory_blackout이랑 동일한 검은 Container 패턴, 대기 시간만 다름.
            // 위 인트로 이미지보다 나중에(위에) 그려야 암전 중엔 인트로가 안 보이고 가려짐
            if (_showChapter3DiaryBlackout)
              Positioned.fill(
                key: const ValueKey('chapter3_diary_blackout'),
                child: Container(color: Colors.black),
              ),

            // 9-11층: 퍼즐 완성 결과 이미지. 퍼즐 단계(9-11-1)에서부터 이미 마운트해둬서(안
            // 보이게 퍼즐 화면 밑에 깔림) 위 인트로 이미지와 동일한 이유로 미리 프레임을
            // 그려둔 상태로 대기하게 함
            if (_showChapter3DiaryPuzzle || _showChapter3DiarySuccessAfter)
              Positioned.fill(
                key: const ValueKey('chapter3_diary_success_after'),
                child: Image.asset(
                  'assets/images/chapter3_diary_success_after.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

            // 9-11-1층: 챕터3 두 번째 미니게임(일기장 사진 조각 맞추기). 인트로 끝나면 뜨고,
            // 최상단에서 화면을 전부 덮음. 완성되면(onComplete) 결과 이미지 -> 암전 ->
            // chapter3_after_eat.json 순으로 이어짐(_onChapter3DiaryPuzzleComplete에서 처리).
            // 위 결과 이미지보다 나중에(위에) 그려야 퍼즐 중엔 결과 이미지가 안 보이고 가려짐
            if (_showChapter3DiaryPuzzle)
              Positioned.fill(
                key: const ValueKey('chapter3_diary_puzzle'),
                child: DiaryPuzzleScene(
                  onComplete: _onChapter3DiaryPuzzleComplete,
                ),
              ),

            // 9-13층: 결과 이미지 끝나고 chapter3_after_eat.json 로드하기 전 뜨는 두 번째 암전
            if (_showChapter3DiaryEndBlackout)
              Positioned.fill(
                key: const ValueKey('chapter3_diary_end_blackout'),
                child: Container(color: Colors.black),
              ),

            // 9-14층: 챕터4 오프닝 컷씬(과거 회상). chapter4_before_cutscene.json 끝나면 뜨고,
            // 최상단에서 화면을 전부 덮음. 프롤로그(GamePlayScreen)에서 쓰던 DialogueOverlay를
            // game 없이 순수 Flutter 위젯으로만 띄우고, data/onComplete만 챕터4용으로 넘김.
            // 끝나면(onComplete) chapter4_after_past.json으로 이어붙임(onDialogueEnd에서 이어받음)
            if (_showChapter4Cutscene)
              Positioned.fill(
                key: const ValueKey('chapter4_cutscene'),
                child: DialogueOverlay(
                  data: chapter4CutsceneData,
                  onComplete: () {
                    setState(() => _showChapter4Cutscene = false);
                    _hasLoadedChapter4AfterPast = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter4/chapter4_after_past.json',
                    );
                  },
                ),
              ),

            // 9-15층: 챕터4 배드엔딩 컷씬. chapter4_after_past.json의 choice_001에서
            // "아뇨... 싫어요."를 골라 line_015b1로 대화가 끝난 경우에만 뜨고, 최상단에서
            // 화면을 전부 덮음. 오프닝 컷씬(9-14층)이랑 동일하게 DialogueOverlay 재사용.
            // 끝나면(onComplete) 챕터 종료 임시 화면을 "배드엔딩" 문구로 표시함
            if (_showChapter4BadEndingCutscene)
              Positioned.fill(
                key: const ValueKey('chapter4_bad_ending_cutscene'),
                child: DialogueOverlay(
                  data: chapter4BadEndingData,
                  onComplete: () {
                    setState(() {
                      _showChapter4BadEndingCutscene = false;
                      _isChapter4BadEnding = true;
                      _showChapterEndPlaceholder = true;
                    });
                  },
                ),
              ),

            // 9-16층: 챕터4 편지 컷씬. chapter4_making_bread.json이 끝나면(line_014) 뜨고,
            // 최상단에서 화면을 전부 덮음. 끝나면(onComplete) chapter4_after_letter.json으로 이어붙임
            if (_showChapter4Letter)
              Positioned.fill(
                key: const ValueKey('chapter4_letter'),
                child: LetterScene(
                  onComplete: () {
                    setState(() => _showChapter4Letter = false);
                    _hasLoadedChapter4AfterLetter = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter4/chapter4_after_letter.json',
                    );
                  },
                ),
              ),

            // 9-17층: 챕터4 빵만들기 컷씬. chapter4_after_letter.json이 끝나면(line_003) 뜨고,
            // 최상단에서 화면을 전부 덮음. 오프닝 컷씬(9-14층)이랑 동일하게 DialogueOverlay 재사용.
            // 끝나면(onComplete) 완성된 빵(croissant) 팝업 표시
            if (_showChapter4MakingBreadCutscene)
              Positioned.fill(
                key: const ValueKey('chapter4_making_bread_cutscene'),
                child: DialogueOverlay(
                  data: chapter4MakingBreadCutsceneData,
                  onComplete: () {
                    setState(() {
                      _showChapter4MakingBreadCutscene = false;
                      _showChapter4BreadPopup = true;
                    });
                  },
                ),
              ),

            // 9-17-1층: 완성된 빵(croissant) 팝업. 챕터2 9-4층(bread_popup_layer)/챕터3
            // 9-8층이랑 동일한 연출(검은 50% 배경 + tutorial_dialogue_box 570x300 + 이미지
            // 300x300). 탭하면 닫히고 chapter4_after_making.json으로 이어짐
            if (_showChapter4BreadPopup)
              Positioned.fill(
                key: const ValueKey('chapter4_bread_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showChapter4BreadPopup = false);
                    _hasLoadedChapter4AfterMaking = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter4/chapter4_after_making.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: rW(570),
                              height: rH(300),
                              child: ScaledNineSliceImage(
                                imagePath: 'assets/images/tutorial_dialogue_box.png',
                                sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                                scaleX: rW(1),
                                scaleY: rH(1),
                              ),
                            ),
                            Image.asset(
                              'assets/images/croissant.png',
                              width: rW(300),
                              height: rH(300),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-19층: 챕터5 빵만들기 미니게임. chapter5_bear.json이 끝나면(line_019) 뜨고,
            // 최상단에서 화면을 전부 덮음. 챕터3(9-7층)이랑 동일하게 forcedCompletedDoughAsset
            // 없이 그대로 재사용해서, 미니게임 안 SUCCESS 반죽 이미지는 재료 조합에 따라
            // StoryState.resolveCompletedDoughImage()로 결정됨. pie.png 고정은 미니게임
            // 자체가 아니라 미니게임 끝나고 뜨는 9-19-1층 팝업에서만 함. 끝나면(onComplete)
            // 완성 빵 팝업 표시
            if (_showChapter5BreadMakingGame)
              Positioned.fill(
                key: const ValueKey('chapter5_bread_making_game'),
                child: BreadMakingScene(
                  onComplete: () {
                    // 챕터3(9-7층)이랑 동일한 암전 패턴 - 성공 화면 위로 바로 암전이 덮이도록,
                    // 미니게임은 화면이 완전히 까매진 뒤(onFullyBlack)에야 끔. 그래야 미니게임
                    // -> 주방 화면 전환이 암전에 가려져서 안 보임(예전엔 이 암전이 빠져있어서
                    // 미니게임 성공 화면에서 주방으로 바로 컷 전환되던 버그가 있었음)
                    _startMemoryBlackout(
                      onFullyBlack: () =>
                          setState(() => _showChapter5BreadMakingGame = false),
                      onComplete: () =>
                          setState(() => _showChapter5BreadPopup = true),
                    );
                  },
                ),
              ),

            // 9-19-1층: 완성된 빵(pie) 팝업. 챕터2/3/4 팝업이랑 동일한 연출(검은 50% 배경 +
            // tutorial_dialogue_box 570x300 + 이미지 300x300). 탭하면 닫히고 chapter5_eat.json으로 이어짐
            if (_showChapter5BreadPopup)
              Positioned.fill(
                key: const ValueKey('chapter5_bread_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showChapter5BreadPopup = false);
                    _hasLoadedChapter5Eat = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter5/chapter5_eat.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: rW(570),
                              height: rH(300),
                              child: ScaledNineSliceImage(
                                imagePath: 'assets/images/tutorial_dialogue_box.png',
                                sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                                scaleX: rW(1),
                                scaleY: rH(1),
                              ),
                            ),
                            Image.asset(
                              'assets/images/pie.png',
                              width: rW(300),
                              height: rH(300),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-22층: 챕터5 회상씬 - 곰인형 팔 붙이기 미니게임(+바느질 미니게임, SUCCESS
            // 연출까지 전부 bear_arm_puzzle_scene.dart/bear_stitch_guide_scene.dart 안에서
            // 끝남). 안내창 탭하면 뜸. 끝나면(onComplete) chapter5_after_eat.json으로 이어짐 -
            // 그 대화가 끝나면 onDialogueEnd의 chapter5Start 분기(_hasLoadedChapter5AfterEat)로
            // 다시 옴
            if (_showChapter5BearArmPuzzle)
              Positioned.fill(
                key: const ValueKey('chapter5_bear_arm_puzzle'),
                child: BearArmPuzzleScene(
                  onComplete: () {
                    setState(() => _showChapter5BearArmPuzzle = false);
                    _hasLoadedChapter5AfterEat = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter5/chapter5_after_eat.json',
                    );
                  },
                ),
              ),

            // 9-23층: 챕터5 해피엔딩 컷씬. chapter5_after_eat.json이 끝나고
            // StoryState.resolveChapter5EndingType()이 happy일 때만 뜸. 챕터4 노말엔딩
            // (chaeon_room_screen.dart)이랑 동일하게 DialogueOverlay 재사용. 끝나면(onComplete)
            // 임시 종료 화면 표시(탭하면 챕터 선택창으로) - 아직 챕터5 다음 챕터가 없어서
            // 챕터4 back_to_bakery처럼 다음 챕터 잠금 해제하는 로직은 없음
            if (_showChapter5EndingHappyCutscene)
              Positioned.fill(
                key: const ValueKey('chapter5_ending_happy_cutscene'),
                child: DialogueOverlay(
                  data: chapter5EndingHappyData,
                  onComplete: () {
                    // 해피엔딩 도달 - 재플레이로 온도/선택 변수 조작 못 하게 전역 플래그 켬
                    ChapterProgress.hasSeenEnding = true;
                    setState(() {
                      _showChapter5EndingHappyCutscene = false;
                      _showChapterEndPlaceholder = true;
                    });
                  },
                ),
              ),

            // 9-24층: 챕터5 히든엔딩 컷씬. chapter5_hidden.json이 끝나고 암전(_startMemoryBlackout)
            // 이 걷힌 뒤 뜸. 해피엔딩이랑 동일하게 DialogueOverlay 재사용, 끝나면(onComplete)도
            // 해피엔딩이랑 동일하게 임시 종료 화면으로 넘어감(탭하면 챕터 선택창으로)
            if (_showChapter5EndingHiddenCutscene)
              Positioned.fill(
                key: const ValueKey('chapter5_ending_hidden_cutscene'),
                child: DialogueOverlay(
                  data: chapter5EndingHiddenData,
                  onComplete: () {
                    // 히든엔딩 도달 - 재플레이로 온도/선택 변수 조작 못 하게 전역 플래그 켬
                    ChapterProgress.hasSeenEnding = true;
                    setState(() {
                      _showChapter5EndingHiddenCutscene = false;
                      _showChapterEndPlaceholder = true;
                    });
                  },
                ),
              ),

            // 10층: 챕터 종료/진행 임시 화면. 나중에 진짜 종료 연출/다음 챕터 연결로 교체할 예정이라
            // 지금은 암전 + 중앙 안내 문구만 있는 자리표시자로 둠. 탭하면 챕터 선택창으로 이동.
            // 챕터1 모드면 "챕터 1 종료", 챕터2 모드면 "챕터 2 종료" 문구로 나뉨
            if (_showChapterEndPlaceholder)
              Positioned.fill(
                key: const ValueKey('chapter_end_placeholder'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleChapterEndTap,
                  child: Container(
                    color: Colors.black.withOpacity(0.85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isChapter4BadEnding
                                ? '배드엔딩'
                                : widget.mode == KitchenScreenMode.chapter1End
                                ? '챕터 1 종료'
                                : widget.mode == KitchenScreenMode.chapter2Start
                                ? '챕터 2 종료'
                                : widget.mode == KitchenScreenMode.chapter3Start
                                ? '챕터3 미니게임 준비 중'
                                : widget.mode == KitchenScreenMode.chapter5Start
                                ? '챕터5 계속 준비 중'
                                // 컷씬(DialogueOverlay)은 이제 떴다 갔으니, 그 다음 이야기가
                                // 아직 준비 안 됐다는 문구로 바꿈
                                : '챕터4 계속 준비 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: rW(28),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SCDream',
                            ),
                          ),
                          SizedBox(height: rH(16)),
                          // 임시 화면이라 안내도 짧게: 탭하면 챕터 선택창으로 넘어감
                          Text(
                            '화면을 탭하면 챕터 선택창으로 이동합니다',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: rW(14),
                              fontFamily: 'SCDream',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
