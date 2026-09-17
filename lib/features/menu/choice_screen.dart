// lib/features/menu/choice_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/app_exit.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/menu_overlay.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';

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

  // 새 게임 시작 처리. 진행 상황 전부 초기화하고 기존 시작 로직(챕터 선택창 이동) 그대로 탐
  void _startNewGame() {
    ChapterProgress.resetAllProgress();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChapterSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 반응형 좌표 함수
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Image.asset('assets/images/main_bg.png', fit: BoxFit.cover),

          Positioned(
            left: rW(91), // X축 위치
            top: rH(52), // Y축 위치
            child: Image.asset(
              'assets/images/logo.png',
              width: rW(167), // 로고 크기
              fit: BoxFit.contain,
            ),
          ),

          // 시작하기 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(195), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 1,
              normalImg: 'start.png',
              touchImg: 'start_touch.png',
              onPressed: () {
                // 엔딩까지 이미 본 상태면 어차피 이어갈 진행 상황이 의미가 없어서 확인창
                // 없이 바로 리셋하고 시작. 아직 엔딩 전이면(한창 진행 중일 수 있음) 확인창부터 띄움
                if (ChapterProgress.hasSeenEnding) {
                  _startNewGame();
                } else {
                  setState(() => _showResetConfirm = true);
                }
              },
              rW: rW,
              rH: rH,
            ),
          ),

          // 이어하기 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(239), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 2,
              normalImg: 'continued.png',
              touchImg: 'continued_touch.png',
              onPressed: () => print("이어하기 클릭!"),
              rW: rW,
              rH: rH,
            ),
          ),

          // 엔딩보기 버튼(신규). index는 기존 1~3(시작/이어/설정) 순서 주석을 안 건드리려고
          // 화면 배치 순서(이어하기 다음)랑 상관없이 4로 둠 - 어차피 "지금 눌려있는 버튼"
          // 판별용 값이라 숫자 자체엔 의미 없음
          Positioned(
            left: rW(100), // X축 위치
            top: rH(283), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 4,
              normalImg: 'ending.png',
              touchImg: 'ending_touch.png',
              // TODO: 엔딩보기 화면 연결 예정
              onPressed: () {},
              rW: rW,
              rH: rH,
            ),
          ),

          // 게임 설정 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(327), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 3,
              normalImg: 'setting.png',
              touchImg: 'setting_touch.png',
              onPressed: () => setState(() => _isSettingOpen = true),
              rW: rW,
              rH: rH,
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
              onGoToChapterSelect: () => Navigator.pushReplacement(
                context,
                fadeThroughBlackRoute(const ChapterSelectScreen()),
              ),
              // 이 화면 자체가 이미 메인 메뉴 역할이라 MainScreen/ChoiceScreen으로 다시
              // 이동시키는 건 의미 없는 왕복이 됨 - X랑 동일하게 그냥 메뉴만 닫히게 처리함
              onGoToMainScreen: () => setState(() => _isSettingOpen = false),
              onExitGame: exitGame,
            ),

          // 새 게임 시작 확인창. 다른 팝업들이랑 동일한 검은 반투명 딤 배경 + 중앙 패널 스타일.
          // 배경 탭은 흡수만 하고 안 닫음 - 확인/취소 버튼을 직접 눌러야만 닫히게 함
          if (_showResetConfirm)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: rW(420),
                      padding: EdgeInsets.all(rW(24)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A3E2B),
                        borderRadius: BorderRadius.circular(rW(16)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '지금까지 진행 상황이 모두 사라집니다.\n처음부터 시작하시겠습니까?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: rW(15),
                              fontFamily: 'SCDream',
                            ),
                          ),
                          SizedBox(height: rH(20)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showResetConfirm = false),
                                child: Container(
                                  width: rW(120),
                                  height: rH(40),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      rW(20),
                                    ),
                                  ),
                                  child: Text(
                                    '취소',
                                    style: TextStyle(
                                      color: const Color(0xFF5A3E2B),
                                      fontSize: rW(14),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SCDream',
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: rW(16)),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _showResetConfirm = false);
                                  _startNewGame();
                                },
                                child: Container(
                                  width: rW(120),
                                  height: rH(40),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7100),
                                    borderRadius: BorderRadius.circular(
                                      rW(20),
                                    ),
                                  ),
                                  child: Text(
                                    '확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: rW(14),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SCDream',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
