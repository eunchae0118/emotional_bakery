// lib/features/chapter3/chaeon_room_screen.dart
//
// 챕터3 시작 지점. 채온이 방에서 혼잣말 대사 하나 보여주고, 끝나면 dpad로
// 문까지 걸어가서 나갈 수 있게 함. kitchen_screen.dart 구조(레터박스 스케일,
// SceneDialogueController + buildSceneBubble 재사용) 그대로 따라감

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
import 'package:emotional_bakery/features/chapter1/bakery_game.dart'
    show ReentryChapter;
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/chapter4/chapter4_back_to_bakery_data.dart';
import 'package:emotional_bakery/features/chapter4/chapter4_bad_ending_data.dart';
import 'package:emotional_bakery/features/chapter4/chapter4_eat_sad_bread_cutscene_data.dart';
import 'package:emotional_bakery/features/chapter4/chapter4_ending_normal_data.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';

// 이 화면이 챕터3용인지 챕터4용인지 구분. 배경(room_bg.png)/좌표는 완전히 같은 걸 재사용하고,
// 진입 시 자동 재생되는 대사 json이랑 문 클릭 시 넘어가는 재진입 챕터 값만 다름
enum ChaeonRoomMode { chapter3, chapter4 }

// room_bg.png 실측 좌표 기준 (874x456 캔버스)
// 채온이가 방 안에 서있는 위치
const double kChaeonRoomX = 240;
const double kChaeonRoomTopY = 210;

// 채온이가 좌우로 움직일 수 있는 범위. 정확한 값은 나중에 화면 보면서 조정 필요
const double kChaeonRoomMinX = 60;
const double kChaeonRoomMaxX = 700;
// 채온이 이동 속도(px/초). 다른 화면들이랑 동일하게 맞춤
const double kChaeonRoomSpeed = 225;
const Duration _moveTickInterval = Duration(milliseconds: 40);

// enterFromDoor(kitchen_screen.dart 챕터4 퇴장 연출)일 때 채온이가 걸어 들어오기
// 시작하는 위치. 캔버스(874) 밖이라 화면 오른쪽에서 걸어 들어오는 것처럼 보임
const double kChaeonRoomEnterStartX = 920;
// enterFromDoor일 때 멈추는 위치. 기존 서있는 위치(kChaeonRoomX)보다 오른쪽으로 조정
const double kChaeonRoomEnterStopX = 400;

// 문 클릭 영역. 임시 위치, 실제 화면 보면서 조정 필요
const double kRoomDoorX = 750;
const double kRoomDoorTopY = 60;
const double kRoomDoorWidth = 80;
const double kRoomDoorHeight = 250;

// 문 근접 판정 범위. 채온이가 이 범위 안에 있을 때만 문 탭이 실제로 이동시킴.
// tutorial_screen.dart의 빵집 문 isNearDoor 체크랑 동일한 패턴. 임시 값, 문 위치 확정되면 같이 조정 필요
const double kRoomDoorNearMinX = 620;
const double kRoomDoorNearMaxX = 700;

// "저장되었습니다" 배지가 뜨는 top 위치(874x402 기준, rH로 스케일됨). kitchen_screen.dart랑
// 동일한 값을 씀 - 화면 보면서 조정 예정
const double _saveConfirmationBadgeTopRef = 80;

// 가상 패드(dpad) 버튼 한 변 크기. 원래 DpadButton 기본값(64)이었는데, 모바일에서 누르기
// 너무 작다는 피드백이 있어서 1.5배로 키움 - 화면 보면서 추가 조정 가능
const double _dpadButtonSize = 96;
// dpad 왼쪽 버튼 left 위치. 버튼이 커진 만큼 원래 값(686)대로 두면 오른쪽 버튼(원래 778)이랑
// 겹치게 돼서, 오른쪽 버튼의 원래 오른쪽 끝(778+64=842, 화면 폭 874 기준 여백 32)과 원래
// 버튼 사이 간격(778-750=28)을 그대로 유지한 채 왼쪽으로 다시 계산함(842-96-28-96=622)
const double _dpadLeftButtonLeft = 622;
// dpad 오른쪽 버튼 left 위치. 오른쪽 끝(746+96=842)이 원래 버튼의 오른쪽 끝이랑 같아서
// 화면 오른쪽 여백(874-842=32)도 원래와 동일하게 유지됨
const double _dpadRightButtonLeft = 746;

class ChaeonRoomScreen extends StatefulWidget {
  const ChaeonRoomScreen({
    super.key,
    this.initialTemperature = 3,
    this.mode = ChaeonRoomMode.chapter3,
    this.enterFromDoor = false,
    this.resumeCheckpoint,
  });

  final int initialTemperature;
  final ChaeonRoomMode mode;
  // true면 진입 대사 없이, 채온이가 문 쪽(화면 오른쪽)에서 걸어 들어와 원래 서있는
  // 위치(kChaeonRoomX)에 멈추는 연출부터 시작함(kitchen_screen.dart 챕터4 퇴장 연출용)
  final bool enterFromDoor;
  // 저장된 세이브를 불러와서 들어온 경우에만 넘어옴. kitchen_screen.dart의 resumeCheckpoint랑
  // 동일한 패턴 - mode/enterFromDoor는 이 체크포인트가 속한 조합이랑 맞게 호출부에서 같이
  // 넘겨줘야 함. null이면(기본값) 지금까지와 100% 동일하게 동작함
  final SaveCheckpoint? resumeCheckpoint;

  @override
  State<ChaeonRoomScreen> createState() => _ChaeonRoomScreenState();
}

class _ChaeonRoomScreenState extends State<ChaeonRoomScreen> {
  double _chaeonX = kChaeonRoomX;
  String _chaeonState = 'idle';
  bool _isChaeonFacingLeft = false;

  Timer? _moveTimer;
  // 진입 대사가 끝나기 전까진 dpad랑 문 둘 다 숨김
  bool _dialogueFinished = false;

  // enterFromDoor 흐름 전용 체이닝 플래그: chapter4_room_choice.json / 온도 분기(temp_low,
  // temp_high)를 이미 다 봤는지. kitchen_screen.dart의 _hasLoadedXxx 패턴이랑 동일
  bool _hasLoadedChapter4RoomChoice = false;
  bool _hasLoadedChapter4TempBranch = false;
  // 온도 낮음(1~3) 분기: chapter4_temp_low.json 끝나면 뜨는 배드엔딩 컷씬.
  // kitchen_screen.dart의 챕터4 배드엔딩 컷씬이랑 동일하게 DialogueOverlay + chapter4BadEndingData 재사용
  bool _showChapter4BadEndingCutscene = false;
  bool _isChapter4BadEnding = false;
  // 온도 높음(4~10) 분기: chapter4_temp_high.json 끝나면 뜨는 슬픔의 빵을 먹는 컷씬.
  // 배드엔딩 컷씬이랑 동일하게 DialogueOverlay + chapter4EatSadBreadCutsceneData 재사용
  bool _showChapter4EatSadBreadCutscene = false;
  // 회상씬 이후 온도 4~7(노말엔딩) 분기: 끝나면 임시 종료 화면으로 이어짐(배드엔딩이랑 동일 패턴)
  bool _showChapter4EndingNormalCutscene = false;
  // 회상씬 이후 온도 8~10(챕터5행) 분기: 끝나면 챕터5 잠금 해제하고 바로 챕터 선택창으로 이동
  bool _showChapter4BackToBakeryCutscene = false;
  // 배드엔딩/노말엔딩 컷씬이 끝나면 뜨는 임시 종료 화면.
  // 그 다음 내용이 아직 없어서 kitchen_screen.dart의 "챕터4 계속 준비 중" 자리표시자를 그대로 재사용
  bool _showChapterEndPlaceholder = false;

  bool _isSettingOpen = false;
  // 메뉴 "저장" 버튼 누르면 잠깐 뜨는 확인 문구. null이면 안 보임. kitchen_screen.dart랑 동일한 패턴
  String? _saveConfirmationText;
  Timer? _saveConfirmationTimer;

  // 문 근접 판정 실패 안내 문구, 배경 오브젝트 클릭 정보 둘 다 여기 띄움. 탭하면 닫힘
  String? _interactionText;

  // 배경 오브젝트 클릭 정보 팝업. chapter3_room.json에서 불러온 히트박스 목록이고,
  // kitchen_screen.dart랑 동일하게 이동 가능한 상태(_dialogueFinished)일 때만 클릭 가능
  List<InteractionObject> _interactionObjects = [];

  late final SceneDialogueController _sceneController;

  @override
  void initState() {
    super.initState();
    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        // enterFromDoor 흐름(챕터4 방 복귀)에서만 room_choice -> 온도 분기 체이닝을 타고,
        // 그 외(챕터3, 챕터4 오프닝 독백)는 기존처럼 그냥 dpad/문만 열어줌
        if (widget.enterFromDoor && !_hasLoadedChapter4RoomChoice) {
          // chapter4_room_choice.json이 끝나면 여기로 옴. 감정 온도로 분기
          _hasLoadedChapter4RoomChoice = true;
          _sceneController.loadDialogue(
            _sceneController.temperature <= 3
                ? 'assets/lines/chapter4/chapter4_temp_low.json'
                : 'assets/lines/chapter4/chapter4_temp_high.json',
          );
          return;
        }
        if (widget.enterFromDoor && !_hasLoadedChapter4TempBranch) {
          // chapter4_temp_low.json(line_001) 또는 chapter4_temp_high.json(line_002)이
          // 끝나면 여기로 옴. 온도 분기 사이에 온도가 바뀔 일은 없어서 위와 동일 조건 재사용
          _hasLoadedChapter4TempBranch = true;
          if (_sceneController.temperature <= 3) {
            setState(() => _showChapter4BadEndingCutscene = true);
          } else {
            // 온도 높음(4~10) 분기: 슬픔의 빵을 먹는 컷씬 표시
            setState(() => _showChapter4EatSadBreadCutscene = true);
          }
          return;
        }
        setState(() => _dialogueFinished = true);
      },
      // 이 방엔 릴리안이 없어서 둘 다 안 씀
      onLillianHop: () {},
      onChaeonHop: () {},
      // widget.initialTemperature 대신 전역값을 읽음 - 챕터 경계(ChapterSelectScreen 경유)를
      // 넘어갈 때도 온도가 안 끊기게 하려면 여기서 위젯 파라미터를 안 쓰고 StoryState를 직접
      // 봐야 함. widget.initialTemperature는 이제 여기서 안 쓰이지만, 같은 챕터 안에서 화면끼리
      // 명시적으로 넘겨주던 기존 호출부들이 있어서 파라미터 자체는 그대로 둠(각 호출부 주석 참고)
      initialTemperature: StoryState.currentTemperature,
    );
    _sceneController.addListener(_onSceneControllerChanged);
    // 세이브 불러와서 들어온 경우, 정상 진입 흐름(아래) 대신 체크포인트가 가리키는 지점부터
    // 바로 시작함. resumeCheckpoint가 null이면 이 분기 자체를 안 타서 기존 동작 그대로임
    if (widget.resumeCheckpoint != null) {
      _resumeFromCheckpoint(widget.resumeCheckpoint!);
    } else if (widget.enterFromDoor) {
      // 문에서 걸어 들어오는 연출: 진입 대사 없이 바로 걸어 들어오는 애니메이션부터 시작하고,
      // 다 걸어 들어오면 그때 dpad/문이 뜨게 함(_dialogueFinished를 그대로 재사용)
      _chaeonX = kChaeonRoomEnterStartX;
      _startEnterWalk();
    } else {
      // 챕터4 모드면 chapter4_start_room.json, 아니면 기존 챕터3 대사를 그대로 로드
      _sceneController.loadDialogue(
        widget.mode == ChaeonRoomMode.chapter4
            ? 'assets/lines/chapter4/chapter4_start_room.json'
            : 'assets/lines/chapter3/chapter3_chaeon_room.json',
      );
    }
    // 배경 오브젝트 클릭 정보(chapter3_room.json) 로드
    InteractionLoader.loadStageObjects('room_bg.png').then((objects) {
      if (mounted) setState(() => _interactionObjects = objects);
    });
  }

  // resumeCheckpoint로 들어온 경우 initState에서 호출됨. kitchen_screen.dart의
  // _resumeFromCheckpoint랑 동일한 패턴 - 체크포인트 이전에 있었어야 할 플래그들을 미리
  // 켜주고 해당 파일을 바로 로드함. StoryState/ChapterProgress는 이 화면 진입 전에
  // 이미 복원되어 있는 걸 전제로 함
  void _resumeFromCheckpoint(SaveCheckpoint checkpoint) {
    switch (checkpoint) {
      case SaveCheckpoint.chapter3ChaeonRoom:
        _sceneController.loadDialogue(
          'assets/lines/chapter3/chapter3_chaeon_room.json',
        );
        break;
      case SaveCheckpoint.chapter4StartRoom:
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_start_room.json',
        );
        break;
      case SaveCheckpoint.chapter4RoomChoice:
        // enterFromDoor 걷기 연출을 건너뛰고 도착 위치에 바로 세워둠(_startEnterWalk 끝 상태랑 동일)
        _chaeonX = kChaeonRoomEnterStopX;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_room_choice.json',
        );
        break;
      case SaveCheckpoint.chapter4TempLow:
        _chaeonX = kChaeonRoomEnterStopX;
        _hasLoadedChapter4RoomChoice = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_temp_low.json',
        );
        break;
      case SaveCheckpoint.chapter4TempHigh:
        _chaeonX = kChaeonRoomEnterStopX;
        _hasLoadedChapter4RoomChoice = true;
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_temp_high.json',
        );
        break;
      default:
        // 이 화면(chaeon_room_screen.dart) 소관 아닌 체크포인트가 잘못 넘어온 경우를 대비한
        // 방어적 분기 - 그냥 이 mode/enterFromDoor의 정상 진입 흐름으로 흘려보냄
        if (widget.enterFromDoor) {
          _chaeonX = kChaeonRoomEnterStartX;
          _startEnterWalk();
        } else {
          _sceneController.loadDialogue(
            widget.mode == ChaeonRoomMode.chapter4
                ? 'assets/lines/chapter4/chapter4_start_room.json'
                : 'assets/lines/chapter3/chapter3_chaeon_room.json',
          );
        }
    }
  }

  // 지금 mode/enterFromDoor/플래그 조합 기준으로 "가장 최근에 통과한 체크포인트"를 찾음.
  // kitchen_screen.dart의 _detectCurrentCheckpoint랑 동일한 이유로, 저장 버튼이 떠 있다는
  // 것 자체가 컷씬/미니게임 같은 중간 연출이 아니라 안정된 상태라는 뜻이라 이 시점 플래그
  // 조합만으로 체크포인트를 확정할 수 있음
  SaveCheckpoint _detectCurrentCheckpoint() {
    if (widget.mode == ChaeonRoomMode.chapter4 && !widget.enterFromDoor) {
      return SaveCheckpoint.chapter4StartRoom;
    }
    if (!widget.enterFromDoor) {
      return SaveCheckpoint.chapter3ChaeonRoom;
    }
    // enterFromDoor(챕터4 방 복귀) 흐름. temp_low/temp_high 중 어느 쪽이 로드됐었는지는 온도로
    // 다시 판단함 - 두 분기 사이엔 온도가 안 바뀌어서 지금 온도로 재확인해도 항상 같은 결과가 나옴
    if (_hasLoadedChapter4RoomChoice) {
      return _sceneController.temperature <= 3
          ? SaveCheckpoint.chapter4TempLow
          : SaveCheckpoint.chapter4TempHigh;
    }
    return SaveCheckpoint.chapter4RoomChoice;
  }

  // 메뉴 "저장" 버튼(MenuOverlay.onSave)이 부름. kitchen_screen.dart의 _handleSave랑 동일한 패턴
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

  // enterFromDoor일 때 kChaeonRoomEnterStartX(화면 오른쪽 밖)에서 kChaeonRoomEnterStopX까지
  // 왼쪽으로 자동으로 걸어오는 애니메이션. kitchen_screen.dart의 _startChapter4ExitWalk이랑
  // 동일한 패턴(플레이어 입력 없이 Timer로 좌표만 직접 움직임). 멈추자마자 탭 없이 바로
  // chapter4_room_choice.json 첫 줄이 뜨고, 끝나면 기존 onDialogueEnd에서
  // _dialogueFinished = true로 넘겨받아 dpad/문이 뜸
  void _startEnterWalk() {
    _moveTimer?.cancel();
    setState(() {
      _chaeonState = 'walk';
      _isChaeonFacingLeft = true;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      setState(() => _chaeonX -= 9.0);
      if (_chaeonX <= kChaeonRoomEnterStopX) {
        timer.cancel();
        setState(() {
          _chaeonX = kChaeonRoomEnterStopX;
          _chaeonState = 'idle';
        });
        _sceneController.loadDialogue(
          'assets/lines/chapter4/chapter4_room_choice.json',
        );
      }
    });
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _saveConfirmationTimer?.cancel();
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    super.dispose();
  }

  void _moveChaeonBy(double delta) {
    setState(() {
      _chaeonX = (_chaeonX + delta).clamp(kChaeonRoomMinX, kChaeonRoomMaxX);
    });
  }

  void _startMoving(int direction) {
    if (!_dialogueFinished) return;
    _moveTimer?.cancel();
    setState(() {
      _chaeonState = 'walk';
      _isChaeonFacingLeft = direction < 0;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      // 225px/초 * 40ms = 9px, 다른 화면들이랑 동일한 틱당 이동량
      _moveChaeonBy(direction * 9.0);
    });
  }

  void _stopMoving() {
    _moveTimer?.cancel();
    setState(() => _chaeonState = 'idle');
  }

  // 골목길(TutorialScreen)로 이동. 문 근처(kRoomDoorNearMinX~MaxX)에 있을 때만 실제로 이동시키고,
  // 아니면 안내 문구만 잠깐 띄움 (tutorial_screen.dart 빵집 문 isNearDoor 체크랑 동일한 패턴)
  void _handleDoorTap() {
    final bool isNearDoor =
        _chaeonX >= kRoomDoorNearMinX && _chaeonX <= kRoomDoorNearMaxX;
    if (!isNearDoor) {
      setState(() => _interactionText = "아직 문까지는 좀 먼 것 같다.");
      return;
    }
    // TutorialScreen 기본값(골목길 맨 왼쪽에서 시작)을 그대로 써서 진입.
    // reentryChapter 켜서 빵집 문 클릭 시 skipChapter1Events 모드로 이어지게 함.
    // initialStep만 2로 넘겨서 조작법 안내 문구(0/1단계)는 건너뜀 (재진입이라 이미 다 아는 내용)
    // 방 모드(mode)에 맞는 챕터로 넘겨줘야 골목길->빵집에서 챕터3 문 대사가 챕터4에 안 새어나감
    Navigator.push(
      context,
      fadeThroughBlackRoute(
        TutorialScreen(
          initialStep: 2,
          reentryChapter: widget.mode == ChaeonRoomMode.chapter4
              ? ReentryChapter.chapter4
              : ReentryChapter.chapter3,
          initialTemperature: _sceneController.temperature,
        ),
      ),
    );
  }

  void _handleBackButtonTap() {
    _sceneController.goBackScene();
  }

  // 챕터4 임시 종료 화면 탭하면 챕터 선택창으로 이동. kitchen_screen.dart의
  // _handleChapterEndTap이랑 동일한 패턴(pushReplacement로 스택 정리)
  void _handleChapterEndTap() {
    Navigator.pushReplacement(
      context,
      fadeThroughBlackRoute(const ChapterSelectScreen()),
    );
  }

  // 현재 노드가 채온이 대사고 expression이 있으면 그 이미지를 우선 보여줌
  // (kitchen_screen.dart의 _resolveChaeonExpressionSprite와 동일한 패턴)
  String? _resolveChaeonExpressionSprite(String? sceneNodeId) {
    final DialogueNode? node =
        _sceneController.sceneDialogue?.nodes[sceneNodeId];
    if (node?.speaker != 'chaeon') return null;
    return node?.expression?.asset;
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;
    // UI 크롬(온도계, 버튼, dpad)은 다른 화면들과 동일 기준(874x402)으로 스케일
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // room_bg.png(874x456)가 화면을 빈틈없이 꽉 채우도록 레터박스 스케일 (kitchen_screen.dart와 동일 공식,
    // 캔버스 세로 크기만 464 대신 456으로 바꿈)
    final double worldScale = (w / 874) > (h / 456) ? (w / 874) : (h / 456);
    final double worldOffsetX = (w - 874 * worldScale) / 2;
    final double worldOffsetY = (h - 456 * worldScale) / 2;
    double wX(double px) => worldOffsetX + px * worldScale;
    double wY(double px) => worldOffsetY + px * worldScale;
    double wSize(double px) => px * worldScale;
    // 챕터3 재진입 상태면 kitchen_screen.dart에서 계단 트리거 체크를 켜서
    final double characterSize = rH(172);
    final double characterTopShift = characterSize - wSize(172);

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;

    final double chaeonCenterX = wX(_chaeonX) + characterSize / 2;
    final double chaeonSpriteTopY = wY(kChaeonRoomTopY) - characterTopShift;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 배경
            Positioned(
              left: worldOffsetX,
              top: worldOffsetY,
              width: wSize(874),
              height: wSize(456),
              child: Image.asset('assets/images/room_bg.png', fit: BoxFit.fill),
            ),

            // 2층: 채온이. 챕터3 기본 상태는 chaeon_20_normal(_walk).gif(20% 상태 에셋), 챕터4는
            // chaeon_50_normal(_walk).gif(50% 상태 에셋)를 쓰고, 현재 대사 노드에 expression이
            // 있으면(채온이 대사일 때만) 그 이미지를 우선 보여줌
            Positioned(
              key: const ValueKey('chaeon_room_chaeon'),
              left: wX(_chaeonX),
              top: wY(kChaeonRoomTopY) - characterTopShift,
              child: Transform.flip(
                flipX: _isChaeonFacingLeft,
                child: Builder(
                  builder: (context) {
                    final String? expressionSprite =
                        _resolveChaeonExpressionSprite(sceneNodeId);
                    // 챕터4는 감정 온도가 더 오른 상태라 기본 스프라이트를 50% 버전으로 씀
                    final String defaultSprite = widget.mode == ChaeonRoomMode.chapter4
                        ? (_chaeonState == 'walk'
                              ? 'assets/images/chaeon_50_normal_walk.gif'
                              : 'assets/images/chaeon_50_normal.gif')
                        : (_chaeonState == 'walk'
                              ? 'assets/images/chaeon_20_normal_walk.gif'
                              : 'assets/images/chaeon_20_normal.gif');
                    // expression이 있을 때만 부드럽게 전환하고, 걷기/정지 전환은 dpad에
                    // 바로 반응해야 자연스러워서 즉시 바뀌는 Image.asset을 씀
                    if (expressionSprite != null) {
                      return PopInImage(
                        imagePath: expressionSprite,
                        width: characterSize,
                        height: characterSize,
                        fit: BoxFit.contain,
                      );
                    }
                    return Image.asset(
                      defaultSprite,
                      width: characterSize,
                      height: characterSize,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),

            // 3층: 문 클릭 영역. 대사 끝나야 나타남. 임시 위치라 실제 화면 보면서 조정 필요
            if (_dialogueFinished)
              Positioned(
                key: const ValueKey('chaeon_room_door'),
                left: wX(kRoomDoorX),
                top: wY(kRoomDoorTopY),
                width: wSize(kRoomDoorWidth),
                height: wSize(kRoomDoorHeight),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleDoorTap,
                ),
              ),

            // 3-2층: 배경 오브젝트 클릭 히트박스. kitchen_screen.dart랑 동일하게 이동 가능한 상태
            // (_dialogueFinished)일 때만 활성화하고, 버튼 레이어(5~7층)보다 아래에 둬서
            // 히트박스가 버튼 탭을 가로채지 않게 함
            if (_dialogueFinished)
              for (final obj in _interactionObjects)
                Positioned(
                  key: ValueKey('chaeon_room_interaction_${obj.id}'),
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

            // 4층: 진입 대사창
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('chaeon_room_dialogue_layer'),
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
                          // 이 방엔 릴리안이 없어서 안 쓰이지만 required라 채온이랑 동일값으로 채움
                          lillianCenterX: chaeonCenterX,
                          typedCharCount: _sceneController.typedCharCount,
                          chaeonSpriteTopY: chaeonSpriteTopY,
                          // buildSceneBubble이 화자별로 headGap을 다르게 줘서(채온 10, 릴리안 20)
                          // 그대로 chaeonSpriteTopY를 넘기면 speaker:lillian인 줄(예:
                          // chapter4_room_choice.json line_002)만 rH(10)px 더 높이 뜸.
                          // 이 방엔 실제로는 채온이 하나뿐이라 그 차이만큼 미리 보정해서 넘겨줌
                          lillianSpriteTopY: chaeonSpriteTopY + rH(10),
                        ),
                    ],
                  ),
                ),
              ),

            // 5층: 온도계
            widgets.buildThermometer(
              key: 'chaeon_room_thermometer',
              rW: rW,
              rH: rH,
              temperature: _sceneController.temperature,
              temperatureChangeText: _sceneController.temperatureChangeText,
            ),

            // 6층: 뒤로가기 버튼
            widgets.buildBackButton(
              key: 'chaeon_room_back',
              rW: rW,
              rH: rH,
              onTap: _handleBackButtonTap,
            ),

            // 7층: 설정 버튼
            widgets.buildSettingButton(
              key: 'chaeon_room_setting',
              rW: rW,
              rH: rH,
              onTap: () => setState(() => _isSettingOpen = true),
            ),

            // 8층: 가상 패드. 대사 끝나기 전까진 숨김
            if (_dialogueFinished) ...[
              Positioned(
                key: const ValueKey('chaeon_room_dpad_left'),
                left: rW(_dpadLeftButtonLeft),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_left.png',
                  onTapDown: () => _startMoving(-1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                  size: _dpadButtonSize,
                ),
              ),
              Positioned(
                key: const ValueKey('chaeon_room_dpad_right'),
                left: rW(_dpadRightButtonLeft),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_right.png',
                  onTapDown: () => _startMoving(1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                  size: _dpadButtonSize,
                ),
              ),
            ],

            // 8-2층: 문 근접 실패 안내 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('chaeon_room_interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 8-3층: 문 근접 실패 안내 텍스트창
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

            // 9-1층: 저장 완료 안내 배지. kitchen_screen.dart 9-1층이랑 동일한 패턴
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

            // 10층: 챕터4 배드엔딩 컷씬. chapter4_temp_low.json(line_001)까지 끝났을 때만
            // 뜨고, 최상단에서 화면을 전부 덮음. kitchen_screen.dart 9-15층이랑 동일하게
            // DialogueOverlay + chapter4BadEndingData 재사용. 끝나면(onComplete) 임시
            // 종료 화면을 "배드엔딩" 문구로 표시함
            if (_showChapter4BadEndingCutscene)
              Positioned.fill(
                key: const ValueKey('chaeon_room_chapter4_bad_ending_cutscene'),
                child: DialogueOverlay(
                  data: chapter4BadEndingData,
                  onComplete: () {
                    // 배드엔딩 도달 - 재플레이로 온도/선택 변수 조작 못 하게 전역 플래그 켬
                    ChapterProgress.hasSeenEnding = true;
                    setState(() {
                      _showChapter4BadEndingCutscene = false;
                      _isChapter4BadEnding = true;
                      _showChapterEndPlaceholder = true;
                    });
                  },
                ),
              ),

            // 10-2층: 챕터4 슬픔의 빵을 먹는 컷씬. chapter4_temp_high.json(line_002)까지
            // 끝났을 때만 뜨고, 최상단에서 화면을 전부 덮음. 배드엔딩 컷씬(10층)이랑
            // 동일하게 DialogueOverlay 재사용. 끝나면(onComplete) 온도로 한 번 더 분기:
            // 4~7은 노말엔딩, 8~10은 챕터5행. 이 시점 온도는 이미 4 이상 확정이라 겹칠 일 없음
            if (_showChapter4EatSadBreadCutscene)
              Positioned.fill(
                key: const ValueKey('chaeon_room_chapter4_eat_sad_bread_cutscene'),
                child: DialogueOverlay(
                  data: chapter4EatSadBreadCutsceneData,
                  onComplete: () {
                    setState(() => _showChapter4EatSadBreadCutscene = false);
                    if (_sceneController.temperature <= 7) {
                      setState(() => _showChapter4EndingNormalCutscene = true);
                    } else {
                      setState(() => _showChapter4BackToBakeryCutscene = true);
                    }
                  },
                ),
              ),

            // 10-3층: 챕터4 노말엔딩(온도 4~7) 컷씬. 위 회상씬이 끝나고 뜸.
            // 배드엔딩 컷씬이랑 동일한 패턴. 끝나면(onComplete) 임시 종료 화면 표시
            if (_showChapter4EndingNormalCutscene)
              Positioned.fill(
                key: const ValueKey('chaeon_room_chapter4_ending_normal_cutscene'),
                child: DialogueOverlay(
                  data: chapter4EndingNormalData,
                  onComplete: () {
                    // 노말엔딩 도달 - 배드엔딩이랑 동일한 이유로 전역 플래그 켬
                    ChapterProgress.hasSeenEnding = true;
                    setState(() {
                      _showChapter4EndingNormalCutscene = false;
                      _showChapterEndPlaceholder = true;
                    });
                  },
                ),
              ),

            // 10-4층: 챕터4 챕터5행(온도 8~10) 컷씬. 위 회상씬이 끝나고 뜸. 끝나면(onComplete)
            // 임시 종료 화면 없이 바로 챕터5 잠금 해제 + 챕터 선택창 이동까지 처리함
            if (_showChapter4BackToBakeryCutscene)
              Positioned.fill(
                key: const ValueKey('chaeon_room_chapter4_back_to_bakery_cutscene'),
                child: DialogueOverlay(
                  data: chapter4BackToBakeryData,
                  onComplete: () {
                    ChapterProgress.isChapter5Unlocked = true;
                    Navigator.pushReplacement(
                      context,
                      fadeThroughBlackRoute(const ChapterSelectScreen()),
                    );
                  },
                ),
              ),

            // 11층: 챕터4 임시 종료 화면. 위 두 컷씬(배드엔딩/슬픔의 빵) 중 하나가 끝나면 뜸.
            // kitchen_screen.dart의 챕터 종료 자리표시자랑 동일한 구성(암전 + 중앙 안내 문구).
            // 탭하면 챕터 선택창으로 이동
            if (_showChapterEndPlaceholder)
              Positioned.fill(
                key: const ValueKey('chaeon_room_chapter_end_placeholder'),
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
                            _isChapter4BadEnding ? '배드엔딩' : '챕터4 계속 준비 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: rW(28),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SCDream',
                            ),
                          ),
                          SizedBox(height: rH(16)),
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
