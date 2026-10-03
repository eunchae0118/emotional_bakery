// lib/features/prologue/tutorial_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 연속 이동 (화살표 꾹 누르기)
import '../chapter1/game_play_screen.dart';
import 'package:emotional_bakery/core/services/app_exit.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/utils/image_warmup.dart';
import 'package:emotional_bakery/core/widgets/menu_overlay.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart'
    show ReentryChapter;
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/menu/choice_screen.dart';

// 마을 상호작용 구역 하나 (1~4번 집, 빵집 문)
class _HouseZone {
  final double left;
  final double top;
  final double width;
  final double height;
  final String? dialogue;
  final bool isDestination;

  const _HouseZone({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.dialogue,
    this.isDestination = false,
  });
}

const List<_HouseZone> _houseZones = [
  _HouseZone(
    left: 0,
    top: 0,
    width: 110,
    height: 295,
    dialogue: "클로에의 집이다.\n지금은 아무도 없는 거 같다.",
  ),
  _HouseZone(
    left: 120,
    top: 0,
    width: 198,
    height: 295,
    dialogue: "피터의 집이다.\n예전에 한 번 들어가 본 적이 있다.",
  ),
  _HouseZone(
    left: 325,
    top: 0,
    width: 281,
    height: 295,
    dialogue: "소피아의 집이다.\n소피아는 나에게 항상 친절하다.",
  ),
  _HouseZone(
    left: 615,
    top: 0,
    width: 279,
    height: 295,
    dialogue: "알렉스 씨의 집이다.\n들어가면 혼날 거 같다.",
  ),
  _HouseZone(
    left: 903,
    top: 0,
    width: 195,
    height: 295,
    dialogue: "간 씨의 집이다.\n들어가면 혼날 거 같다.",
  ),
  _HouseZone(
    left: 1107,
    top: 0,
    width: 280,
    height: 295,
    dialogue: "오 씨의 집이다.\n들어가면 혼날 거 같다.",
  ),
  _HouseZone(
    left: 1407,
    top: 183,
    width: 49,
    height: 114,
    dialogue: "잘 키운 식물이다.\n가까이 가면 풀 냄새가 난다.",
  ),
  _HouseZone(
    left: 1758,
    top: 226,
    width: 62,
    height: 71,
    dialogue: "카페 메뉴판이다.\n오늘의 추천 빵은 크루와상이다.",
  ),
  _HouseZone(
    left: 1842,
    top: 0,
    width: 113,
    height: 556,
    dialogue: "이곳에는 누가 사는거지?",
  ),
  // 우측 목적지 (빛나는 빵집 건물), 메인 거리 끝자락
  _HouseZone(left: 1456, top: 0, width: 302, height: 295, isDestination: true),
];

// 가상 패드(dpad) 버튼 한 변 크기. 원래 DpadButton 기본값(64)이었는데, 모바일에서 누르기
// 너무 작다는 피드백이 있어서 game_play_screen.dart/chaeon_room_screen.dart/
// kitchen_screen.dart랑 동일하게 1.5배로 키움 - 화면 보면서 추가 조정 가능
const double _dpadButtonSize = 96;
// dpad 왼쪽 버튼 left 위치. 버튼이 커진 만큼 원래 값(686)대로 두면 오른쪽 버튼(원래 778)이랑
// 겹치게 돼서, 오른쪽 버튼의 원래 오른쪽 끝(778+64=842, 화면 폭 874 기준 여백 32)과 원래
// 버튼 사이 간격(778-750=28)을 그대로 유지한 채 왼쪽으로 다시 계산함(842-96-28-96=622)
const double _dpadLeftButtonLeft = 622;
// dpad 오른쪽 버튼 left 위치. 오른쪽 끝(746+96=842)이 원래 버튼의 오른쪽 끝이랑 같아서
// 화면 오른쪽 여백(874-842=32)도 원래와 동일하게 유지됨
const double _dpadRightButtonLeft = 746;

// "저장되었습니다" 배지가 뜨는 top 위치(874x402 기준, rH로 스케일됨). kitchen_screen.dart랑
// 동일한 값을 씀 - 화면 보면서 조정 예정
const double _saveConfirmationBadgeTopRef = 80;

class TutorialScreen extends StatefulWidget {
  // 튜토리얼 안내 문구(0, 1단계)를 건너뛰고 바로 마을 배경만 보여주고 싶을 때 2로 전달
  final int initialStep;
  // 채온이가 등장할 마을 좌표
  final double initialPlayerX;
  // 등장 시 채온이가 왼쪽을 보도록 반전할지 여부 (빵집에서 나올 때 true)
  final bool initialFacingLeft;
  // true면 챕터1 GamePlayScreen에서 빵집 왼쪽 끝을 넘어와서 진입한 경우라는 뜻.
  // 이땐 빵집 문으로 다시 들어갈 때 새 GamePlayScreen을 만들지 않고 pop해서, 아래 깔려있는
  // 기존 GamePlayScreen(진행 중이던 대사/이동 상태 그대로 보존)으로 돌아감
  final bool returnToExistingGame;
  // none이 아니면 챕터3/4 채온이 방에서 나와 골목길을 거쳐 온 경우라는 뜻. 이땐 빵집 문으로
  // 들어갈 때 GamePlayScreen을 skipChapter1Events 모드로 켜서 push함
  // (챕터1 이벤트 다 건너뛰고 계단으로 직행). 원래는 chapter3Reentry라는 bool이었는데,
  // 챕터4 재진입도 같은 흐름을 타면서 "어느 챕터로 돌아온 건지"까지 구분해야 해서
  // ReentryChapter enum으로 바꿈 (chapter3_door.json 트리거가 챕터4에서 안 새어나가게 하려고)
  final ReentryChapter reentryChapter;
  // 챕터3/4 재진입 시 방/이전 화면에서 이어받아 온도계에 표시할 시작 온도.
  // reentryChapter가 none이 아닐 때만 온도계 자체가 노출되므로 그 외에는 쓰이지 않음
  final int initialTemperature;
  const TutorialScreen({
    super.key,
    this.initialStep = 0,
    this.initialPlayerX = 445,
    this.initialFacingLeft = false,
    this.returnToExistingGame = false,
    this.reentryChapter = ReentryChapter.none,
    this.initialTemperature = 3,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late int _tutorialStep = widget.initialStep;

  final double _mapWidth = 1955;
  double _playerX = 150; // 캐릭터 시작 위치 (뒷골목 구역)
  bool _isPlayerInitialized = false;
  String? _interactionText;

  // 연속 이동 타이머 및 캐릭터 상태 관리 변수
  Timer? _moveTimer;
  String _currentAction = 'idle';
  late bool _isLookingLeft = widget.initialFacingLeft; // 왼쪽인지 확인 여부
  bool _isSettingOpen = false;
  // 메뉴 "저장" 버튼 누르면 잠깐 뜨는 확인 문구. kitchen_screen.dart랑 동일한 패턴. null이면 안 보임
  String? _saveConfirmationText;
  Timer? _saveConfirmationTimer;

  // didChangeDependencies가 여러 번 불려도 워밍업이 중복으로 안 걸리게 막는 용도
  bool _hasStartedBgWarmUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedBgWarmUp) return;
    _hasStartedBgWarmUp = true;
    // 4000x1352 골목길 배경. 이전 화면에서 미리 걸어뒀으면 캐시돼 있어서 바로 끝나고, 아니면
    // (어느 경로로 들어왔든) fadeThroughBlackRoute 암전 구간 동안 디코딩 + GPU 업로드를 끝냄
    precacheAndWarmUpAsset(kTutorialBgAsset, context);
    // 빵집 문으로 들어가면 바로 GamePlayScreen(Flame 빵집 배경)이라 다음 화면 것도 미리 데워둠
    loadAndWarmUpFlameImage(kBakeryBgFlameImage);
  }

  @override
  void dispose() {
    _saveConfirmationTimer?.cancel();
    super.dispose();
  }

  // 메뉴 "저장" 버튼(MenuOverlay.onSave)이 부름. 골목길은 항상 챕터3/4/5 재진입 상태로만
  // 진입하니까(reentryChapter==none이면 애초에 설정 버튼 자체가 안 뜸 - 아래 온도계/설정 버튼
  // 노출 조건 참고), reentryChapter를 보고 그 챕터의 "채온이 방 진입" 체크포인트로 바로 저장함.
  // kitchen_screen.dart/chaeon_room_screen.dart처럼 지금 대사 진행 단계를 세세하게 추적하는
  // 로직이 이 화면엔 없어서, 골목길에서 저장하면 항상 그 챕터의 시작 지점으로 복원됨
  void _handleSave() async {
    final SaveCheckpoint? checkpoint = switch (widget.reentryChapter) {
      ReentryChapter.chapter3 => SaveCheckpoint.chapter3ChaeonRoom,
      ReentryChapter.chapter4 => SaveCheckpoint.chapter4StartRoom,
      ReentryChapter.chapter5 => SaveCheckpoint.chapter5Start,
      // 방어적 분기 - 실제로는 설정 버튼 자체가 안 떠서 여기까지 못 옴
      ReentryChapter.none => null,
    };
    if (checkpoint == null) return;
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

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    // UI 크롬(버튼, 대사창 등 화면에 고정되는 요소)에만 쓰는 스케일 함수
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;
    // 월드 요소는 세로 기준 하나로만 스케일 (챕터1 zoom 방식과 동일, rH랑 계산은 같은데 용도 구분용으로 분리)
    double zoom = h / 402;
    double zW(double worldPx) => worldPx * zoom;

    if (!_isPlayerInitialized) {
      _playerX = zW(widget.initialPlayerX);
      _isPlayerInitialized = true;
    }

    // 캐릭터가 화면 중심을 넘어설 때 배경을 반대 방향으로 밀어주는 카메라 오프셋 계산
    double screenWidth = w;
    double cameraX = (_playerX - zW(80)).clamp(
      0.0,
      zW(_mapWidth) - screenWidth,
    );

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_tutorialStep < 2) {
            setState(() {
              _tutorialStep++;
            });
          } else if (_interactionText != null) {
            setState(() {
              _interactionText = null;
            });
          }
        },
        child: Container(
          width: w,
          height: h,
          color: Colors.black,
          child: Stack(
            children: [
              // 1층: 카메라 오프셋의 영향을 받는 인게임 월드 레이어 (배경, 오브젝트, 캐릭터)
              Positioned(
                left: -cameraX,
                top: 0,
                width: zW(_mapWidth),
                height: h,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: zW(_mapWidth),
                      height: rH(661),
                      child: Image.asset(
                        kTutorialBgAsset,
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 마을 상호작용 구역들 (1~4번 집 + 빵집 문)
                    for (final zone in _houseZones)
                      _buildHouseZone(zone, zW: zW, rH: rH),

                    // 주인공 캐릭터 (채온) 레이어
                    Positioned(
                      left: _playerX,
                      bottom: rH(50),
                      child: Transform.flip(
                        flipX: _isLookingLeft, // true일 때 이미지 반전
                        child: Image.asset(
                          // 오른쪽 에셋 2개만 가지고 walk와 idle을 스위칭함.
                          // 챕터3 재진입일 때는 20% 상태 에셋, 챕터4 재진입일 때는 50% 상태
                          // 에셋을 씀
                          widget.reentryChapter == ReentryChapter.chapter4
                              ? (_currentAction == 'walk'
                                    ? 'assets/images/chaeon_50_normal_walk.gif'
                                    : 'assets/images/chaeon_50_normal.gif')
                              : widget.reentryChapter != ReentryChapter.none
                              ? (_currentAction == 'walk'
                                    ? 'assets/images/chaeon_20_normal_walk.gif'
                                    : 'assets/images/chaeon_20_normal.gif')
                              : (_currentAction == 'walk'
                                    ? 'assets/images/chaeon_walk_right.gif'
                                    : 'assets/images/chaeon_idle_right.gif'),
                          // 챕터1의 채온이(172 * zoom, zoom = h/402)와 동일한 크기 공식
                          width: zW(172),
                          height: rH(172),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 1-1층: 온도계/뒤로가기/설정 버튼. 챕터3/4 재진입(reentryChapter != none)일 때만 노출.
              // 원래 프롤로그 튜토리얼(첫 플레이)에서는 온도/대사 진행 상태 자체가 없어서 의미가 없음
              if (widget.reentryChapter != ReentryChapter.none) ...[
                widgets.buildThermometer(
                  key: 'tutorial_thermometer',
                  rW: rW,
                  rH: rH,
                  temperature: widget.initialTemperature,
                  temperatureChangeText: null,
                ),
                widgets.buildBackButton(
                  key: 'tutorial_back',
                  rW: rW,
                  rH: rH,
                  onTap: () => Navigator.pop(context),
                ),
                widgets.buildSettingButton(
                  key: 'tutorial_setting',
                  rW: rW,
                  rH: rH,
                  onTap: () => setState(() => _isSettingOpen = true),
                ),
              ],

              // 2층: 가상 패드 및 유동 대사창 UI 레이어
              Positioned(
                left: rW(_dpadLeftButtonLeft),
                bottom: rH(20),
                child: IgnorePointer(
                  ignoring: _tutorialStep < 2,
                  child: DpadButton(
                    imagePath: 'assets/images/btn_left.png',
                    onTapDown: () {
                      if (_interactionText != null) {
                        setState(() => _interactionText = null);
                        return;
                      }
                      if (_tutorialStep == 2) {
                        _moveTimer?.cancel();
                        setState(() {
                          _currentAction = 'walk';
                          _isLookingLeft = true;
                        });
                        _moveTimer = Timer.periodic(
                          const Duration(milliseconds: 40),
                          (timer) {
                            if (_playerX > zW(30)) {
                              setState(() {
                                // 225 unit/sec (챕터1 채온이 속도와 동일) * 40ms
                                _playerX -= zW(9);
                              });
                            } else {
                              // 골목 왼쪽 끝에 도달하면 더 못 간다는 대사 노출
                              timer.cancel();
                              setState(() {
                                _currentAction = 'idle';
                                _interactionText = "빵집은 이쪽 방향이 아니다.\n오른쪽으로 가자.";
                              });
                            }
                          },
                        );
                      }
                    },
                    onTapUp: () {
                      _moveTimer?.cancel();
                      if (_tutorialStep == 2) {
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = true;
                        });
                      }
                    },
                    rW: rW,
                    rH: rH,
                    size: _dpadButtonSize,
                  ),
                ),
              ),

              // 오른쪽 이동 버튼
              Positioned(
                left: rW(_dpadRightButtonLeft),
                bottom: rH(20),
                child: IgnorePointer(
                  ignoring: _tutorialStep < 2,
                  child: DpadButton(
                    imagePath: 'assets/images/btn_right.png',
                    onTapDown: () {
                      if (_interactionText != null) {
                        setState(() => _interactionText = null);
                        return;
                      }
                      if (_tutorialStep == 2) {
                        _moveTimer?.cancel();
                        setState(() {
                          _currentAction = 'walk';
                          _isLookingLeft = false;
                        });
                        _moveTimer = Timer.periodic(
                          const Duration(milliseconds: 40),
                          (timer) {
                            setState(() {
                              // 225 unit/sec (챕터1 채온이 속도와 동일) * 40ms
                              if (_playerX < zW(_mapWidth - 100)) {
                                _playerX += zW(9);
                              }
                            });
                          },
                        );
                      }
                    },
                    onTapUp: () {
                      _moveTimer?.cancel();
                      if (_tutorialStep == 2) {
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = false;
                        });
                      }
                    },
                    rW: rW,
                    rH: rH,
                    size: _dpadButtonSize,
                  ),
                ),
              ),

              // 가이드 대사(Step 0, 1)가 활성화되어 있을 때만 인게임 월드를 50% 어둡게 깔아주는 반투명 암전 레이어
              if (_tutorialStep < 2)
                Positioned.fill(
                  child: IgnorePointer(
                    // 암전 레이어가 터치 이벤트를 먹어버리지 않게 차단
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),

              // 메인 가이드 Box (Step 0, 1 시점 노출)
              if (_tutorialStep < 2)
                CenteredDialogueBox(
                  textWidget: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      children: _tutorialStep == 0
                          ? [
                              const TextSpan(
                                text: "화면을 클릭하면 다음 화면으로 넘어갑니다.\n물건이나 건물을 ",
                              ),
                              const TextSpan(
                                text: "클릭할 시, 정보를 얻을 수 있습니다.",
                                style: TextStyle(
                                  color: Color(0xFFFF7100),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ]
                          : [
                              const TextSpan(
                                text:
                                    "왼쪽 화살표를 클릭하면 캐릭터가 왼쪽으로,\n오른쪽 화살표를 클릭하면 오른쪽으로 움직입니다.",
                              ),
                            ],
                    ),
                    style: dialogueTextStyle(rW),
                  ),
                  rW: rW,
                  rH: rH,
                ),

              // 오브젝트 상호작용 임시 대사창 구역
              if (_interactionText != null)
                CenteredDialogueBox(
                  textWidget: Text(
                    _interactionText!,
                    textAlign: TextAlign.center,
                    style: dialogueTextStyle(rW),
                  ),
                  rW: rW,
                  rH: rH,
                ),

              // 공용 메뉴 오버레이. 다른 화면들이랑 동일한 MenuOverlay 재사용
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
                  onGoToMainScreen: () =>
                      Navigator.of(context).pushAndRemoveUntil(
                        fadeThroughBlackRoute(const ChoiceScreen()),
                        (route) => false,
                      ),
                  onExitGame: exitGame,
                ),

              // 저장 완료 안내 배지. _handleSave가 저장 끝내고 잠깐(2초) 띄웠다가 스스로 지움.
              // kitchen_screen.dart랑 동일한 위치/스타일
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
            ],
          ),
        ),
      ),
    );
  }

  // 마을 상호작용 구역 하나 렌더링. 대화창이 떠 있으면 어떤 클릭이든 그 대화창부터 닫음
  Widget _buildHouseZone(
    _HouseZone zone, {
    required double Function(double) zW,
    required double Function(double) rH,
  }) {
    return Positioned(
      left: zW(zone.left),
      top: rH(zone.top),
      width: zW(zone.width),
      height: rH(zone.height),
      child: IgnorePointer(
        ignoring: _tutorialStep < 2,
        child: GestureDetector(
          onTapDown: (_) {
            if (_interactionText != null) {
              setState(() => _interactionText = null);
            } else if (_tutorialStep == 2) {
              if (zone.isDestination) {
                // 빵집 문 근처에서만 다음 화면으로 넘어가도록 체크
                final bool isNearDoor =
                    _playerX >= zW(1380) && _playerX <= zW(1680);
                if (isNearDoor) {
                  if (widget.returnToExistingGame) {
                    // 챕터1 진행 중 빵집 왼쪽 끝으로 나왔다가 돌아온 경우: 새로
                    // GamePlayScreen을 만들지 않고 pop해서 기존 진행 상태로 복귀
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      fadeThroughBlackRoute(
                        GamePlayScreen(
                          skipChapter1Events:
                              widget.reentryChapter != ReentryChapter.none,
                          reentryChapter: widget.reentryChapter,
                          initialTemperature: widget.initialTemperature,
                        ),
                      ),
                    );
                  }
                } else {
                  setState(
                    () => _interactionText = "아직 빵집에 들어가기엔\n거리가 먼 거 같다.",
                  );
                }
              } else {
                setState(() => _interactionText = zone.dialogue);
              }
            }
          },
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}
