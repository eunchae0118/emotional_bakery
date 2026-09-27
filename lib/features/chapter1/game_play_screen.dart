// lib/features/chapter1/game_play_screen.dart

import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart';
import 'package:emotional_bakery/core/widgets/dialogue_overlay.dart';
import 'package:emotional_bakery/core/widgets/menu_overlay.dart';
import 'package:emotional_bakery/core/services/app_exit.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/memory_flashback_scene.dart';
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';

// 챕터1 대사 체이닝 진행 단계: first_meet → table → 회상 컷씬 → first_bread → 앞치마 착용 후 주방행
enum DialoguePhase {
  none,
  firstMeet,
  table,
  memoryFlashback,
  firstBread,
  // 앞치마 착용 후 주방으로 내려가는 연출 단계. 이때부터 계단 트리거가 실제로 소모되게 켜짐
  kitchenApproach,
}

// table.json 종료 후 회상 컷씬으로 넘어갈 때 쓰는 검은 화면 페이드 전환 타이밍
const Duration _memoryFadeInDuration = Duration(milliseconds: 300);
const Duration _memoryFadeHoldDuration = Duration(milliseconds: 1000);
const Duration _memoryFadeOutDuration = Duration(milliseconds: 300);

// 계단 하강 연출용 상수: 계단 꼭대기 지점, 계단 화면 밖 지점, 채온이 계단 내려가는 끝 지점, 하강 애니메이션 지속시간
const Offset _stairsTopPoint = Offset(1680, 172);
// 릴리안이 계단을 올라오기 시작하는(화면 밖) 지점
const Offset _stairsOffscreenPoint = Offset(1800, 180);
// 채온이가 계단을 내려가 화면 밖으로 사라지는 지점. 시작 y를 180으로 바꾸면서 대각선
// 각도가 예전보다 완만해져서, x를 오른쪽으로 더 밀어서 각도를 다시 맞춤(y는 그대로)
const Offset _chaeonStairsDescentEnd = Offset(1960, 232);
const Duration _stairsDescentDuration = Duration(milliseconds: 700);
// 채온이 하강 애니메이션이 시작하는 y좌표. _stairsTopPoint.dy(172)를 그대로 쓰면 평소
// 걷는 위치(bottom: rH(50) 기준, top으로 환산하면 rH(180))보다 rH(8)만큼 위에서 시작해버려서
// 하강 시작 순간 살짝 위로 튀어 보임. 릴리안은 평소에도 top: rH(172) 기준이라 172가 맞지만,
// 채온이는 평소 바닥선 기준이 달라서 따로 값을 둠
const double _chaeonStairsDescentStartY = 180;
const double _chaeonWalkFloorBottomOffset = 50; // "bottom: rH(50)" 채온이 바닥선 기준값

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

// 릴리안 계단 등장(_triggerLillianStairsEntrance)이 끝났을 때 멈추는 지점 - 채온이 위치보다
// 이만큼 오른쪽. resumeChaeonX(1305) + 이 값으로 chapter1Table/chapter1FirstBread 이어하기
// 시 릴리안 도착 좌표를 계산해야 정상 진행 때랑 같은 위치에 서게 됨(_snapLillianArrived 호출부 참고)
const double _lillianStairsArrivalGap = 280;

// chapter1Table/chapter1FirstBread 체크포인트 재개 시 채온이를 세워두는 x좌표. 정상 진행에서
// 릴리안 두 번째 등장 트리거(bakery_game.dart의 onReachPostSceneEnd, x>=1305)가 막 발동한
// 직후 상태를 그대로 재현하는 거라 그 트리거 좌표(1305)를 그대로 씀
const double _chapter1TableResumeChaeonX = 1305;

class GamePlayScreen extends StatefulWidget {
  final bool isPrologue;
  // 챕터3 재진입 모드: true면 가이드 대사/table.json/first_bread.json 단계를 전부 건너뛰고,
  final bool skipChapter1Events;
  // 어느 챕터로 재진입한 건지. skipChapter1Events는 챕터 상관없이 공통으로 켜지지만,
  // chapter3_door.json 트리거처럼 챕터별로 갈라야 하는 로직은 이 값으로 구분함(BakeryGame에 그대로 전달)
  final ReentryChapter reentryChapter;
  // 챕터3 재진입 시 방/골목길에서 이어받아 온도계에 표시할 시작 온도.
  // chaeon_room_screen.dart처럼 이전 화면의 _sceneController.temperature를 그대로 넘겨받음
  final int initialTemperature;
  // 저장된 세이브를 불러와서 들어온 경우에만 넘어옴. kitchen_screen.dart/chaeon_room_screen.dart의
  // resumeCheckpoint랑 동일한 패턴 - skipChapter1Events/reentryChapter는 이 체크포인트가 속한
  // 조합이랑 맞게 호출부에서 같이 넘겨줘야 함. null이면(기본값) 지금까지와 100% 동일하게 동작함
  final SaveCheckpoint? resumeCheckpoint;
  const GamePlayScreen({
    super.key,
    this.isPrologue = false,
    this.skipChapter1Events = false,
    this.reentryChapter = ReentryChapter.none,
    this.initialTemperature = 3,
    this.resumeCheckpoint,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with TickerProviderStateMixin {
  late final BakeryGame _game;

  bool _isDialogueActive = false;
  int _dialogueStep = 0;
  List<String> _dialogueTexts = [];
  String? _interactionText;
  bool _isSettingOpen = false;
  // 메뉴 "저장" 버튼 누르면 잠깐 뜨는 확인 문구. null이면 안 보임. kitchen_screen.dart랑 동일한 패턴
  String? _saveConfirmationText;
  Timer? _saveConfirmationTimer;

  // 채온이 상태 변수
  String _chaeonState = 'idle';
  bool _isChaeonFacingRight = true; // 채온 좌우 반전용 스위치
  // table.json 먹는 클로즈업을 한 번이라도 지나갔는지. true가 되면 회상 컷씬으로 넘어갈 때까지
  // 빵 접시를 다시 그리지 않고, 채온이도 빵 든 정지 이미지로 표시
  bool _hasEatenBread = false;
  // 챕터5 전용: chapter5_start.json이 끝나서 그 자리에서 앞치마로 갈아입었는지.
  // 다른 재진입 챕터(챕터3/4)는 이 화면에서 계속 평상복이라 안 씀
  bool _hasChangedToChapter5Apron = false;

  // 릴리안 상태 및 자동 걷기 애니메이션 변수
  late AnimationController _lillianController;
  double _lillianStartX = 1500.0; // 릴리안 시작 좌표
  double _lillianTargetX = 900.0; // 걸어와서 멈출 좌표
  bool _isLillianWalking = false; // 릴리안이 현재 걷는 중인지 여부
  bool _isLillianVisible = false; // 릴리안이 화면에 등장했는지 여부
  // 릴리안 스프라이트를 좌우 반전할지. lillian_walk.gif 원본은 오른쪽을 보고 있는데,
  // 등장 연출 두 종류(_triggerLillianWalk, _triggerLillianStairsEntrance) 모두 채온이보다
  // 오른쪽에서 시작해 왼쪽(채온이 쪽)으로 걸어오므로 등장 트리거 시점에 true로 바뀜.
  // 예전엔 _isLillianWalking에 그대로 묶어서 걷는 동안만 반전시켰는데, 그러면 도착한 순간
  // 반전이 풀리면서 방향이 홱 바뀌는 것처럼 보여서 지금은 도착 후에도 계속 true로 유지함
  bool _isLillianFacingLeft = false;

  // 릴리안 두 번째 등장(계단을 올라와 채온이 앞까지 걸어옴)
  late AnimationController _lillianStairsController;
  Animation<Offset>? _lillianStairsAnimation;
  bool _isLillianSecondEntranceActive = false;

  // 왼쪽 끝에서 튜토리얼 화면으로 전환 중 중복 네비게이션 방지 플래그
  bool _isNavigatingToTutorial = false;

  // 채온이가 계단 근처에 도달했을 때 재생하는 하강 애니메이션(_stairsTopPoint -> _chaeonStairsDescentEnd)
  late AnimationController _chaeonStairsDescentController;
  Animation<Offset>? _chaeonStairsDescentAnimation;
  bool _isChaeonDescendingStairs = false;
  // 계단 하강 후 주방 화면으로 전환 중 중복 네비게이션 방지 플래그
  bool _isNavigatingToKitchen = false;

  // 릴리안/채온 "깜짝 놀람" 모션(살짝 위로 껑충)용 컨트롤러 및 오프셋 애니메이션
  late AnimationController _lillianHopController;
  late Animation<double> _lillianHopOffset;
  late AnimationController _chaeonHopController;
  late Animation<double> _chaeonHopOffset;

  // 암전 시작시, true 고정. 이때부터 온도계/뒤로가기 노출, 이동 버튼 숨김
  bool _isGuidePhaseStarted = false;
  // 첫 만남 대사 종료 후, 채온이가 1200 지점에 도착하면 true. 이때부터 방향키 숨김, 이동 잠금
  bool _isFreeWalkPhase = false;

  // 현재 어느 대사 단계인지: first_meet → table → 회상 컷씬 → first_bread 순으로 변경
  DialoguePhase _dialoguePhase = DialoguePhase.none;

  // table.json -> 회상 컷씬 전환용 검은 화면 페이드 오버레이
  bool _showMemoryFadeOverlay = false;
  double _memoryFadeOpacity = 0.0;
  Timer? _memoryFadeTimer;

  // 채온-릴리안 첫 만남 대사(line/choice 그래프 순회, 타이핑 효과, 온도 변화) 상태 관리
  late final SceneDialogueController _sceneController;

  bool _thermometerImagesPrecached = false;

  @override
  void initState() {
    super.initState();

    // resumeCheckpoint로 들어온 경우, BakeryGame을 만들 때 재개 위치를 같이 넘겨줘야 함 -
    // _game이 만들어진 다음에 chaeon 위치를 옮기려고 하면 그 시점엔 chaeon이 아직 mount되기
    // 전(Flame onLoad()가 비동기라 나중에 돎)이라 안 먹힘. 체크포인트별 좌표는 실제 정상
    // 진행에서 그 대사가 시작되는 지점(x=650 가이드/첫 만남, x=1305 릴리안 계단 등장 완료)을
    // 그대로 따라감 - kChapter5StartX가 마침 챕터1 첫 만남 지점(650)이랑 같은 값이라 재사용함
    double? resumeChaeonX;
    double? resumeLillianArrivalX;
    bool resumeSkipGuideTrigger = false;
    bool resumeSkipPostSceneEndTrigger = false;
    switch (widget.resumeCheckpoint) {
      case SaveCheckpoint.chapter1FirstMeet:
        resumeChaeonX = kChapter5StartX;
        resumeLillianArrivalX = 900;
        resumeSkipGuideTrigger = true;
        break;
      case SaveCheckpoint.chapter1Table:
      case SaveCheckpoint.chapter1FirstBread:
        resumeChaeonX = _chapter1TableResumeChaeonX;
        // 900은 첫 만남 등장(_triggerLillianWalk) 도착 좌표라 여기(두 번째 등장) 기준으로는
        // 틀린 값이었음 - 릴리안이 채온이보다 왼쪽에 서고 카메라 초점도 잘못 잡히는 원인이었음.
        // 실제로는 채온이 위치 + _lillianStairsArrivalGap(280)이 맞는 도착 좌표임
        resumeLillianArrivalX =
            _chapter1TableResumeChaeonX + _lillianStairsArrivalGap;
        resumeSkipGuideTrigger = true;
        resumeSkipPostSceneEndTrigger = true;
        break;
      case SaveCheckpoint.chapter3Door:
        // chapter3_door.json 트리거 지점에 세워두면 BakeryGame.update()가 알아서
        // onReachChapter3Door를 자연스럽게 다시 발동시켜줌(_resumeFromCheckpoint 참고)
        resumeChaeonX = kChapter3DoorTriggerX;
        break;
      case SaveCheckpoint.chapter5Start:
      case null:
        // 챕터5는 reentryChapter==chapter5일 때 BakeryGame.onLoad()의 챕터5 전용 블록이
        // 위치/카메라/대사 로드까지 이미 다 처리해줘서 여기선 안 건드림. resumeCheckpoint가
        // null이면(정상 진행) 당연히 아무 것도 안 함
        break;
      default:
        // 이 화면(game_play_screen.dart) 소관 아닌 체크포인트가 잘못 넘어온 경우 방어적으로 무시
        break;
    }

    _game = BakeryGame(
      skipChapter1Events: widget.skipChapter1Events,
      reentryChapter: widget.reentryChapter,
      resumeChaeonX: resumeChaeonX,
      resumeLillianArrivalX: resumeLillianArrivalX,
      resumeSkipGuideTrigger: resumeSkipGuideTrigger,
      resumeSkipPostSceneEndTrigger: resumeSkipPostSceneEndTrigger,
    );
    // 챕터3 재진입 모드면, 릴리안-채온 첫 만남 대사/회상 컷씬/빵 먹는 대사 단계를 전부 건너뜀
    if (widget.skipChapter1Events) {
      _dialoguePhase = DialoguePhase.kitchenApproach;
      // showDpad가 skip 모드에서는 _isFreeWalkPhase만 보고 판단하니까, 처음부터 걸을 수 있는
      // 상태로 시작해야 dpad가 바로 보임. 챕터5는 예외: onReachChapter5Start가 발동하기
      // 전까지 잠깐(배경/채온이 로딩되는 동안) dpad가 노출됐다 사라지는 게 보여서,
      // chapter5_start.json 로드 전까진 false로 시작해야 함(onReachChapter5Start에서 처리)
      if (widget.reentryChapter != ReentryChapter.chapter5) {
        _isFreeWalkPhase = true;
      }
    }

    _sceneController = SceneDialogueController(
      // widget.initialTemperature 대신 전역값을 읽음 - 챕터 경계(ChapterSelectScreen 경유)를
      // 넘어갈 때도 온도가 안 끊기게 하려면 여기서 위젯 파라미터를 안 쓰고 StoryState를 직접
      // 봐야 함. widget.initialTemperature는 이제 여기서 안 쓰이지만, 같은 챕터 안에서 화면끼리
      // 명시적으로 넘겨주던 기존 호출부들이 있어서 파라미터 자체는 그대로 둠(각 호출부 주석 참고)
      initialTemperature: StoryState.currentTemperature,
      onDialogueEnd: () {
        switch (_dialoguePhase) {
          case DialoguePhase.firstMeet:
            // 릴리안-채온 첫 만남 대화가 끝났으니 자유롭게 걸을 수 있는 구간으로 전환하고 릴리안 퇴장
            setState(() {
              _isFreeWalkPhase = true;
              _isLillianVisible = false;
              _dialoguePhase = DialoguePhase.none;
            });
            // chapter1FirstMeet로 이어하기한 경우, BakeryGame.onLoad()가 비동기라 initState의
            // _resumeFromCheckpoint()가 풀어준 isMovementBlocked를 나중에 다시 true로 덮어씀 -
            // 그래서 여기서 한 번 더 확실하게 풀어줘야 이어하기 후에도 실제로 걸어갈 수 있음
            // (정상 진행에선 이미 false라 아무 영향 없음)
            _game.isMovementBlocked = false;
            // 카메라가 채온이를 따라가도록 복귀
            _game.lillianArrivalX = null;
            _game.startCameraCatchUp();
            break;
          case DialoguePhase.table:
            // 자유이동으로 빠지지 않고, 검은 화면 페이드 전환 후 회상 컷씬(구름 미니게임)으로 전환
            _transitionToMemoryFlashback();
            break;
          case DialoguePhase.firstBread:
            // 앞치마 착용 후 주방으로 내려가는 연출 단계로 전환. 이때부터 계단 트리거가 실제로 소모되게 켜짐
            setState(() {
              _dialoguePhase = DialoguePhase.kitchenApproach;
              _isLillianVisible = false;
              _isFreeWalkPhase = true;
            });
            _game.isMovementBlocked = false;
            // kitchenApproach 단계에서만 계단 트리거가 실제로 소모되게 켜줌
            _game.isKitchenApproachActive = true;
            // 카메라가 채온이를 따라가도록 복귀
            _game.lillianArrivalX = null;
            _game.startCameraCatchUp();
            break;
          case DialoguePhase.kitchenApproach:
            // kitchenApproach 단계에서 로드되는 JSON 대사는 지금 chapter3_door.json 하나뿐이라
            // 여기로 오면 그 대사가 끝난 거임. 이동 잠금 풀어주면 나머지(계단 트리거)는 알아서 이어짐
            _game.isMovementBlocked = false;
            // dpad도 다시 보여줘야 계단까지 계속 걸어갈 수 있음
            setState(() => _isFreeWalkPhase = true);
            // 챕터5는 chapter5_start.json이 끝나는 시점도 여기로 옴. 릴리안 숨기고
            // 그 자리에서 앞치마로 갈아입힘(컷씬 없음). _hasChangedToChapter5Apron 가드로
            // chapter3_door.json 등 다른 kitchenApproach 대사에서는 안 타게 막음
            if (widget.reentryChapter == ReentryChapter.chapter5 &&
                !_hasChangedToChapter5Apron) {
              setState(() {
                _hasChangedToChapter5Apron = true;
                _isLillianVisible = false;
              });
              // 챕터1의 firstMeet/firstBread 케이스랑 동일한 패턴: lillianArrivalX만
              // null로 두면 다음 프레임에 카메라가 채온이 위치로 순간이동(번쩍)해버려서,
              // startCameraCatchUp으로 부드럽게 따라잡도록 함
              _game.lillianArrivalX = null;
              _game.startCameraCatchUp();
            }
            break;
          case DialoguePhase.none:
          case DialoguePhase.memoryFlashback:
            break;
        }
      },
      onLillianHop: () => _lillianHopController.forward(from: 0),
      onChaeonHop: () => _chaeonHopController.forward(from: 0),
    );
    _sceneController.addListener(_onSceneControllerChanged);

    // 릴리안 걷기 애니메이션 제어기 설정
    _lillianController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {}); // 애니메이션 프레임마다 화면을 다시 그려 릴리안 이동 반영
          });

    // 릴리안 계단 등장 애니메이션 제어기 설정
    _lillianStairsController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    _lillianStairsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isLillianWalking = false; // 도착하면 idle 모션으로 전환
          _dialoguePhase = DialoguePhase.table;
        });
        _sceneController.loadDialogue('assets/lines/chapter1/table.json');
      }
    });

    // 채온이 계단 하강 애니메이션 제어기 설정
    _chaeonStairsDescentController =
        AnimationController(vsync: this, duration: _stairsDescentDuration)
          ..addListener(() {
            setState(() {});
          });
    _chaeonStairsDescentController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToKitchenScreen();
      }
    });

    // 계단 근처 도달 시 주방으로 내려가는 연출 시작. kitchenApproach 단계가 아니면
    // (이전 단계에서 실수로 걸렸으면) 그냥 무시하고 반응 안 함
    _game.onReachStairs = () {
      if (_dialoguePhase != DialoguePhase.kitchenApproach) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerChaeonStairsDescent();
      });
    };

    // skipChapter1Events 모드에서 계단 가는 길목에 도달하면 chapter3_door.json 대사 로드.
    // isMovementBlocked/movePlayer(0)은 BakeryGame 쪽 트리거에서 이미 처리하고 넘어옴
    _game.onReachChapter3Door = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // dpad도 같이 숨겨야 함. 안 그러면 isMovementBlocked 때문에 실제로는 안 움직이면서
          // _chaeonState만 walk로 바뀌어서 걷는 GIF가 제자리에서 계속 재생되는 문제가 생김
          setState(() => _isFreeWalkPhase = false);
          _sceneController.loadDialogue(
            'assets/lines/chapter3/chapter3_door.json',
          );
        }
      });
    };

    // 챕터5는 씬 로드 직후 곧바로 발동(BakeryGame.onLoad 참고). 릴리안이 대사에 나오니까
    // 걷기 연출 없이 바로 보이는 위치에 세워둠. _lillianTargetX 기본값(900.0)이 챕터1
    // 첫 만남 때(_triggerLillianWalk) 릴리안이 멈추는 고정 좌표라 따로 안 바꾸고 그대로 씀.
    // _lillianController는 안 건드림(위 currentLillianX 계산부 주석 참고)
    _game.onReachChapter5Start = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isFreeWalkPhase = false;
            _isLillianVisible = true;
          });
          // 카메라 위치/스냅은 bakery_game.dart의 onLoad()에서 이미 동기적으로
          // 처리했어서(lillianArrivalX 세팅 + requestCameraSnap) 여기선 안 건드림
          _sceneController.loadDialogue(
            'assets/lines/chapter5/chapter5_start.json',
          );
        }
      });
    };

    // 릴리안/채온 깜짝 놀람 모션: 짧게 위로 튀었다가 제자리로 돌아옴
    _lillianHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _lillianHopOffset = _buildHopOffset(_lillianHopController);

    _chaeonHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _chaeonHopOffset = _buildHopOffset(_chaeonHopController);

    // 릴리안 도착 시 실행될 리스너
    _lillianController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isLillianWalking = false;
          _game.isMovementBlocked = false;
          _dialoguePhase = DialoguePhase.firstMeet;
        });
        // 릴리안 도착 후 첫 만남 대사 시작
        debugPrint("릴리안 도착 완료 조작 잠금 해제");
        _sceneController.loadDialogue('assets/lines/chapter1/first_meet.json');
      }
    });

    _game.onShowDialogue = (textLines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isDialogueActive = true;
            _isGuidePhaseStarted = true;
            _dialogueStep = 0;
            _dialogueTexts = textLines;
          });
        }
      });
    };

    // 릴리안이 계단을 다 올라와서 채온이 앞까지 걸어오면, 그 다음 연출을 트리거
    _game.onReachPostSceneEnd = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isFreeWalkPhase = false;
            _chaeonState = 'idle';
          });
          _triggerLillianStairsEntrance();
        }
      });
    };

    // 배경 오브젝트 클릭 시 정보성 팝업 텍스트 표시
    _game.onInteract = (text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _interactionText = text);
      });
    };

    _game.onGameUpdate = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    };

    // 왼쪽 끝까지 간 뒤 계속 왼쪽으로 가려 하면 마을 배경으로 전환
    _game.onReachLeftEdge = () {
      if (widget.isPrologue || _isNavigatingToTutorial) return;
      _isNavigatingToTutorial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          fadeThroughBlackRoute(
            TutorialScreen(
              initialStep: 2,
              initialPlayerX: 1500,
              initialFacingLeft: true,
              // 마을(튜토리얼)에서 빵집 문으로 다시 들어오면 새 GamePlayScreen을 만들지 않고
              // pop해서 지금 이 화면(대사/이동 진행 상태 그대로)으로 돌아오게 함
              returnToExistingGame: true,
              // 챕터3/4 재진입 상태면 마을에서도 채온이가 20% 평상복 스프라이트로 나오게
              // reentryChapter를 그대로 넘겨줌 (안 넘기면 기본값 none이라 항상 챕터1 스프라이트로 나왔음)
              reentryChapter: widget.reentryChapter,
              // 온도계 값도 이어받아서 마을에서 표시되는 온도가 끊기지 않게 함
              initialTemperature: _sceneController.temperature,
            ),
          ),
        );
        if (!mounted) return;
        // 왼쪽 벽 트리거 좌표(size.x/2)에 그대로 멈춰있으면 복귀하자마자 onReachLeftEdge가
        // 다시 발동해버리므로, 벽에서 살짝 떨어진 곳으로 옮기고 이동 입력도 정지시켜둠
        _game.movePlayer(0);
        _game.chaeon?.position.x = 150;
        setState(() {
          _isNavigatingToTutorial = false;
          _chaeonState = 'idle';
          _isChaeonFacingRight = true;
        });
      });
    };

    // 세이브 불러와서 들어온 경우, 위에서 등록한 트리거/애니메이션 콜백들이 자연스럽게 발동하길
    // 기다리는 대신 체크포인트가 가리키는 지점부터 바로 시작함. resumeCheckpoint가 null이면
    // 이 분기 자체를 안 타서 기존 동작 그대로임. 위 콜백들이 전부 등록된 다음(initState 맨
    // 마지막)에 불러야 함 - _lillianController 리스너 등 일부 로직이 여기서 필요함
    if (widget.resumeCheckpoint != null) {
      _resumeFromCheckpoint(widget.resumeCheckpoint!);
    }
  }

  // 릴리안이 계단 등장까지 다 마치고 채온이 옆에 도착해있는 상태로 스냅. first_meet/table/
  // first_bread 체크포인트 재개에 공통으로 필요해서 뺐음. 실제 걷기/계단 애니메이션은 재생
  // 안 하고 도착 결과만 그대로 세팅함. _lillianController.value를 직접 1.0으로 두는 방식도
  // 생각해봤는데, 그러면 "도착 완료" 상태 리스너(제일 처음 first_meet.json 로드하는 그
  // 리스너)가 setState를 동반해서 initState 도중에 바로 발동해버려 위험함(빌드 되기 전에
  // setState 호출하는 셈이라 에러남). 그래서 _lillianStartX를 목표 지점(_lillianTargetX)이랑
  // 똑같이 맞춰서, 컨트롤러 값이 뭐든 Tween(begin,end).evaluate 결과가 항상 도착 위치로
  // 고정되게 하는 방식으로 우회함
  // lillianX: 체크포인트마다 릴리안이 도착해있어야 할 좌표가 다름(첫 만남 등장은 900,
  // 계단 등장은 채온이 위치 + _lillianStairsArrivalGap) - 예전엔 900으로 고정해뒀다가
  // table/first_bread 재개 시 릴리안이 채온이보다 왼쪽에 서는 버그가 있어서 파라미터로 뺌
  void _snapLillianArrived(double lillianX) {
    _isLillianVisible = true;
    _isLillianFacingLeft = true;
    _lillianTargetX = lillianX;
    _lillianStartX = _lillianTargetX;
    _game.lillianArrivalX = _lillianTargetX;
    _isLillianWalking = false;
  }

  // resumeCheckpoint로 들어온 경우 initState 끝에서 호출됨. kitchen_screen.dart의
  // _resumeFromCheckpoint랑 동일한 패턴이지만, 이 화면은 Flame(BakeryGame) 기반이라 캐릭터
  // 위치/카메라까지 완벽히 재현하진 않고 대사가 정상적으로 이어지는 데 필요한 최소한의
  // 상태만 맞춤. StoryState/ChapterProgress는 이 화면 진입 전에 이미 복원되어 있는 걸 전제로 함
  //
  // (업데이트: 캐릭터 위치/카메라는 initState 위쪽에서 BakeryGame 생성 시 resumeChaeonX로
  // 처리하게 바꿈 - 여기서 chaeon 위치를 옮기려고 하면 그 시점엔 아직 mount 전이라 안 먹혔음.
  // 설정 버튼이 안 뜨던 것도 같이 발견해서 _isGuidePhaseStarted를 챕터1 케이스들에 추가함)
  void _resumeFromCheckpoint(SaveCheckpoint checkpoint) {
    switch (checkpoint) {
      case SaveCheckpoint.chapter3Door:
        // 위치는 BakeryGame 생성 시 이미 트리거 지점(kChapter3DoorTriggerX)으로 옮겨놔서,
        // update()가 알아서 onReachChapter3Door를 자연스럽게 다시 발동시켜줌(그쪽이
        // _isFreeWalkPhase/대사 로드까지 다 처리함) - 여기서 또 loadDialogue 부르면 중복
        // 로드됨. dpad가 잠깐이라도 보이지 않게 미리만 꺼둠
        _isFreeWalkPhase = false;
        break;
      case SaveCheckpoint.chapter5Start:
        // 챕터5는 BakeryGame.onLoad()의 챕터5 전용 블록이 위치/카메라/대사 로드까지 전부
        // 알아서 처리해줘서(reentryChapter==chapter5면 무조건 발동) 여기서 따로 할 게 없음
        break;
      case SaveCheckpoint.chapter1FirstMeet:
        // 900은 _triggerLillianWalk()의 첫 만남 등장 도착 좌표랑 동일
        _snapLillianArrived(900.0);
        _dialoguePhase = DialoguePhase.firstMeet;
        // 정상 흐름에선 가이드 대사(_game.onShowDialogue)가 이 값을 켜주는데, 그 경로를
        // 건너뛰니까 직접 켜줘야 함 - 안 그러면 설정 버튼이 안 뜸(노출 조건 참고)
        _isGuidePhaseStarted = true;
        _game.isMovementBlocked = false;
        _sceneController.loadDialogue('assets/lines/chapter1/first_meet.json');
        break;
      case SaveCheckpoint.chapter1Table:
        // 계단 등장(두 번째 등장) 도착 좌표 - 채온이 위치(_chapter1TableResumeChaeonX) + 280
        _snapLillianArrived(
          _chapter1TableResumeChaeonX + _lillianStairsArrivalGap,
        );
        _dialoguePhase = DialoguePhase.table;
        _isGuidePhaseStarted = true;
        _game.isMovementBlocked = false;
        _sceneController.loadDialogue('assets/lines/chapter1/table.json');
        break;
      case SaveCheckpoint.chapter1FirstBread:
        // chapter1Table이랑 동일한 이유로 계단 등장 도착 좌표를 그대로 씀
        _snapLillianArrived(
          _chapter1TableResumeChaeonX + _lillianStairsArrivalGap,
        );
        // table.json 먹는 구간을 이미 지난 상태라 먹는 클로즈업이 다시 뜨면 안 됨
        _hasEatenBread = true;
        _dialoguePhase = DialoguePhase.firstBread;
        _isGuidePhaseStarted = true;
        _game.isMovementBlocked = false;
        _sceneController.loadDialogue('assets/lines/chapter1/first_bread.json');
        break;
      default:
        // 이 화면(game_play_screen.dart) 소관 아닌 체크포인트가 잘못 넘어온 경우를 대비한
        // 방어적 분기 - 아무 것도 안 하고 기존 자연 진입 흐름(가이드 대사 등)에 맡김
        break;
    }
  }

  // 지금 skipChapter1Events/reentryChapter/_dialoguePhase 조합 기준으로 "가장 최근에 통과한
  // 체크포인트"를 찾음. kitchen_screen.dart의 _detectCurrentCheckpoint랑 동일한 이유로,
  // 저장 버튼이 떠 있다는 것 자체가 안정된 상태라는 뜻이라 이 시점 값들만으로 확정할 수 있음
  SaveCheckpoint _detectCurrentCheckpoint() {
    // 챕터5 재진입도 choice_screen.dart에서 skipChapter1Events:true로 넘어오기 때문에,
    // 아래 chapter3Door 분기보다 먼저 확인해야 함 - 순서가 바뀌어 있으면(원래 이 체크가
    // chapter3Door 분기 뒤에 있었음) 챕터5 저장이 chapter3Door로 잘못 분류되는 버그가 있었음
    if (widget.reentryChapter == ReentryChapter.chapter5) {
      return SaveCheckpoint.chapter5Start;
    }
    if (widget.skipChapter1Events) {
      // 챕터3/4 재진입은 chapter3_door.json 트리거 하나뿐(챕터5는 위에서 먼저 걸러짐)
      return SaveCheckpoint.chapter3Door;
    }
    // 챕터1 프롤로그 이후 첫 플레이 흐름. 이 화면에서 로드되는 마지막 파일이 뭐였는지를
    // _dialoguePhase로 판단함(none은 첫 만남 대사 시작 전이라 아직 아무 파일도 안 실렸지만,
    // 이 화면이 지원하는 가장 이른 체크포인트인 firstMeet로 대체함)
    switch (_dialoguePhase) {
      case DialoguePhase.firstBread:
      case DialoguePhase.kitchenApproach:
        return SaveCheckpoint.chapter1FirstBread;
      case DialoguePhase.memoryFlashback:
      case DialoguePhase.table:
        return SaveCheckpoint.chapter1Table;
      case DialoguePhase.firstMeet:
      case DialoguePhase.none:
        return SaveCheckpoint.chapter1FirstMeet;
    }
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

  void _onSceneControllerChanged() {
    if (!mounted) return;
    setState(() {
      // 먹는 클로즈업 노드를 한 번이라도 지나가면 이후로는 계속 "먹은 상태"로 취급
      final String? nodeId = _sceneController.sceneNodeId;
      if (_dialoguePhase == DialoguePhase.table &&
          nodeId != null &&
          (widgets.eatingCloseupNodeIdsA.contains(nodeId) ||
              widgets.eatingCloseupNodeIdsB.contains(nodeId))) {
        _hasEatenBread = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_thermometerImagesPrecached) {
      _thermometerImagesPrecached = true;
      for (int i = 1; i <= 10; i++) {
        precacheImage(
          AssetImage('assets/images/main_thermometer_$i.png'),
          context,
        );
      }
      for (int i = 1; i <= widgets.dialogueBoxWidths.length; i++) {
        precacheImage(
          AssetImage('assets/images/main_dialogue_box_$i.png'),
          context,
        );
      }
      // table.json 대사 구간에서 채온이 먹는 GIF를 전체화면 클로즈업으로 보여주므로, 미리 프리캐싱
      // chaeon_laughing1.gif는 line_004a3/line_004a4의 chaeonExpression으로 새로 추가된
      // 에셋인데 여기 빠져있었음 - 이 두 노드는 릴리안 expression(surprise/thinking2)도
      // 같이 바뀌는 지점이라, 실제로는 이 채온이 GIF가 안 캐싱돼서 나던 번쩍임이 릴리안
      // 표정 전환 탓처럼 보였던 것 같음
      const List<String> tableSceneAssets = [
        'assets/images/bread_plate.png',
        'assets/images/chaeon_laughing.gif',
        'assets/images/chaeon_laughing.png',
        'assets/images/chaeon_laughing1.gif',
        'assets/images/chaeon_holding_bread.png',
      ];
      for (final asset in tableSceneAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // first_bread.json 특정 노드에서 잠깐 바뀌는 채온이 감정 GIF도 미리 프리캐싱.
      // beforeReveal/afterReveal 둘 다 있을 수 있어서 둘 다 챙겨줌
      for (final override in widgets.chaeonSpriteOverrides.values) {
        precacheImage(AssetImage(override.beforeReveal), context);
        final String? afterReveal = override.afterReveal;
        if (afterReveal != null) {
          precacheImage(AssetImage(afterReveal), context);
        }
      }
      // first_meet.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.lillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // table.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.tableLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // first_bread.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.firstBreadLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // 앞치마 착용 연출(kitchenApproach)에서 쓰는 채온이 스프라이트도 프리캐싱
      const List<String> apronAssets = [
        'assets/images/chaeon_apron_putting_on.gif',
        'assets/images/chaeon_apron_idle.gif',
      ];
      for (final asset in apronAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // 챕터5는 앞치마 갈아입은 뒤로 idle이면 chaeon_80.gif, 걷는 중이면 chaeon_apron_80.gif를 쓰니까 둘 다 프리캐싱
      const List<String> chapter5ApronAssets = [
        'assets/images/chaeon_80.gif',
        'assets/images/chaeon_apron_80.gif',
      ];
      for (final asset in chapter5ApronAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // 챕터3 재진입 모드(skipChapter1Events)에서 지하 내려가기 전까지 쓰는 20% 평상복 스프라이트도 프리캐싱
      const List<String> chapter3ReentryAssets = [
        'assets/images/chaeon_20_normal.gif',
        'assets/images/chaeon_20_normal_walk.gif',
      ];
      for (final asset in chapter3ReentryAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // 챕터4 재진입 모드는 같은 자리에서 20% 대신 50% 평상복 스프라이트를 씀
      const List<String> chapter4ReentryAssets = [
        'assets/images/chaeon_50_normal.gif',
        'assets/images/chaeon_50_normal_walk.gif',
      ];
      for (final asset in chapter4ReentryAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // 챕터5 재진입 모드는 대사 끝나기 전(앞치마 입기 전)까지 80% 평상복 스프라이트를 씀
      const List<String> chapter5ReentryAssets = [
        'assets/images/chaeon_80_normal.gif',
        'assets/images/chaeon_80_normal_walk.gif',
      ];
      for (final asset in chapter5ReentryAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // _resolveLillianSprite 기본값(idle/walk)도 프리캐싱. 챕터1은 릴리안이 걸어오는
      // 연출 동안 디코딩 시간이 가려졌는데, 챕터5는 씬 로드되자마자 바로 idle로 등장해서
      // 프리캐싱이 안 돼있으면 채온이보다 1초 정도 늦게 나타나는 게 눈에 띄었음
      const List<String> lillianDefaultAssets = [
        'assets/images/lillian_idle.gif',
        'assets/images/lillian_walk.gif',
      ];
      for (final asset in lillianDefaultAssets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    _lillianController.dispose(); // 메모리 누수 방지용
    _lillianStairsController.dispose();
    _lillianHopController.dispose();
    _chaeonHopController.dispose();
    _chaeonStairsDescentController.dispose();
    _memoryFadeTimer?.cancel();
    _saveConfirmationTimer?.cancel();
    super.dispose();
  }

  // table.json 종료 -> 검은 화면 페이드인(300ms) -> 유지(400ms, 이 동안 회상 컷씬으로 전환해둠)
  // -> 페이드아웃(300ms)되며 memory_car_bumpy.gif 노출
  void _transitionToMemoryFlashback() {
    setState(() {
      _showMemoryFadeOverlay = true;
      _memoryFadeOpacity = 0.0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _memoryFadeOpacity = 1.0);
    });
    _memoryFadeTimer = Timer(_memoryFadeInDuration, () {
      if (!mounted) return;
      // 화면이 완전히 검게 덮인 상태에서 미리 전환해둬서, 화면이 열릴 때 바로 회상 컷씬이 보임
      setState(() => _dialoguePhase = DialoguePhase.memoryFlashback);
      _memoryFadeTimer = Timer(_memoryFadeHoldDuration, () {
        if (!mounted) return;
        setState(() => _memoryFadeOpacity = 0.0);
        _memoryFadeTimer = Timer(_memoryFadeOutDuration, () {
          if (!mounted) return;
          setState(() => _showMemoryFadeOverlay = false);
        });
      });
    });
  }

  // 현재 씬 노드에 맞춰 채온이 스프라이트 경로와 세로 위치 보정값, 그리고 이 스프라이트
  // 전환에 PopInImage 페이드(50ms)를 걸지(true) 즉시 전환(false, duration: Duration.zero)할지를
  // 결정. 렌더링은 항상 PopInImage 하나로 통일돼있고, chaeonExpression이어도
  // widgets.chaeonEatingSprites(빵 먹는 진행 단계 GIF)면 false를 반환해 페이드 없이 즉시
  // 전환됨(자세 차이가 커서 페이드가 어색해 보임).
  // first_bread.json 단계면 chaeonSpriteOverrides부터 확인하고(해당 노드 아니면 기본 idle로 복귀),
  // 그 외 단계(table.json 등)면 기존처럼 _hasEatenBread/이동 상태로 결정
  // override가 있는 노드는 bubbleRevealed(말풍선이 떴는지) 기준으로 beforeReveal/afterReveal 중 골라줌
  (String, double, bool) _resolveChaeonSprite(String? sceneNodeId) {
    // 챕터5는 chapter5_start.json이 끝나면 그 자리에서 앞치마로 갈아입어야 해서, 갈아입은
    // 뒤로는 다른 재진입 챕터(챕터3/4, 이 화면에선 계속 평상복)랑 다르게 취급해야 함
    final bool isChapter5WithApron =
        widget.reentryChapter == ReentryChapter.chapter5 &&
        _hasChangedToChapter5Apron;
    // 계단 하강 중엔 그 시점 _chaeonState(walk/idle)와 무관하게 항상 한 스프라이트로 고정.
    // 챕터1은 apron_idle.gif, 챕터3 재진입 모드는 chaeon_20_normal_walk.gif,
    // 챕터4 재진입 모드는 chaeon_50_normal_walk.gif
    if (_isChaeonDescendingStairs) {
      return (
        // 챕터5는 80% 앞치마 에셋 하나만 씀 (idle/walk 구분 없음)
        isChapter5WithApron
            ? 'assets/images/chaeon_apron_80.gif'
            : widget.reentryChapter == ReentryChapter.chapter4
            ? 'assets/images/chaeon_50_normal_walk.gif'
            : widget.skipChapter1Events
            ? 'assets/images/chaeon_20_normal_walk.gif'
            : 'assets/images/chaeon_apron_idle.gif',
        0,
        false,
      );
    }
    // 챕터3/4 재진입 모드는 kitchenApproach 단계로 시작해도 아직 앞치마 입기 전(지하 내려가기 전)
    // 상태라서, 아래 kitchenApproach 앞치마 분기보다 먼저 여기서 평상복 스프라이트로 처리함.
    // 챕터4는 50%, 나머지(챕터3)는 20% 상태 에셋. 챕터5는 앞치마로 갈아입은 뒤엔 여길 건너뛰고
    // 아래 kitchenApproach 앞치마 분기로 흘러가게 함
    if (widget.skipChapter1Events && !isChapter5WithApron) {
      final bool isChapter4Reentry =
          widget.reentryChapter == ReentryChapter.chapter4;
      // 챕터5는 chapter5_start.json 대사 끝나기 전(앞치마 갈아입기 전)까지 80% 평상복 에셋을 씀
      if (widget.reentryChapter == ReentryChapter.chapter5) {
        return (
          _chaeonState == 'walk'
              ? 'assets/images/chaeon_80_normal_walk.gif'
              : 'assets/images/chaeon_80_normal.gif',
          0,
          false,
        );
      }
      return (
        _chaeonState == 'walk'
            ? (isChapter4Reentry
                  ? 'assets/images/chaeon_50_normal_walk.gif'
                  : 'assets/images/chaeon_20_normal_walk.gif')
            : (isChapter4Reentry
                  ? 'assets/images/chaeon_50_normal.gif'
                  : 'assets/images/chaeon_20_normal.gif'),
        0,
        false,
      );
    }
    // 현재 노드에 chaeonExpression이 있으면(예: table.json의 line_004a2_laugh/line_004a3)
    // 아래 단계별 기본 로직보다 우선해서 그걸 보여줌
    final String? chaeonExpressionAsset = _sceneController
        .sceneDialogue
        ?.nodes[sceneNodeId]
        ?.chaeonExpression
        ?.asset;
    if (chaeonExpressionAsset != null) {
      // widgets.chaeonEatingSprites(빵 먹는 진행 단계 GIF, 0%->20%->50%->80%)로 바뀔 땐
      // 자세 차이가 커서 크로스페이드가 어색해 보이므로 페이드 없이 즉시 전환함
      final bool shouldFade = !widgets.chaeonEatingSprites.contains(
        chaeonExpressionAsset,
      );
      return (chaeonExpressionAsset, 0, shouldFade);
    }
    if (_dialoguePhase == DialoguePhase.firstBread) {
      final widgets.ChaeonSpriteOverride? override =
          widgets.chaeonSpriteOverrides[sceneNodeId];
      if (override != null) {
        if (_sceneController.bubbleRevealed) {
          final String? afterReveal = override.afterReveal;
          if (afterReveal != null) {
            return (afterReveal, override.afterRevealVerticalOffsetPx, true);
          }
          // afterReveal이 따로 없으면 기본 idle로 폴백
          return ('assets/images/chaeon_idle_right.gif', 0, false);
        }
        return (
          override.beforeReveal,
          override.beforeRevealVerticalOffsetPx,
          true,
        );
      }
      return ('assets/images/chaeon_idle_right.gif', 0, false);
    }
    // 챕터5는 앞치마로 갈아입은 뒤로 idle이면 chaeon_80.gif, 걷는 중이면 chaeon_apron_80.gif
    if (isChapter5WithApron) {
      return (
        _chaeonState == 'walk'
            ? 'assets/images/chaeon_apron_80.gif'
            : 'assets/images/chaeon_80.gif',
        0,
        false,
      );
    }
    // 앞치마 착용 후 주방으로 내려가는 연출 단계(kitchenApproach)에서는, walk 상태면 apron_idle.gif
    // TODO: 나중에 앞치마 입고 걷는 walk 전용 에셋 나오면 _chaeonState 보고 분기하도록 교체할 예정
    if (_dialoguePhase == DialoguePhase.kitchenApproach) {
      return (
        _chaeonState == 'walk'
            ? 'assets/images/chaeon_apron_idle.gif'
            : 'assets/images/chaeon_apron_putting_on.gif',
        0,
        false,
      );
    }
    if (_hasEatenBread) {
      return ('assets/images/chaeon_holding_bread.png', 0, false);
    }
    return (
      _chaeonState == 'walk'
          ? 'assets/images/chaeon_walk_right.gif'
          : 'assets/images/chaeon_idle_right.gif',
      0,
      false,
    );
  }

  // 현재 씬 노드에 맞춰 릴리안 스프라이트 경로를 결정. 노드에 expression이 있으면 그걸 쓰고,
  // 없으면 기존처럼 걷는 중인지 여부로 결정.
  // 두번째 값은 좌우 반전(_isLillianFacingLeft) 적용 여부: 옆모습 걷기 스프라이트
  // (lillian_walk.gif)만 반전 대상이고, idle/expression은 전부 정면 구도라 절대 반전 안 함.
  // 세번째 값은 PopInImage로 페이드할지 여부(렌더링에서 이 값에 따라 PopInImage/Image.asset
  // 위젯 자체를 다르게 씀): walk<->idle 전환에 PopInImage(크로스페이드)를 쓰면, duration을
  // 0으로 줘도 전환 시작 프레임에서 이전 이미지(walk, 반전됨)가 바깥쪽 Transform.flip의
  // 새 상태(반전 안 함)를 물려받아 순간적으로 "반전됐다가 돌아오는" 것처럼 보이는 문제가
  // 있었음(duration과 무관하게 PopInImage 구조상 피할 수 없음, 실제로 재현됨). 그래서
  // walk/idle 전환은 Image.asset으로 즉시 스왑(크로스페이드 위젯 자체를 안 씀)하고, 실제
  // 서사적 표정 변화(expression)에만 PopInImage 페이드를 적용함
  (String asset, bool shouldFlip, bool isExpression) _resolveLillianSprite(
    String? sceneNodeId,
  ) {
    final String? expressionAsset =
        _sceneController.sceneDialogue?.nodes[sceneNodeId]?.expression?.asset;
    if (expressionAsset != null) return (expressionAsset, false, true);
    if (_isLillianWalking) {
      return ('assets/images/lillian_walk.gif', true, false);
    }
    return ('assets/images/lillian_idle.gif', false, false);
  }

  // 짧게 위로 튀었다가 바운스감 있게 제자리로 돌아오는 오프셋 애니메이션 생성
  Animation<double> _buildHopOffset(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -20.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -20.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(controller)..addListener(() {
      setState(() {}); // 모션 프레임마다 화면을 다시 그려 오프셋 반영
    });
  }

  void _triggerLillianWalk() {
    setState(() {
      _isDialogueActive = false; // 대화창 끄기
      _isLillianVisible = true; // 대화가 끝났으니 이제부터 릴리안 등장
      _isLillianWalking = true; // 릴리안 걷기 상태 돌입
      // lillian_walk.gif 원본은 오른쪽을 보고 있는데, 릴리안은 항상 채온이보다 오른쪽(x=1500)에서
      // 왼쪽(x=900, 채온이는 x=650)으로 걸어오므로 반전(flip)해야 진행 방향(왼쪽)을 보며 걷고,
      // 도착 후에도 왼쪽에 있는 채온이를 바라보는 방향과 일치함. 그래서 걷는 중/도착 후 모두 true로 고정
      // (전에 false로 고정했다가 걷는 방향과 반대로 뒷걸음질 치는 것처럼 보이는 문제가 있었음)
      _isLillianFacingLeft = true;

      // 채온이는 항상 x=650에서 멈추므로, 릴리안의 도착 좌표도 고정값 사용
      _lillianTargetX = 900.0;

      // 이 시점부터 카메라가 채온이 대신 "채온이-릴리안 도착 지점"의 중간을 따라가도록 설정
      _game.lillianArrivalX = _lillianTargetX;
    });

    // 릴리안 걷는 속도를 채온이 이동 속도(Chaeon.speed)와 동일하게 맞춤
    double distance = (_lillianTargetX - _lillianStartX).abs();
    double chaeonSpeed = _game.chaeon?.speed ?? 250.0 * 0.85;
    int durationMs = (distance / chaeonSpeed * 1000).round().clamp(1, 60000);
    _lillianController.duration = Duration(milliseconds: durationMs);

    _lillianController.forward(from: 0.0);
  }

  // 릴리안이 계단을 올라와서 채온이 앞까지 걸어오는 연출 트리거
  void _triggerLillianStairsEntrance() {
    // 릴리안이 계단을 다 올라와서 채온이 앞까지 걸어오면, 그 다음 연출을 트리거
    final double chaeonX = _game.chaeon?.position.x ?? 1300.0;
    final Offset walkEnd = Offset(chaeonX + 280, 172); // 채온이 앞 280 거리

    final double climbDist = (_stairsTopPoint - _stairsOffscreenPoint).distance;
    final double walkDist = (walkEnd - _stairsTopPoint).distance;

    _lillianStairsAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: _stairsOffscreenPoint,
          end: _stairsTopPoint,
        ),
        weight: climbDist,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: _stairsTopPoint, end: walkEnd),
        weight: walkDist,
      ),
    ]).animate(_lillianStairsController);

    // 릴리안 걷는 속도를 채온이 이동 속도와 동일하게 맞춤
    double chaeonSpeed = _game.chaeon?.speed ?? 250.0 * 0.85;
    int durationMs = ((climbDist + walkDist) / chaeonSpeed * 1000)
        .round()
        .clamp(1, 60000);
    _lillianStairsController.duration = Duration(milliseconds: durationMs);

    // 첫 만남 등장 때와 같은 방식: 카메라가 채온이와 릴리안 도착 예정 지점의 중간을 추적
    _game.lillianArrivalX = walkEnd.dx;

    setState(() {
      _isLillianSecondEntranceActive = true;
      _isLillianVisible = true;
      _isLillianWalking = true;
      // 이번에도 계단 꼭대기(x=1680)에서 채온이 앞(chaeonX+280, 채온이보다 오른쪽)까지
      // 왼쪽으로 걸어오므로, 첫 등장 때와 같은 이유로 반전(왼쪽을 보게) 시켜야 함
      _isLillianFacingLeft = true;
    });

    _lillianStairsController.forward(from: 0);
  }

  // 채온이가 계단 근처에 도달하면 조작을 잠그고, 계단 꼭대기(_stairsTopPoint.dx,
  // _chaeonStairsDescentStartY)에서 화면 밖(계단 아래, _chaeonStairsDescentEnd)으로
  // 내려가는 하강 애니메이션을 재생. y는 _stairsTopPoint.dy(릴리안용)가 아니라
  // _chaeonStairsDescentStartY를 써야 평소 걷던 위치에서 이어져서 시작함
  void _triggerChaeonStairsDescent() {
    _chaeonStairsDescentAnimation =
        TweenSequence<Offset>([
          TweenSequenceItem(
            tween: Tween<Offset>(
              begin: Offset(_stairsTopPoint.dx, _chaeonStairsDescentStartY),
              end: _chaeonStairsDescentEnd,
            ),
            weight: 1,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _chaeonStairsDescentController,
            curve: Curves.easeIn,
          ),
        );

    setState(() {
      _isFreeWalkPhase = false; // 하강 중엔 방향키도 숨김
      _isChaeonDescendingStairs = true;
    });

    _chaeonStairsDescentController.forward(from: 0);
  }

  // 하강 애니메이션이 끝나면 암전 후 주방 화면으로 전환. onReachLeftEdge에서 쓰는 것과 동일한
  // fadeThroughBlackRoute + 중복 네비게이션 방지 패턴
  void _navigateToKitchenScreen() {
    if (_isNavigatingToKitchen) return;
    _isNavigatingToKitchen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.push(
        context,
        fadeThroughBlackRoute(
          KitchenScreen(
            initialTemperature: _sceneController.temperature,
            // 재진입 챕터별로 주방 진입 모드가 갈림. reentryChapter가 none이면 챕터1 최초 진입
            mode: switch (widget.reentryChapter) {
              ReentryChapter.chapter5 => KitchenScreenMode.chapter5Start,
              ReentryChapter.chapter4 => KitchenScreenMode.chapter4Start,
              ReentryChapter.chapter3 => KitchenScreenMode.chapter3Start,
              ReentryChapter.none => KitchenScreenMode.chapter1End,
            },
          ),
        ),
      );
      if (!mounted) return;
      // 주방에서 왼쪽 끝까지 이동해 다시 계단을 올라와 돌아온 경우: 하강 연출 상태를 되돌리고,
      // 트리거 좌표에 딱 걸쳐있으면 돌아오자마자 하강 연출이 다시 발동해버리므로 살짝 떨어뜨려둠
      _game.chaeon?.position.x = kitchenStairsTriggerX - 100;
      _game.movePlayer(0);
      _game.resetStairsTrigger();
      _game.isMovementBlocked = false;
      setState(() {
        _isNavigatingToKitchen = false;
        _isChaeonDescendingStairs = false;
        _isFreeWalkPhase = true;
        _chaeonState = 'idle';
      });
    });
  }

  void _advanceDialogue() {
    setState(() {
      if (_dialogueStep < _dialogueTexts.length - 1) {
        _dialogueStep++;
      } else {
        // 대화창이 모두 끝나면 릴리안 걸어오기
        _triggerLillianWalk();
      }
    });
  }

  // 뒤로가기 버튼: 대화창이 켜져 있으면 대화창을 닫고, 아니면 선택지 이전 line으로 돌아감
  void _handleBackButtonTap() {
    if (_isDialogueActive && _dialogueStep != 0) {
      _advanceDialogue();
      return;
    }
    _sceneController.goBackScene();
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // dpad 노출 조건. 원래 식(!_isGuidePhaseStarted || _isFreeWalkPhase)은 skipChapter1Events
    // 모드에서 문제가 생김: 이 모드는 가이드 대사(x=650) 자체를 안 거쳐서 _isGuidePhaseStarted가
    // 끝까지 false로 남고, 그러면 !_isGuidePhaseStarted가 항상 true라 _isFreeWalkPhase를 아무리
    // false로 바꿔도(예: chapter3_door.json 대사 중) OR 전체가 항상 true가 되어 dpad가 안 사라짐.
    // 그래서 skip 모드는 _isFreeWalkPhase 하나만 보고 판단하도록 분기함.
    // canInteract(오브젝트 클릭 정보 팝업 허용 여부)도 같은 식을 쓰길래 동일하게 재사용함
    final bool showDpad = widget.skipChapter1Events
        ? _isFreeWalkPhase
        : (!_isGuidePhaseStarted || _isFreeWalkPhase);

    // 오브젝트 클릭 정보 팝업은 이동 가능한 상태에서만 허용
    _game.canInteract = !widget.isPrologue && showDpad;

    // 실시간 카메라 스크롤 값 계산
    double cameraX = _game.camera.isMounted
        ? _game.camera.viewfinder.position.x
        : 0.0;

    // 배경이 세로로 항상 꽉 차도록 하는 카메라 줌
    double zoom = h / _game.mapHeight;

    // 채온이 렌더링 좌표 계산
    double chaeonX = (_game.chaeon != null && _game.chaeon!.isMounted)
        ? _game.chaeon!.position.x
        : 0.0;

    double chaeonDisplaySize = 172 * zoom;
    // 계단 하강 중엔 게임 월드 절대좌표(_stairsTopPoint -> _chaeonStairsDescentEnd) 애니메이션 값을
    // 그대로 렌더링 좌표로 사용 (기존 chaeon.position.x 기반 좌표 대신)
    final Offset? chaeonStairsDescentPos = _isChaeonDescendingStairs
        ? _chaeonStairsDescentAnimation?.value
        : null;
    double renderChaeonX =
        ((chaeonStairsDescentPos?.dx ?? chaeonX) - cameraX) * zoom -
        chaeonDisplaySize / 2;

    // 릴리안 렌더링 좌표 계산
    double currentLillianX;
    double lillianTopValue;
    if (widget.reentryChapter == ReentryChapter.chapter5) {
      // 챕터5는 _lillianController를 아예 안 건드림. 그 컨트롤러엔 이미 챕터1
      // _triggerLillianWalk() 완료 시 first_meet.json을 로드하는 상태 리스너가 걸려있어서,
      // value를 강제로 1.0으로 바꾸면 AnimationStatus.completed로 인식돼 그 리스너가
      // 같이 발동해버림(실제로 이 버그 때문에 chapter5_start.json이 first_meet.json으로
      // 덮어써졌었음). 그래서 컨트롤러 대신 도착 좌표(_lillianTargetX)를 바로 씀
      currentLillianX = _lillianTargetX;
      lillianTopValue = rH(172);
    } else if (_isLillianSecondEntranceActive && _lillianStairsAnimation != null) {
      final Offset pos = _lillianStairsAnimation!.value;
      currentLillianX = pos.dx;
      lillianTopValue = rH(pos.dy);
    } else {
      currentLillianX = Tween<double>(
        begin: _lillianStartX,
        end: _lillianTargetX,
      ).evaluate(_lillianController);
      lillianTopValue = rH(172);
    }
    // 채온이랑 똑같이 중심 기준 보정 필요 (안 하면 릴리안이 오른쪽으로 밀려 그려짐)
    double lillianDisplaySize = 174 * zoom;
    double renderLillianX =
        (currentLillianX - cameraX) * zoom - lillianDisplaySize / 2;

    // 채온-릴리안 말풍선 가로 위치 계산용: 각 캐릭터의 화면상 가로 중심
    double chaeonCenterX = renderChaeonX + chaeonDisplaySize / 2;
    double lillianCenterX = renderLillianX + lillianDisplaySize / 2;

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final (
      String chaeonSpriteAsset,
      double chaeonSpriteVerticalOffsetPx,
      bool isChaeonSpriteExpression,
    ) = _resolveChaeonSprite(
      sceneNodeId,
    );
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;
    final DialogueNode? lastLineNode = _sceneController.lastLineNode;

    // table.json의 먹는 대사 구간에서는 채온 GIF 대신 전체화면 클로즈업을 보여줌 (분기별로 다른 에셋)
    final bool isEatingCloseupActiveA =
        _dialoguePhase == DialoguePhase.table &&
        sceneNodeId != null &&
        widgets.eatingCloseupNodeIdsA.contains(sceneNodeId);
    final bool isEatingCloseupActiveB =
        _dialoguePhase == DialoguePhase.table &&
        sceneNodeId != null &&
        widgets.eatingCloseupNodeIdsB.contains(sceneNodeId);
    final bool isEatingCloseupActive =
        isEatingCloseupActiveA || isEatingCloseupActiveB;

    // 먹는 클로즈업 중에는 채온/릴리안 스프라이트가 안 보이므로, 말풍선도 캐릭터의
    // 월드 좌표 대신 화면 중앙(클로즈업 이미지 기준)에 맞춰 표시
    final double bubbleChaeonCenterX = isEatingCloseupActive
        ? w / 2
        : chaeonCenterX;
    final double bubbleLillianCenterX = isEatingCloseupActive
        ? w / 2
        : lillianCenterX;

    // 빵 접시는 채온-릴리안 사이, 테이블 가로 중앙에 표시 (테이블 상판 바로 위)
    double breadPlateWorldX = (chaeonX + currentLillianX) / 2;
    double breadPlateDisplaySize = rW(73);
    double renderBreadPlateX =
        (breadPlateWorldX - cameraX) * zoom - breadPlateDisplaySize / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 게임 엔진 구역
            Positioned.fill(
              key: const ValueKey('game'),
              child: GameWidget(
                game: _game,
                overlayBuilderMap: {
                  'dialogue': (BuildContext context, BakeryGame game) {
                    return DialogueOverlay(game: game);
                  },
                },
                initialActiveOverlays: widget.isPrologue
                    ? const ['dialogue']
                    : const [],
              ),
            ),

            // 2층: 채온 GIF (table.json 먹는 구간에서는 전체화면 클로즈업으로 대체)
            if (!widget.isPrologue &&
                _game.chaeon != null &&
                _game.chaeon!.isMounted)
              if (isEatingCloseupActive)
                Positioned.fill(
                  key: const ValueKey('chaeon_eating_closeup'),
                  child: widgets.EatingCloseupOverlay(
                    onFinished: _sceneController.advanceScene,
                    // line_004a 분기(A)에서만 eating_1/eating_2 사이클을 두 번 반복
                    repeatCount: isEatingCloseupActiveA ? 2 : 1,
                  ),
                )
              else if (chaeonStairsDescentPos != null)
                // 계단 하강 중: 게임 월드 절대좌표(top 기준, 릴리안 계단 등장 연출과 동일한 방식)로 배치
                Positioned(
                  key: const ValueKey('chaeon'),
                  left: renderChaeonX,
                  top: rH(chaeonStairsDescentPos.dy),
                  height: chaeonDisplaySize,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _chaeonHopOffset.value + chaeonSpriteVerticalOffsetPx,
                    ),
                    child: Transform.flip(
                      flipX: !_isChaeonFacingRight,
                      // 릴리안(_resolveLillianSprite)과 달리 예전엔 표정(expression)일 때만
                      // PopInImage, 아니면 Image.asset으로 위젯 타입 자체가 바뀌었음. 위젯
                      // 타입이 바뀌면 Flutter가 이전 PopInImage를 버리고 새로 만들어서,
                      // 표정으로 처음 들어가는 순간 크로스페이드 없이 뚝 튀어 나타나는 문제가
                      // 있었음(kitchen_screen.dart의 채온이 스프라이트에서 고친 것과 동일한
                      // 문제). 이제 항상 PopInImage 하나로 그리고, duration으로 표정
                      // 전환(페이드)과 걷기/idle 전환(즉시)을 구분함
                      child: PopInImage(
                        imagePath: chaeonSpriteAsset,
                        width: chaeonDisplaySize,
                        height: chaeonDisplaySize,
                        fit: BoxFit.contain,
                        // 120ms는 팔을 내린/올린 자세처럼 포즈 차이가 큰 표정 사이에서
                        // 크로스페이드가 눈에 띄게 느적거려 보여서 50ms로 줄임
                        duration: isChaeonSpriteExpression
                            ? const Duration(milliseconds: 50)
                            : Duration.zero,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  key: const ValueKey('chaeon'),
                  left: renderChaeonX,
                  bottom: rH(
                    _chaeonWalkFloorBottomOffset,
                  ), // 튜토리얼 채온이와 동일한 바닥선 기준
                  child: Transform.translate(
                    // 스프라이트별 세로 위치 보정값(chaeonSpriteVerticalOffsetPx)만큼 더해줌
                    offset: Offset(
                      0,
                      _chaeonHopOffset.value + chaeonSpriteVerticalOffsetPx,
                    ),
                    child: Transform.flip(
                      flipX: !_isChaeonFacingRight,
                      // 릴리안(_resolveLillianSprite)과 달리 예전엔 표정(expression)일 때만
                      // PopInImage, 아니면 Image.asset으로 위젯 타입 자체가 바뀌었음. 위젯
                      // 타입이 바뀌면 Flutter가 이전 PopInImage를 버리고 새로 만들어서,
                      // 표정으로 처음 들어가는 순간 크로스페이드 없이 뚝 튀어 나타나는 문제가
                      // 있었음(kitchen_screen.dart의 채온이 스프라이트에서 고친 것과 동일한
                      // 문제). 이제 항상 PopInImage 하나로 그리고, duration으로 표정
                      // 전환(페이드)과 걷기/idle 전환(즉시)을 구분함
                      child: PopInImage(
                        imagePath: chaeonSpriteAsset,
                        width: chaeonDisplaySize,
                        height: chaeonDisplaySize,
                        fit: BoxFit.contain,
                        // 120ms는 팔을 내린/올린 자세처럼 포즈 차이가 큰 표정 사이에서
                        // 크로스페이드가 눈에 띄게 느적거려 보여서 50ms로 줄임
                        duration: isChaeonSpriteExpression
                            ? const Duration(milliseconds: 50)
                            : Duration.zero,
                      ),
                    ),
                  ),
                ),

            // 3층: 릴리안 GIF (먹는 클로즈업 중에는 페이드 없이 즉시 숨김)
            if (_isLillianVisible && !isEatingCloseupActive)
              Builder(
                builder: (context) {
                  // 세번째 값(isExpression)은 이제 PopInImage/Image.asset 분기 기준으로
                  // 안 쓰고 shouldApplyLillianFacingFlip(walk 여부)만 보므로 버림
                  final (
                    String lillianSpriteAsset,
                    bool shouldApplyLillianFacingFlip,
                    bool _,
                  ) = _resolveLillianSprite(
                    sceneNodeId,
                  );
                  return Positioned(
                    key: const ValueKey('lillian'),
                    left: renderLillianX,
                    top: lillianTopValue, // 튜토리얼 채온이와 동일한 바닥선 기준
                    height: lillianDisplaySize,
                    child: Transform.translate(
                      offset: Offset(0, _lillianHopOffset.value),
                      child: Transform.flip(
                        flipX:
                            shouldApplyLillianFacingFlip &&
                            _isLillianFacingLeft,
                        // "항상 PopInImage + duration: Duration.zero" 시도는 실제로
                        // 반전 버그가 재발해서 되돌림: PopInImage는 전환 시작 순간
                        // _previousPath(이전 이미지)를 최소 1프레임 붙들고 있는데, 그
                        // 프레임에서 바깥쪽 Transform.flip은 이미 새 상태(반전 안 함)로
                        // 넘어가 있어서, duration이 0이어도 "이전 프레임이 새 반전 상태를
                        // 물려받는" 순간 자체는 피할 수 없었음. 그래서 walk<->idle 전환은
                        // 다시 Image.asset으로 즉시 스왑(크로스페이드 위젯 자체를 안 씀)하고,
                        // 실제 표정 변화에만 PopInImage 크로스페이드를 적용함
                        //
                        // 근데 위 분기를 isLillianSpriteExpression 기준으로 나누면, 대사 중
                        // expression 없는 노드(idle로 폴백)랑 있는 노드가 번갈아 나올 때마다
                        // idle(Image.asset) <-> 표정(PopInImage) 사이에서 위젯 타입 자체가
                        // 계속 바뀌게 됨. 표정으로 들어갈 때마다 PopInImage가 매번 새로
                        // 만들어지니까 크로스페이드 없이 뚝 튀어 나타나 보였던 거였음(챕터1
                        // 릴리안 표정 전환 번쩍임의 실제 원인). idle이랑 walk는 flip 여부가
                        // 갈리는 유일한 지점(shouldApplyLillianFacingFlip이 true인 건 walk뿐)이라
                        // 위 반전 버그 우려는 walk 쪽만 Image.asset으로 분리해두면 그대로
                        // 피할 수 있어서, 분기 기준을 walk 여부(!shouldApplyLillianFacingFlip)로
                        // 바꿔서 idle<->표정 사이는 하나의 PopInImage로 계속 유지되게 함
                        child: !shouldApplyLillianFacingFlip
                            ? PopInImage(
                                imagePath: lillianSpriteAsset,
                                width: lillianDisplaySize,
                                height: lillianDisplaySize,
                                fit: BoxFit.contain,
                              )
                            : Image.asset(
                                lillianSpriteAsset,
                                width: lillianDisplaySize,
                                height: lillianDisplaySize,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  );
                },
              ),

            // 3-2층: 빵 접시. table.json 대사가 시작되는 시점부터 테이블 상판 위에 표시.
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김. 빵을 다 먹은 뒤로는 계속 숨김
            if (_dialoguePhase == DialoguePhase.table &&
                !isEatingCloseupActive &&
                !_hasEatenBread)
              Positioned(
                key: const ValueKey('bread_plate'),
                left: renderBreadPlateX,
                bottom: rH(140), // 빵 위치
                child: Image.asset(
                  'assets/images/bread_plate.png',
                  width: breadPlateDisplaySize,
                  fit: BoxFit.contain,
                ),
              ),

            // 4층: 온도계 (먹는 클로즈업 중에는 페이드 없이 즉시 숨김)
            // skipChapter1Events(챕터3 재진입) 모드는 x=650 가이드 대사를 거치지 않아
            // _isGuidePhaseStarted가 계속 false로 남으므로 dpad와 동일하게 별도 분기
            if ((widget.skipChapter1Events || _isGuidePhaseStarted) &&
                !(_isDialogueActive && _dialogueStep == 0) &&
                !isEatingCloseupActive)
              widgets.buildThermometer(
                key: 'thermometer_below',
                rW: rW,
                rH: rH,
                temperature: _sceneController.temperature,
                temperatureChangeText: _sceneController.temperatureChangeText,
              ),

            // 4-3층: 뒤로가기 버튼 (가이드 대사 0번째 스텝 전용).
            // 7층 암전보다 아래라서 검은 반투명에 덮여 흐릿하게 보임
            if (_isDialogueActive && _dialogueStep == 0)
              widgets.buildBackButton(
                key: 'back_below_guide',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 4-4층: 설정 버튼 (가이드 대사 0/1 스텝 전용).
            // 7층 암전보다 아래라서 검은 반투명 배경에 덮여 흐릿하게 보임
            if (_isGuidePhaseStarted && _isDialogueActive)
              widgets.buildSettingButton(
                key: 'setting_dimmed',
                rW: rW,
                rH: rH,
                onTap: () => setState(() => _isSettingOpen = true),
              ),

            // 5층: 가상 패드 왼쪽 이동 버튼 영역
            if (!widget.isPrologue && showDpad)
              Positioned(
                // 디버그: dpad 재마운트 시 이전 눌림 상태가 이어지는지 테스트하려고 단계별로
                // 완전히 다른 키를 줘서 매번 새 위젯으로 취급되게 함. 원인 아니면 나중에 되돌릴 것
                key: ValueKey('dpad_left_$_dialoguePhase'),
                left: rW(_dpadLeftButtonLeft),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_left.png',
                  onTapDown: () {
                    _game.movePlayer(-1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = false;
                    });
                  },
                  onTapUp: () {
                    _game.movePlayer(0);
                    setState(() => _chaeonState = 'idle');
                  },
                  onTapCancel: () {
                    _game.movePlayer(0);
                    // 대화 트리거로 버튼이 같은 프레임에 사라지면 위젯 트리 잠긴 상태서 호출될 수 있어 다음 프레임으로 미룸
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _chaeonState = 'idle');
                    });
                  },
                  rW: rW,
                  rH: rH,
                  size: _dpadButtonSize,
                ),
              ),

            // 6층: 가상 패드 오른쪽 이동 버튼 영역
            if (!widget.isPrologue && showDpad)
              Positioned(
                // 디버그: dpad 재마운트 시 이전 눌림 상태가 이어지는지 테스트하려고 단계별로
                // 완전히 다른 키를 줘서 매번 새 위젯으로 취급되게 함. 원인 아니면 나중에 되돌릴 것
                key: ValueKey('dpad_right_$_dialoguePhase'),
                left: rW(_dpadRightButtonLeft),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_right.png',
                  onTapDown: () {
                    _game.movePlayer(1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = true;
                    });
                  },
                  onTapUp: () {
                    _game.movePlayer(0);
                    setState(() => _chaeonState = 'idle');
                  },
                  onTapCancel: () {
                    _game.movePlayer(0);
                    // 대화 트리거로 버튼이 같은 프레임에 사라지면 위젯 트리 잠긴 상태서 호출될 수 있어 다음 프레임으로 미룸
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _chaeonState = 'idle');
                    });
                  },
                  rW: rW,
                  rH: rH,
                  size: _dpadButtonSize,
                ),
              ),

            // 7층: 화면 어둡게 덮는 반투명 암전 레이어
            if (_isDialogueActive)
              Positioned.fill(
                key: const ValueKey('darken'),
                child: IgnorePointer(
                  ignoring: false,
                  child: GestureDetector(
                    onTap: _advanceDialogue,
                    child: Container(color: Colors.black.withOpacity(0.55)),
                  ),
                ),
              ),

            // 8층: 온도계
            if (_isDialogueActive && _dialogueStep == 0)
              widgets.buildThermometer(
                key: 'thermometer_above',
                rW: rW,
                rH: rH,
                temperature: _sceneController.temperature,
                temperatureChangeText: _sceneController.temperatureChangeText,
              ),

            // 8-2층: 뒤로가기 버튼
            // 아직 클릭 기능 없어서 탭하면 아래 암전 레이어가 받아서 대사 넘어감 (설정 버튼은 계속 4-2층에만 있음)
            if (_isDialogueActive && _dialogueStep != 0)
              widgets.buildBackButton(
                key: 'back_above',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 9층: x=650 지점 가이드 대사창
            if (_isDialogueActive && _dialogueTexts.isNotEmpty)
              widgets.buildCustomDialogue(
                key: 'dialogue_box',
                step: _dialogueStep,
                rW: rW,
                rH: rH,
              ),

            // 10층: 오브젝트 클릭 정보성 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 11층: 오브젝트 클릭 정보성 팝업 텍스트창
            if (_interactionText != null)
              widgets.buildInteractionBox(
                text: _interactionText!,
                rW: rW,
                rH: rH,
              ),

            // 12층: 채온-릴리안 첫 만남 말풍선 대화 (line 노드)
            // 먹는 클로즈업(isEatingCloseupActive) 중에는 탭으로 넘기지 못하게 막음.
            // EatingCloseupOverlay가 자체 타이머(onFinished)로만 다음 노드로 넘겨야 하는데,
            // 여기 탭 레이어가 겹쳐 있으면 애니메이션이 끝나기 전에 유저가 탭해서 먼저 넘어가버림
            if (currentSceneNode != null &&
                currentSceneNode.type == 'line' &&
                !isEatingCloseupActive)
              Positioned.fill(
                key: const ValueKey('scene_bubble_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sceneController.advanceScene,
                  child: Stack(
                    children: [
                      // 대사 텍스트 없는 노드(예: 먹는 클로즈업 사이 빈 노드)는 말풍선 없이
                      // 탭으로만 다음으로 넘어감
                      // bubbleRevealed가 false면 GIF 재생 중이라는 뜻이라 말풍선을 아직 안 그림
                      if (currentSceneNode.spans.isNotEmpty &&
                          _sceneController.bubbleRevealed)
                        widgets.buildSceneBubble(
                          node: currentSceneNode,
                          rW: rW,
                          rH: rH,
                          chaeonCenterX: bubbleChaeonCenterX,
                          lillianCenterX: bubbleLillianCenterX,
                          typedCharCount: _sceneController.typedCharCount,
                        ),
                    ],
                  ),
                ),
              ),

            // 13층: 채온-릴리안 첫 만남 선택지 (choice 노드)
            if (currentSceneNode != null && currentSceneNode.type == 'choice')
              Positioned.fill(
                key: const ValueKey('scene_choice_layer'),
                child: Stack(
                  children: [
                    if (lastLineNode != null)
                      widgets.buildSceneBubble(
                        node: lastLineNode,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: bubbleChaeonCenterX,
                        lillianCenterX: bubbleLillianCenterX,
                        typedCharCount: _sceneController.typedCharCount,
                        charCount: lastLineNode.spans.fold<int>(
                          0,
                          (sum, s) => sum + s.text.length,
                        ),
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

            // 14층: 뒤로가기 버튼 (가이드 대사/선택지 중엔 4-3층 흐릿한 버튼이 대신 나오므로 여기선 안 그림)
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김
            // skipChapter1Events(챕터3 재진입) 모드는 _isGuidePhaseStarted가 false로 남으므로 별도 분기
            if ((widget.skipChapter1Events || _isGuidePhaseStarted) &&
                !_isDialogueActive &&
                !isEatingCloseupActive)
              widgets.buildBackButton(
                key: 'back_below',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 15층: 선택지 되돌리기 불가 안내 배지. 선택지를 한 번이라도 골랐는데 히스토리가 비어서 더 못 돌아갈 때만 띄움
            if (_sceneController.choiceLockedMessage != null)
              Positioned(
                key: const ValueKey('choice_locked_badge'),
                left: rW(636),
                top: rH(74),
                child: widgets.buildBlackRoundedBadge(
                  _sceneController.choiceLockedMessage!,
                  rW: rW,
                  rH: rH,
                ),
              ),

            // 16층: 설정(옵션) 버튼. 15층 안내 배지보다 위에 있어야 배지가 버튼에 안 가려짐
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김
            // skipChapter1Events(챕터3 재진입) 모드는 _isGuidePhaseStarted가 false로 남으므로 별도 분기
            if ((widget.skipChapter1Events || _isGuidePhaseStarted) &&
                !_isDialogueActive &&
                !isEatingCloseupActive)
              widgets.buildSettingButton(
                key: 'setting',
                rW: rW,
                rH: rH,
                onTap: () => setState(() => _isSettingOpen = true),
              ),

            // 17층: 공용 메뉴 오버레이. 다른 화면들이랑 동일한 MenuOverlay 재사용
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

            // 17-1층: 저장 완료 안내 배지. kitchen_screen.dart 9-1층이랑 동일한 패턴
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

            // 18층: 회상 컷씬(구름 드래그 미니게임 + 놀이공원 연출). 최상단에서 화면을 전부 덮음
            if (_dialoguePhase == DialoguePhase.memoryFlashback)
              Positioned.fill(
                key: const ValueKey('memory_flashback'),
                child: MemoryFlashbackScene(
                  onTemperatureIncrease: () =>
                      _sceneController.applyTemperatureEffect(1),
                  onComplete: () {
                    setState(() => _dialoguePhase = DialoguePhase.firstBread);
                    _sceneController.loadDialogue(
                      'assets/lines/chapter1/first_bread.json',
                    );
                  },
                ),
              ),

            // 19층: 앞치마 착용은 풀스크린 컷씬 없이 2층 채온이 스프라이트
            // 전환(_resolveChaeonSprite)만으로 처리함. onDialogueEnd의 firstBread 분기 참고

            // 20층: table.json -> 회상 컷씬 전환용 검은 화면 페이드. 항상 최상단
            if (_showMemoryFadeOverlay)
              Positioned.fill(
                key: const ValueKey('memory_fade_overlay'),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _memoryFadeOpacity,
                    duration: _memoryFadeOpacity == 1.0
                        ? _memoryFadeInDuration
                        : _memoryFadeOutDuration,
                    child: Container(color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
