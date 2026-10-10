// lib/features/menu/choice_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/app_exit.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/save_resume.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/menu_overlay.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';
import 'package:emotional_bakery/features/menu/ending_gallery_screen.dart';

// ChoiceScreen으로 가는 라우트에 붙이는 표시. 챕터 종료 시 스택을 이 화면까지만 남기고 정리할 때
// (goToChapterSelectClearingStack) 이 이름으로 ChoiceScreen 라우트를 찾음. ChoiceScreen을
// push하는 곳은 전부 settings: kChoiceScreenRouteSettings를 넘겨야 함
const RouteSettings kChoiceScreenRouteSettings = RouteSettings(name: 'choice');

// main_bg.png 실제 픽셀 크기(3496x1968)를 디자인 단위(÷4)로 환산한 값. 이 화면 좌표 전체가
// 쓰는 디자인 캔버스는 874x402인데, 배경 그림 자체의 실제 비율은 874x492(1.776:1)라서 서로
// 다름 - 가로(874)는 정확히 맞아떨어지는데 세로가 492로 더 김. leftOnBg()에서 배경의
// BoxFit.cover 크롭을 흉내 낼 때는 402가 아니라 이 값(492)을 써야 실제 크롭 위치랑 맞음
const double kMainBgDesignWidth = 874;
const double kMainBgDesignHeight = 492;

// 챕터 종료 후 챕터 선택창으로 갈 때 씀. pushReplacement는 맨 위 화면 하나만 바꿔서, 그 아래
// push로 쌓인 이전 챕터 화면들(GamePlayScreen의 Flame 게임 루프 포함)이 dispose 안 되고 계속
// 살아있었음(전시처럼 하루 종일 켜두면 플레이할 때마다 누적됨). ChoiceScreen(메인 메뉴) 위에
// 쌓인 건 전부 제거하고 그 위에 ChapterSelectScreen을 올림. 혹시 스택에 ChoiceScreen이 없으면
// 맨 아래 라우트에서 멈춰서 스택이 완전히 비지는 않게 함
void goToChapterSelectClearingStack(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    fadeThroughBlackRoute(const ChapterSelectScreen()),
    (route) =>
        route.settings.name == kChoiceScreenRouteSettings.name || route.isFirst,
  );
}

class ChoiceScreen extends StatefulWidget {
  const ChoiceScreen({super.key});

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  // 현재 눌려있는 버튼의 인덱스 (0: 없음, 1: 시작, 2: 이어, 3: 설정)
  int _pressedIndex = 0;

  // 다른 화면들이랑 동일한 패턴(_isSettingOpen + MenuOverlay)
  bool _isSettingOpen = false;

  // "시작하기" 눌렀을 때, 진행 상황이 있는데 리셋해도 되는지 물어보는 확인창 노출 여부
  bool _showResetConfirm = false;

  // "이어하기" 눌렀는데 저장된 데이터가 없을 때 뜨는 안내창 노출 여부. 버튼 자체는 항상
  // 눌리게 두고(흐리게 비활성화 안 함), 탭한 시점에 SaveManager.hasSave()를 바로 확인해서
  // 없으면 이 안내창만 띄움
  bool _showNoSaveDataNotice = false;

  @override
  void initState() {
    super.initState();
    // 다른 화면에서 메인 메뉴로 돌아올 때도(뒤로가기로 기존 인스턴스에 popUntil로 돌아오는
    // 경우 제외 - 그땐 원래 main_theme이었어서 상관없음) 여기로 새로 push되면 항상 다시 불림.
    // 이미 main_theme이 재생 중이면 AudioService가 알아서 아무것도 안 함
    AudioService.playBgm(AudioIds.mainTheme);
  }

  // 로고 끝-버튼1, 버튼-버튼 사이 간격(디자인 단위). 전부 이 값 하나로 통일함 - 전에는
  // 로고 top이랑 버튼 블록 시작 top을 따로 잡고 기기별 추가 간격까지 얹었더니 로고-버튼1
  // 사이만 유독 크게 벌어지는 문제가 있었음. 화면 보면서 조정 예정
  static const double _itemGapRef = 14;

  // 로고 렌더 높이(디자인 단위). logo.png 원본이 928x696(세로/가로 = 696/928 = 0.75)이고
  // 로고를 width 167로 그리니까 height는 167*0.75
  static const double _logoHeightRef = 167 * 696 / 928;

  // 버튼 렌더 높이(디자인 단위). 버튼 이미지(start.png 등)가 576x144(세로/가로=0.25)고
  // Positioned width가 144로 고정돼서 height는 144*0.25=36
  static const double _buttonHeightRef = 36;

  // 로고+버튼 4개 블록 전체 높이(디자인 단위). 로고 높이 + 버튼 4개 높이 + 사이 간격 4개
  // (로고-버튼1, 버튼1-2, 버튼2-3, 버튼3-4)
  static const double _blockHRef =
      _logoHeightRef + _buttonHeightRef * 4 + _itemGapRef * 4;

  // 블록을 디자인 캔버스(402) 안에서 세로 중앙에 놓기 위한 시작 top
  static const double _blockTopRef = (402 - _blockHRef) / 2;

  // 로고/버튼 묶음이 화면 왼쪽 밖으로 잘리지 않게 두는 최소 여백(화면 폭 대비 비율). 아이패드처럼
  // 세로로 긴 화면에서 leftOnBg() 계산값이 이 여백보다 왼쪽으로 나가면 묶음 전체를 오른쪽으로
  // 밀어서 맞춤
  static const double _groupMinLeftMarginRatio = 0.03;

  // 첫 번째 버튼(시작하기) top. 로고 top(=_blockTopRef) + 로고 높이 + 간격 하나
  static const double _firstButtonTopRef =
      _blockTopRef + _logoHeightRef + _itemGapRef;

  // 새 게임 시작 처리. 진행 상황 전부 초기화하고 기존 시작 로직(챕터 선택창 이동) 그대로 탐
  void _startNewGame() {
    ChapterProgress.resetAllProgress();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChapterSelectScreen()),
    );
  }

  // "이어하기" 버튼(MenuOverlay.onSave 연결한 kitchen_screen.dart/chaeon_room_screen.dart/
  // game_play_screen.dart 저장 버튼이랑 같은 데이터 계층을 씀). SaveManager.load()로
  // SaveData를 읽어서 StoryState/ChapterProgress를 전부 복원하고, checkpoint에 맞는
  // 화면으로 resumeCheckpoint를 넘겨서 이동함
  Future<void> _handleContinue() async {
    final SaveData? data = await SaveManager.load();
    if (!mounted || data == null) return;

    // StoryState/ChapterProgress 복원. 저장할 때 읽어갔던 값들을 그대로 되돌려놓음
    restoreStoryStateFromSave(data);

    final SaveCheckpoint? checkpoint = resolveSaveCheckpoint(data);
    if (checkpoint == null) {
      // 저장 파일이 깨졌거나 옛날 포맷이라 체크포인트 이름을 못 알아본 경우 - 엉뚱한
      // 지점으로 보내는 대신 여기서 멈추고 안내만 띄움
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 데이터를 불러올 수 없습니다.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => screenForCheckpoint(checkpoint, data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 반응형 좌표 함수
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 로고/버튼 4개 전용 단일 스케일 + 중앙 정렬 오프셋. bear_arm_puzzle_scene.dart의
    // bearZoomFit() 패턴 참고 - 디자인 캔버스(874x402)를 통째로 한 배율로 축소/확대해서
    // 화면 안에 넣고, 남는 여백은 좌우/상하에 반씩 나눠서 중앙에 오게 함.
    //
    // 가로/세로 배율 중 큰 쪽(max)을 썼을 때는, 화면이 극단적으로 가로로 길어지면(가로가
    // 세로보다 훨씬 큰 비율) 버튼 블록 전체가 화면 세로 길이보다 커져서 아래로 잘려
    // 넘치는 문제가 있었음. 작은 쪽(min)으로 바꾸면 디자인 캔버스가 항상 화면 안에
    // 다 들어오는 게 보장됨(874*scale <= w, 402*scale <= h) - 배경(main_bg.png,
    // BoxFit.cover)이랑 스케일이 완전히 같지는 않지만, UI가 안 잘리는 걸 우선함.
    // 디자인 비율(874:402)이랑 정확히 일치하는 화면에서는 offsetX/offsetY가 0이 되고
    // scale도 지금(rW/rH)이랑 같아서 결과가 완전히 동일함
    final double scale = (w / 874) < (h / 402) ? (w / 874) : (h / 402);
    final double offsetX = (w - 874 * scale) / 2;
    final double offsetY = (h - 402 * scale) / 2;
    double s(double px) => px * scale;

    // 로고/버튼의 가로 위치 전용 매핑. 배경(main_bg.png)은 BoxFit.cover라서 min이 아니라
    // max 배율로 캔버스를 채우고 중앙 정렬함 - 그래서 위 scale/offsetX(min 기준)로 좌우
    // 위치를 잡으면 화면이 가로로 길어질 때 배경이랑 로고/버튼이 서로 다른 기준으로
    // 어긋나 보임(로고/버튼이 배경보다 오른쪽으로 쏠림). bgScale/bgOffsetX는 배경이랑
    // 똑같은 cover 매핑을 써서 가로 위치만 배경 기준에 맞추고, 크기/세로 위치는 여전히
    // 위에 있는 min 스케일(scale/offsetY/s)을 그대로 써야 버튼 블록이 화면 아래로
    // 잘리는 문제가 다시 안 생김. 디자인 비율(874:402)에서는 bgScale도 scale이랑
    // 같아지고 bgOffsetX도 0이라 결과가 지금이랑 동일함
    //
    // bgScale 계산에 쓰는 세로 기준은 402(이 화면 좌표계 전체의 디자인 캔버스 높이)가
    // 아니라 kMainBgDesignHeight(492, 배경 그림 자체의 실제 비율)여야 함 - 둘이 다른
    // 값이라서 402를 쓰면 아이패드처럼 세로가 긴 화면에서 실제 배경 크롭보다 훨씬 많이
    // 밀려나서 로고/버튼이 화면 밖으로 잘렸었음
    final double bgScale = (w / kMainBgDesignWidth) > (h / kMainBgDesignHeight)
        ? (w / kMainBgDesignWidth)
        : (h / kMainBgDesignHeight);
    final double bgOffsetX = (w - kMainBgDesignWidth * bgScale) / 2;

    // bgScale을 실제 배경 비율로 고쳐도 아이패드처럼 극단적으로 좁은 화면에서는 여전히
    // 로고(묶음에서 가장 왼쪽, designX=91)가 화면 밖으로 나갈 수 있어서 안전장치를 하나
    // 더 둠. 로고의 raw left가 최소 여백보다 왼쪽이면 그 차이만큼 묶음 전체를 오른쪽으로
    // 밀어줌 - 묶음 안의 상대 위치(로고-버튼 간격 등)는 그대로 유지됨
    final double groupMinLeftMargin = w * _groupMinLeftMarginRatio;
    final double rawLogoLeft = bgOffsetX + 91 * bgScale;
    final double groupShiftX = rawLogoLeft < groupMinLeftMargin
        ? groupMinLeftMargin - rawLogoLeft
        : 0.0;
    double leftOnBg(double designX) =>
        bgOffsetX + designX * bgScale + groupShiftX;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Image.asset('assets/images/main_bg.png', fit: BoxFit.cover),

          Positioned(
            left: leftOnBg(91), // X축 위치
            top: offsetY + s(_blockTopRef), // Y축 위치
            child: Image.asset(
              'assets/images/logo.png',
              width: s(167), // 로고 크기
              fit: BoxFit.contain,
            ),
          ),

          // 시작하기 버튼
          Positioned(
            left: leftOnBg(100), // X축 위치
            top: offsetY + s(_firstButtonTopRef), // Y축 위치
            width: s(144), // 버튼 크기
            child: _imageMenuButton(
              index: 1,
              normalImg: 'start.png',
              touchImg: 'start_touch.png',
              onPressed: () async {
                // 저장된 게 아예 없으면(첫 실행 등) 되돌릴 진행 상황 자체가 없어서
                // hasSeenEnding 값이랑 상관없이 확인창 없이 바로 시작
                final bool hasSave = await SaveManager.hasSave();
                if (!mounted) return;
                if (!hasSave) {
                  _startNewGame();
                  return;
                }
                // 엔딩까지 이미 본 상태면 어차피 이어갈 진행 상황이 의미가 없어서 확인창
                // 없이 바로 리셋하고 시작. 아직 엔딩 전이면(한창 진행 중일 수 있음) 확인창부터 띄움
                if (ChapterProgress.hasSeenEnding) {
                  _startNewGame();
                } else {
                  setState(() => _showResetConfirm = true);
                }
              },
              rW: s,
              rH: s,
            ),
          ),

          // 이어하기 버튼. 항상 정상적으로 눌리고, 탭한 시점에 저장 데이터가 있는지 확인해서
          // 없으면 안내창만 띄움(버튼 자체를 흐리게 비활성화하지 않음)
          Positioned(
            left: leftOnBg(100), // X축 위치
            top:
                offsetY +
                s(
                  _firstButtonTopRef + (_buttonHeightRef + _itemGapRef),
                ), // Y축 위치
            width: s(144), // 버튼 크기
            child: _imageMenuButton(
              index: 2,
              normalImg: 'continued.png',
              touchImg: 'continued_touch.png',
              onPressed: () async {
                final bool hasSave = await SaveManager.hasSave();
                if (!mounted) return;
                if (!hasSave) {
                  setState(() => _showNoSaveDataNotice = true);
                  return;
                }
                await _handleContinue();
              },
              rW: s,
              rH: s,
            ),
          ),

          // 엔딩보기 버튼(신규). index는 기존 1~3(시작/이어/설정) 순서 주석을 안 건드리려고
          // 화면 배치 순서(이어하기 다음)랑 상관없이 4로 둠 - 어차피 "지금 눌려있는 버튼"
          // 판별용 값이라 숫자 자체엔 의미 없음
          Positioned(
            left: leftOnBg(100), // X축 위치
            top:
                offsetY +
                s(
                  _firstButtonTopRef + (_buttonHeightRef + _itemGapRef) * 2,
                ), // Y축 위치
            width: s(144), // 버튼 크기
            child: _imageMenuButton(
              index: 4,
              normalImg: 'ending.png',
              touchImg: 'ending_touch.png',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EndingGalleryScreen(),
                  ),
                );
              },
              rW: s,
              rH: s,
            ),
          ),

          // 게임 설정 버튼
          Positioned(
            left: leftOnBg(100), // X축 위치
            top:
                offsetY +
                s(
                  _firstButtonTopRef + (_buttonHeightRef + _itemGapRef) * 3,
                ), // Y축 위치
            width: s(144), // 버튼 크기
            child: _imageMenuButton(
              index: 3,
              normalImg: 'setting.png',
              touchImg: 'setting_touch.png',
              onPressed: () => setState(() => _isSettingOpen = true),
              rW: s,
              rH: s,
            ),
          ),

          // 공용 메뉴 오버레이. 이 화면은 대사 진행 화면이 아니라 타이틀 메뉴라서 다른
          // 4개 화면이랑 콜백 처리가 조금 다름(각 콜백 위 주석 참고)
          if (_isSettingOpen)
            MenuOverlay(
              rW: rW,
              rH: rH,
              isAutoAdvanceEnabled: StoryState.isAutoAdvanceEnabled,
              onClose: () => setState(() => _isSettingOpen = false),
              // AUTO는 여기서 당장 쓰이는 대사 화면이 없어도, 전역 설정값이라 여기서
              // 켜두면 나중에 실제 대사가 시작될 때부터 바로 적용됨. 어차피 배경
              // 이미지에 이미 그려진 버튼이라 숨길 수도 없어서 그냥 정상 동작하게 둠
              onToggleAuto: () => setState(
                () => StoryState.isAutoAdvanceEnabled =
                    !StoryState.isAutoAdvanceEnabled,
              ),
              // TODO: 이 화면은 아직 체크포인트 판단 로직이 없어서 저장 기능 미연결.
              // kitchen_screen.dart부터 먼저 연결했고 나중에 여기도 맞춰서 붙일 예정
              onSave: () {},
              // 이 화면 자체가 이미 메인 메뉴 역할이라 MainScreen/ChoiceScreen으로 다시
              // 이동시키는 건 의미 없는 왕복이 됨 - X랑 동일하게 그냥 메뉴만 닫히게 처리함
              onGoToMainScreen: () => setState(() => _isSettingOpen = false),
              // 이 화면은 'choice' 라우트 자체라서 goToChapterSelectClearingStack이 이
              // 화면 인스턴스를 안 지우고 스택에 그대로 남겨둠(다른 4개 화면은 전부 위에
              // 쌓인 채로 사라져서 신경 안 써도 됐던 부분). 그래서 여기서만 이동 직전에
              // 메뉴를 먼저 닫아둬야, 나중에 챕터 선택 화면에서 뒤로가기로 돌아왔을 때
              // 메뉴가 열린 채로 남아있는 걸 막을 수 있음
              onGoToChapterSelect: () {
                setState(() => _isSettingOpen = false);
                goToChapterSelectClearingStack(context);
              },
            ),

          // 새 게임 시작 확인창. 버튼 2개(취소/확인)
          if (_showResetConfirm)
            _buildNoticeDialog(
              rW: rW,
              rH: rH,
              message: '지금까지 진행 상황이 모두 사라집니다.\n처음부터 시작하시겠습니까?',
              buttons: [
                (
                  label: '취소',
                  onTap: () => setState(() => _showResetConfirm = false),
                ),
                (
                  label: '확인',
                  onTap: () {
                    setState(() => _showResetConfirm = false);
                    _startNewGame();
                  },
                ),
              ],
            ),

          // "이어하기" 눌렀는데 저장된 데이터가 없을 때 뜨는 안내창. 버튼 1개(확인)
          if (_showNoSaveDataNotice)
            _buildNoticeDialog(
              rW: rW,
              rH: rH,
              message: '이어하기 데이터가 없습니다',
              buttons: [
                (
                  label: '확인',
                  onTap: () => setState(() => _showNoSaveDataNotice = false),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 확인/안내 팝업 공용 빌더. tutorial_dialogue_box.png 9-slice 배경 + button.png 버튼(들)을
  // 쓰는 스타일. 새 게임 확인창(버튼 2개)이랑 이어하기 데이터 없음 안내창(버튼 1개)이 크기/
  // 스타일을 똑같이 맞추려고 여기로 뺐음. 예전엔 460x220으로 잡았다가 내용물보다 훨씬 커서
  // 세로로 비어 보였던 걸, 내용물 높이에 맞춰 420x160으로 줄이고 패딩/버튼도 같이 줄임.
  // 딤 배경 탭은 흡수만 하고 안 닫음 - 버튼을 직접 눌러야만 닫히게 함
  Widget _buildNoticeDialog({
    required double Function(double) rW,
    required double Function(double) rH,
    required String message,
    required List<({String label, VoidCallback onTap})> buttons,
  }) {
    const double panelWidthRef = 420;
    const double panelHeightRef = 160;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: SizedBox(
              width: rW(panelWidthRef),
              height: rH(panelHeightRef),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: rW(panelWidthRef),
                    height: rH(panelHeightRef),
                    child: ScaledNineSliceImage(
                      imagePath: 'assets/images/tutorial_dialogue_box.png',
                      sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                      scaleX: rW(1),
                      scaleY: rH(1),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: rW(28),
                      vertical: rH(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF5A3E2B),
                            fontSize: rW(15),
                            fontFamily: 'SCDream',
                          ),
                        ),
                        SizedBox(height: rH(14)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < buttons.length; i++) ...[
                              if (i > 0) SizedBox(width: rW(16)),
                              GestureDetector(
                                onTap: buttons[i].onTap,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/button.png',
                                      width: rW(110),
                                      height: rH(36),
                                      fit: BoxFit.fill,
                                    ),
                                    Text(
                                      buttons[i].label,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: rW(14),
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'SCDream',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 이미지 전용 버튼 위젯 함수
  Widget _imageMenuButton({
    required int index,
    required String normalImg,
    required String touchImg,
    required VoidCallback onPressed,
    required Function rW,
    required Function rH,
  }) {
    bool isPressed = (_pressedIndex == index);

    return Padding(
      padding: EdgeInsets.only(bottom: rH(10)), // rH로 비율 유지
      child: GestureDetector(
        // 터치하는 순간 이미지 교체
        onTapDown: (_) => setState(() => _pressedIndex = index),
        // 터치 떼는 순간 원래대로 + 기능 실행
        onTapUp: (_) {
          setState(() => _pressedIndex = 0);
          onPressed();
        },
        // 누르다가 밖으로 삐져나가면 취소
        onTapCancel: () => setState(() => _pressedIndex = 0),

        child: Image.asset(
          'assets/images/${isPressed ? touchImg : normalImg}',
          width: rW(220),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
