// lib/features/chapter1/bakery_game.dart

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:emotional_bakery/features/chapter1/chaeon.dart';
import 'package:emotional_bakery/features/chapter1/components/interactive_zone.dart';
import 'package:emotional_bakery/core/services/interaction_loader.dart';
import 'package:emotional_bakery/core/utils/image_warmup.dart'
    show kBakeryBgFlameImage;

// 챕터1 빵집에서 계단 근처에 도달했을 때, 주방으로 내려가는 연출 트리거 좌표
const double kitchenStairsTriggerX = 1680;

// 챕터3 재진입 모드(skipChapter1Events) 전용 트리거. 계단 가는 길목에 chapter3_door.json
// 대사 한 번 끼워넣는 지점. 임시값, 실제로는 이보다 좀 더 뒤쪽이어야 함 - 화면 보면서 조정 예정
const double kChapter3DoorTriggerX = 650;

// 챕터5 재진입 모드에서 채온이가 서있는 지점. 챕터1에서 채온이가 항상 멈춰서
// first_meet.json이 시작되던 지점(x=650, game_play_screen.dart의 _triggerLillianWalk
// 주석 "채온이는 항상 x=650에서 멈추므로" 참고)이랑 동일하게 맞춤. x=1305는
// onReachPostSceneEnd 트리거라 first_meet.json이 아니라 그 다음 장면(table.json) 지점이었음
const double kChapter5StartX = 650;
// 챕터5 재진입 모드에서 릴리안이 서있는 지점. game_play_screen.dart의 _lillianTargetX
// 기본값(900, 챕터1 첫 만남 때 릴리안이 멈추는 고정 좌표)이랑 동일하게 맞춤. 여기서도
// 알아야 카메라를 onLoad() 안에서 바로 정확한 위치로 맞출 수 있음(아래 참고)
const double kChapter5LillianX = 900;

// 어느 챕터로 재진입해서 빵집을 다시 쓰는 건지 구분하는 용도. skipChapter1Events는 챕터
// 상관없이 공통으로 켜지는 플래그인데, chapter3_door.json 트리거처럼 특정 챕터에서만 발동해야
// 하는 로직은 이 enum으로 따로 갈라줘야 함. 나중에 챕터5 이후로 재진입 지점이 더 생기면 여기에 추가
enum ReentryChapter { none, chapter3, chapter4, chapter5 }

class BakeryGame extends FlameGame {
  BakeryGame({
    this.skipChapter1Events = false,
    this.reentryChapter = ReentryChapter.none,
    this.resumeChaeonX,
    this.resumeLillianArrivalX,
    bool resumeSkipGuideTrigger = false,
    bool resumeSkipPostSceneEndTrigger = false,
  }) {
    // 챕터3 빵집 재진입 모드: 가이드 대사(x=650)/릴리안 등장(x=1305) 트리거를 처음부터
    // "이미 발동됨" 상태로 시작해서 무효화하고, 계단 트리거만 살아있게 함
    if (skipChapter1Events) {
      _hasTriggeredGuide = true;
      _hasTriggeredPostSceneEnd = true;
      isKitchenApproachActive = true;
    }
    // 저장/불러오기로 특정 지점부터 재개하는 경우, resumeChaeonX로 옮겨놓을 위치가 하필
    // 가이드/릴리안 등장 트리거 좌표랑 겹칠 수 있어서(예: 챕터1 table.json 재개 지점은
    // x=1305, 릴리안 등장 트리거랑 동일) 그대로 두면 update()가 "막 도달한 것"으로 착각해서
    // 가이드 대사나 계단 등장 애니메이션을 또 틔워버림. game_play_screen.dart가 이미 그
    // 상태를 지나온 걸로 치고 재개하는 거라, 필요한 경우에만 각 트리거를 미리 소모시켜달라고
    // 요청받음(skipChapter1Events 처리랑 동일한 방식)
    if (resumeSkipGuideTrigger) {
      _hasTriggeredGuide = true;
    }
    if (resumeSkipPostSceneEndTrigger) {
      _hasTriggeredPostSceneEnd = true;
    }
  }

  // true면 챕터3에서 빵집에 다시 들어온 경우. 챕터1 최초 플레이 흐름과 구분하는 용도
  final bool skipChapter1Events;
  // chapter3_door.json 트리거처럼 챕터별로 갈라야 하는 로직 전용. skipChapter1Events가 true여도
  // 이게 chapter3가 아니면(예: chapter4) chapter3 문 대사는 안 뜸
  final ReentryChapter reentryChapter;
  // 저장/불러오기 재개 전용. null이 아니면 onLoad()에서 chaeon을 이 x좌표로 옮기고 카메라도
  // 그 자리에 맞춰 스냅함(reentryChapter==chapter5가 이미 하는 것과 동일한 패턴). null이면
  // (기본값) 기존 스폰 위치 그대로라 정상 진행에 영향 없음
  final double? resumeChaeonX;
  // 재개 시점에 릴리안이 이미 등장해있어야 하면 같이 넘김(챕터1 첫 만남 이후 지점들).
  // null이면 릴리안 관련 카메라 중간점 계산 없이 chaeon만 따라감
  final double? resumeLillianArrivalX;

  Chaeon? chaeon;
  final double mapWidth = 1852; // 배경 이미지 가로 길이
  final double mapHeight = 402; // 배경 이미지 세로 길이

  bool isMovementBlocked = false;
  bool canInteract = true;
  bool _hasTriggeredGuide = false;
  bool _hasTriggeredPostSceneEnd = false;
  bool _hasTriggeredStairs = false;
  // skipChapter1Events 모드에서만 쓰는 chapter3_door.json 트리거용 1회성 플래그
  bool _hasTriggeredChapter3Door = false;
  // 챕터5 전용 1회성 플래그. 챕터3/4처럼 x좌표 트리거가 아니라 씬 로드 직후 바로 발동함
  bool _hasTriggeredChapter5Start = false;
  // game_play_screen에서 DialoguePhase.kitchenApproach가 됐을 때만 true로 켜줌.
  // 이 플래그가 켜지기 전까진 계단 트리거 체크 자체를 안 해서, chaeon 위치가 이전 단계에서
  // 어쩌다 계단 트리거 좌표를 넘겨버려도 _hasTriggeredStairs가 미리 소모되지 않게 막는 안전장치
  bool isKitchenApproachActive = false;
  // 채온이가 막 mount된 첫 프레임인지 추적. 안 하면 가만히 서있는 상태로 시작할 때
  // onGameUpdate가 한 번도 안 불려서 플러터 쪽 위치가 초기값(0)에 멈춰 안 보이게 됨
  bool _wasChaeonMounted = false;

  double? lillianArrivalX;

  // 릴리안 등장 이후 카메라가 목표 지점으로 이동하는 속도
  final double _cameraPanSpeed = 1.8;

  // 대사 종료처럼 카메라 포커스가 갑자기 바뀔 때, 순간이동하지 않고 부드럽게
  // 따라잡도록 트리거. 다 따라잡으면 자동으로 즉시 추적 모드로 복귀함
  bool _isCameraCatchingUp = false;
  void startCameraCatchUp() {
    _isCameraCatchingUp = true;
  }

  // 현재 focusX(채온 위치, lillianArrivalX 있으면 채온-릴리안 중간점)에 카메라를 렌더링
  // 지연(lerp) 없이 바로 스냅시키도록 다음 update() 틱에 요청함. onLoad() 시점엔
  // size(게임 화면 크기)가 아직 0일 수 있어서 그 안에서 직접 카메라 위치를 계산하면
  // 위험함(실제로 이것 때문에 맵 자체가 안 보이는 버그가 났었음). update()는 매 프레임
  // size가 유효할 때만 계산하는 게 이미 보장돼있어서 그쪽에서 처리하는 게 안전함
  bool _pendingCameraSnap = false;
  void requestCameraSnap() {
    _pendingCameraSnap = true;
  }

  // 플러터 UI 레이어와 연동하기 위한 콜백 함수 포인터들
  Function(List<String>)? onShowDialogue;
  Function()? onGameUpdate;
  Function()? onReachLeftEdge; // 왼쪽 끝에서 계속 왼쪽으로 이동 시 프롤로그로 전환
  Function(String)? onInteract; // 배경 오브젝트 클릭 시 팝업 표시
  Function()? onReachPostSceneEnd; // 첫 만남 대사 후 채온이가 1200 지점 도착 시
  Function()? onReachStairs; // 계단 근처 도달 시 (주방으로 내려가는 연출 트리거)
  Function()?
  onReachChapter3Door; // skipChapter1Events 모드에서 chapter3_door.json 트리거 지점 도달 시
  Function()?
  onReachChapter5Start; // 챕터5 재진입 모드에서 씬 로드 직후 곧바로(x좌표 무관) 발동

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 배경 레이어
    final bgSprite = await loadSprite(kBakeryBgFlameImage);
    final background = SpriteComponent(
      sprite: bgSprite,
      size: Vector2(mapWidth, mapHeight),
    );
    world.add(background);

    // 배경 위 클릭 가능한 오브젝트 히트박스 배치
    final stageObjects = await InteractionLoader.loadStageObjects(
      'bakery_bg_main.png',
    );
    for (final objectData in stageObjects) {
      world.add(InteractiveZone(objectData: objectData));
    }

    /* // 사용 안함
    lillian = Lillian();
    lillian.position = Vector2(1200, 320);
    world.add(lillian);
    */

    // 채온 레이어. await 필수: Chaeon 자신의 onLoad()가 position을 (10, 350)으로 다시
    // 세팅하는데, 여기서 await 안 하면 그 초기화가 끝나기 전에 아래 챕터5 위치 조정
    // 코드가 먼저 실행돼서 나중에 Chaeon.onLoad()가 그 값을 덮어써버림
    chaeon = Chaeon(mapWidth: mapWidth);
    await world.add(chaeon!);

    // 카메라 초기 위치를 맵 왼쪽 끝으로 설정
    camera.viewfinder.anchor = Anchor.centerLeft;
    camera.viewfinder.position = Vector2(0, mapHeight / 2);

    // 챕터5는 골목길 없이 씬 로드되자마자 바로 chapter5_start.json이 재생돼야 해서,
    // 다른 재진입 챕터처럼 x좌표 트리거를 기다리지 않고 여기서 바로 발동함
    if (reentryChapter == ReentryChapter.chapter5 &&
        !_hasTriggeredChapter5Start) {
      _hasTriggeredChapter5Start = true;
      // 채온이를 챕터1 첫 만남 지점(kChapter5StartX)에 세워둠. 릴리안도 이 위치 기준으로
      // 세워야 해서(kChapter5LillianX) 왼쪽 끝 스폰 대신 여기로 옮김
      chaeon?.position.x = kChapter5StartX;
      lillianArrivalX = kChapter5LillianX;
      // 카메라는 위에서 일단 맵 왼쪽 끝으로 세팅했는데, requestCameraSnap으로 다음
      // update() 틱에 바로 정확한 위치로 스냅되게 요청함(그 프레임까지만 왼쪽 끝이
      // 잠깐 그려짐 - onLoad() 안에서 직접 스냅하면 size가 아직 0이라 위험함)
      requestCameraSnap();
      isMovementBlocked = true;
      movePlayer(0);
      onReachChapter5Start?.call();
    }

    // 저장/불러오기 재개 지점. resumeChaeonX가 있으면 chaeon을 그 자리로 옮기고 카메라도
    // 바로 스냅시킴 - 위 챕터5 블록이랑 동일한 이유(size가 0인 onLoad() 안에서 직접 카메라
    // 계산하면 위험해서 requestCameraSnap으로 다음 update() 틱에 미룸). 여기서 chaeon.x를
    // 옮기면 update()의 위치 기반 트리거(가이드/postSceneEnd)가 "막 도달한 것"으로 다시
    // 착각할 수 있는데, 그건 game_play_screen.dart가 resumeSkipGuideTrigger/
    // resumeSkipPostSceneEndTrigger로 미리 소모시켜서 넘어오는 걸 전제로 함
    if (resumeChaeonX != null) {
      chaeon?.position.x = resumeChaeonX!;
      if (resumeLillianArrivalX != null) {
        lillianArrivalX = resumeLillianArrivalX;
      }
      requestCameraSnap();
      isMovementBlocked = true;
      movePlayer(0);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 카메라 줌을 맵 세로 길이에 맞춰서 화면에 꽉 차게 조정
    if (size.y > 0) {
      camera.viewfinder.zoom = size.y / mapHeight;
    }

    // 카메라가 채온이를 따라가도록 위치를 업데이트
    bool positionChangedThisFrame = false;

    if (chaeon != null && chaeon!.isMounted) {
      // 화면에 실제로 보이는 가로 폭
      double visibleWidth = size.x / camera.viewfinder.zoom;
      // 뷰포트가 맵보다 넓은 극단적인 비율이어도 clamp 범위가 뒤집히지 않도록 방어
      double maxLeftEdge = (mapWidth - visibleWidth).clamp(0.0, mapWidth);

      // 카메라가 따라갈 초점 좌표를 계산
      double focusX = lillianArrivalX != null
          ? (chaeon!.position.x + lillianArrivalX!) / 2
          : chaeon!.position.x;

      // 초점이 화면 중앙을 따라며, 카메라 범위 제한
      double targetLeftEdge = (focusX - visibleWidth / 2).clamp(
        0.0,
        maxLeftEdge,
      );

      double newLeftEdge;
      if (_pendingCameraSnap) {
        // requestCameraSnap()으로 요청된 즉시 스냅. size가 이제는 확실히 유효한
        // update() 안이라 안전하게 계산 가능함
        newLeftEdge = targetLeftEdge;
        _pendingCameraSnap = false;
      } else if (lillianArrivalX != null || _isCameraCatchingUp) {
        // 릴리안 등장 중이거나, 포커스가 갑자기 바뀌어 따라잡는 중이면 서서히 이동
        double currentLeftEdge = camera.viewfinder.position.x;
        double t = (_cameraPanSpeed * dt).clamp(0.0, 1.0);
        newLeftEdge = currentLeftEdge + (targetLeftEdge - currentLeftEdge) * t;
        // 카메라가 목표 지점에 도달하면, 추적 모드로 복귀
        if (_isCameraCatchingUp && (targetLeftEdge - newLeftEdge).abs() < 1.0) {
          _isCameraCatchingUp = false;
        }
      } else {
        // 평소 채온이 추적은 카메라 지연 없이 따라가기
        newLeftEdge = targetLeftEdge;
      }

      double previousLeftEdge = camera.viewfinder.position.x;

      // 카메라 위치 업데이트
      camera.viewfinder.position = Vector2(
        newLeftEdge,
        camera.viewfinder.position.y,
      );

      positionChangedThisFrame =
          !_wasChaeonMounted ||
          chaeon!.moveDirection != 0 ||
          (newLeftEdge - previousLeftEdge).abs() > 0.01;
      _wasChaeonMounted = true;
    } else {
      _wasChaeonMounted = false;
    }

    // 채온이가 계속 왼쪽으로 이동을 시도하면 프롤로그로 전환
    if (chaeon != null &&
        chaeon!.isMounted &&
        chaeon!.moveDirection < 0 &&
        chaeon!.position.x <= chaeon!.size.x / 2) {
      onReachLeftEdge?.call();
    }

    if (chaeon != null &&
        !_hasTriggeredGuide &&
        chaeon!.isMounted &&
        chaeon!.position.x >= 650) {
      _hasTriggeredGuide = true; // 스위치 ON

      // 대사 띄우는 중에는 조작 잠금
      isMovementBlocked = true;
      movePlayer(0);

      showDialogue([
        "지금부터 감정의 온도를 확인할 수 있습니다.\n당신의 선택에 따라 감정의 온도는 오를수도, 내려갈 수도 있습니다.",
        "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 선택은 돌릴 수 없습니다.",
      ]);

      print("x=650 지점 도달");
    }

    // skipChapter1Events 모드 전용: 계단 가는 길목에서 chapter3_door.json 대사 한 번 트리거.
    // 일반 챕터1 최초 플레이 경로(skipChapter1Events=false)에서는 절대 발동 안 함
    // reentryChapter가 chapter3일 때만 발동. 챕터4 재진입(reentryChapter.chapter4)에서는
    // chapter3 문 대사가 튀어나오면 안 되니까 여기서 걸러줌
    if (skipChapter1Events &&
        reentryChapter == ReentryChapter.chapter3 &&
        chaeon != null &&
        !_hasTriggeredChapter3Door &&
        chaeon!.isMounted &&
        chaeon!.position.x >= kChapter3DoorTriggerX) {
      _hasTriggeredChapter3Door = true;
      isMovementBlocked = true;
      movePlayer(0);
      onReachChapter3Door?.call();
      print("chapter3 door 트리거 도달: x=${chaeon!.position.x}");
    }

    // 첫 만남 대사 이후 다시 걸을 수 있게 된 구간에서, 채온이가 1200 지점에 도착하면
    // 방향키를 다시 숨기고 조작을 잠금 (나중에 해야함)
    if (chaeon != null &&
        !_hasTriggeredPostSceneEnd &&
        chaeon!.isMounted &&
        chaeon!.position.x >= 1305) {
      _hasTriggeredPostSceneEnd = true;
      isMovementBlocked = true;
      movePlayer(0);
      onReachPostSceneEnd?.call();
      print("x=1300 지점 도달");
      // 디버그: 이 시점 chaeon 실제 x랑 계단 트리거까지 남은 거리 확인용
      print(
        "postSceneEnd 도달 시 chaeon.x=${chaeon!.position.x}, "
        "계단 트리거(kitchenStairsTriggerX=$kitchenStairsTriggerX)까지 남은 거리="
        "${kitchenStairsTriggerX - chaeon!.position.x}",
      );
    }

    // 앞치마 갈아입고 다시 걸을 수 있게 된 구간에서, 채온이가 계단 근처에 도착하면
    // 조작을 잠금. 실제로 주방 전환까지 이어질지는 game_play_screen에서 대사 단계 보고 판단함.
    // isKitchenApproachActive가 켜지기 전까진 이 체크 자체를 안 하게 막아서, chaeon 위치가
    // 어쩌다 이전 단계에서 이 좌표를 넘겨버려도 _hasTriggeredStairs가 미리 소모되지 않게 함
    if (isKitchenApproachActive &&
        chaeon != null &&
        !_hasTriggeredStairs &&
        chaeon!.isMounted &&
        chaeon!.position.x >= kitchenStairsTriggerX) {
      _hasTriggeredStairs = true;
      isMovementBlocked = true;
      movePlayer(0);
      onReachStairs?.call();
      // 디버그: 계단 트리거가 실제로 발동한 시점의 chaeon x좌표 확인용
      print(
        "계단 트리거 발동: chaeon.x=${chaeon!.position.x}, "
        "kitchenStairsTriggerX=$kitchenStairsTriggerX",
      );
    }

    if (positionChangedThisFrame) {
      onGameUpdate?.call();
    }
  }

  // 외부 위젯에서 플레이어 방향 제어용 함수
  void movePlayer(int direction) {
    // 디버그: 방향키 없이 자동으로 걷는 버그 추적용. 호출될 때마다 direction이랑 호출 스택을 같이 찍음
    print('movePlayer($direction) 호출됨\n${StackTrace.current}');
    if (isMovementBlocked) {
      chaeon?.moveDirection = 0;
      return;
    }
    chaeon?.moveDirection = direction;
  }

  // 전역 대화창 제어 함수
  void showDialogue(List<String> textLines) {
    onShowDialogue?.call(textLines);
  }

  // 주방에서 다시 계단을 올라와 빵집으로 돌아왔을 때, 계단 트리거를 다시 쓸 수 있게 리셋
  void resetStairsTrigger() {
    _hasTriggeredStairs = false;
  }
}
