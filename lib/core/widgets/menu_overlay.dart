// lib/core/widgets/menu_overlay.dart

// 모든 화면(챕터1~5 대사 화면)에서 공용으로 쓰는 메뉴 오버레이. 재료 획득 팝업 등 기존
// 팝업들이랑 동일하게 검은 반투명 50% 딤 배경 + 중앙 정렬 패널(tutorial_dialogue_box.png
// 9-slice 재사용) 스타일로 만듦. 미니게임 화면(BreadMakingScene 등)에는 안 붙임 - 그
// 화면들은 원래 설정 버튼 자체가 없음
//
// X(닫기)만 이 위젯이 직접 처리하고, 나머지 버튼(AUTO/챕터이동/메인화면으로/게임종료)은
// 실제 동작(Navigator 이동 등)을 콜백으로 받아서 호출하는 화면 쪽에 맡김 - 화면마다 이동
// 대상이나 처리 방식이 조금씩 다를 수 있어서 재사용성을 위해 이렇게 분리함

// (업데이트: 배경을 위 tutorial_dialogue_box 9-slice 패널에서 실제 시안 이미지
// main_setting_ex.png로 바꿈. 이 이미지가 화면 전체를 채우고 X/챕터이동/메인화면으로/게임종료는
// 이미지에 이미 그려져 있어서 투명 히트박스만 얹음. AUTO는 켜졌을 때만 auto.png를 그 자리에
// 겹쳐서 켜짐/꺼짐을 구분함. 딤 배경이나 별도 패널 위젯은 더 안 씀)

// (업데이트 2: 위에서 화면 전체를 꽉 채우던 배경을 다시 줄임 - 딤 배경(검은 반투명 50%)을
// 맨 아래에 깔고, main_setting_ex.png는 그 위에서 650:342 비율 유지한 채로 화면의 80% 안에
// 레터박스로 맞춰서 중앙에 띄움. 다른 팝업들이 화면을 안 꽉 채우고 딤 배경 위에 작게 뜨는
// 것과 톤을 맞추려는 거임. 버튼 좌표는 여전히 650x342 캔버스 기준 비율이라 배경이 작아진
// 만큼 같이 축소되게 아래 로컬 스케일 함수를 다시 계산함)

import 'package:flutter/material.dart';

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({
    super.key,
    required this.rW,
    required this.rH,
    required this.isAutoAdvanceEnabled,
    required this.onClose,
    required this.onToggleAuto,
    required this.onGoToChapterSelect,
    required this.onGoToMainScreen,
    required this.onExitGame,
  });

  // 호출하는 화면들은 각자 자기 화면 기준(874x402 등)으로 만든 rW/rH를 넘겨주는데, 이
  // 배경(main_setting_ex.png)은 그거랑 다른 자체 디자인 기준(650x342)이라 그대로는 못 씀.
  // build() 안에서 이 이미지 기준 로컬 스케일 함수를 따로 만들어 쓰고, 여기 파라미터는 4개
  // 화면 호출부를 안 건드려도 되게 시그니처만 유지함(실제로는 안 씀)
  final double Function(double) rW;
  final double Function(double) rH;
  final bool isAutoAdvanceEnabled;
  final VoidCallback onClose;
  final VoidCallback onToggleAuto;
  final VoidCallback onGoToChapterSelect;
  final VoidCallback onGoToMainScreen;
  final VoidCallback onExitGame;

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;

    // main_setting_ex.png(650:342)를 화면의 80% 박스 안에 비율 유지한 채로 레터박스로 맞춤.
    // popupW/popupH는 이미지가 들어갈 수 있는 최대 박스고, imageAspect랑 비교해서 가로/세로 중
    // 어느 쪽이 꽉 차는 기준이 되는지 정한 다음 실제 렌더 크기(renderedW/H)를 구함 - 예전
    // main_setting_ex.png 시안 팝업(지금은 MenuOverlay로 대체됨)이 쓰던 것과 동일한 계산
    final double popupW = w * 0.8;
    final double popupH = h * 0.8;
    const double imageAspect = 650 / 342;
    double renderedW, renderedH;
    if (imageAspect > popupW / popupH) {
      renderedW = popupW;
      renderedH = popupW / imageAspect;
    } else {
      renderedH = popupH;
      renderedW = popupH * imageAspect;
    }
    final double offsetX = (w - renderedW) / 2;
    final double offsetY = (h - renderedH) / 2;

    // main_setting_ex.png 디자인 기준 좌표(650x342)를 실제 렌더 크기(renderedW/H) 기준으로
    // 바꿔주는 로컬 스케일 함수. 위치는 레터박스 오프셋을 더해야 하고, 크기는 오프셋 없이
    // 비율만 곱하면 됨(kitchen_screen.dart의 wX/wY/wSize랑 동일한 이유)
    double localX(double px) => offsetX + (px / 650) * renderedW;
    double localY(double px) => offsetY + (px / 342) * renderedH;
    double localW(double px) => (px / 650) * renderedW;
    double localH(double px) => (px / 342) * renderedH;

    return Positioned.fill(
      key: const ValueKey('menu_overlay'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 딤 배경 탭 흡수해서 뒤 화면 안 눌리게 막음(팝업은 안 닫힘) - 4개 화면의 기존 설정
        // 팝업이랑 동일한 동작
        onTap: () {},
        child: Container(
          // 다른 팝업들(재료 안내창 등)이랑 동일한 검은 반투명 50% 딤 배경
          color: Colors.black.withOpacity(0.5),
          child: Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: renderedW,
                height: renderedH,
                child: Image.asset(
                  'assets/images/main_setting_ex.png',
                  fit: BoxFit.fill,
                ),
              ),

              // X 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음
              Positioned(
                left: localX(593),
                top: localY(15),
                width: localW(47),
                height: localH(43),
                child: GestureDetector(onTap: onClose),
              ),

              // AUTO 버튼. 켜져 있으면 auto.png를 배경 위에 겹쳐서 켜짐 표시, 꺼져 있으면
              // 배경 그림 그대로 노출. 탭 히트박스는 이미지 유무랑 상관없이 항상 이 자리에 유지됨
              Positioned(
                left: localX(51),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(
                  onTap: onToggleAuto,
                  child: isAutoAdvanceEnabled
                      ? Image.asset(
                          'assets/images/auto.png',
                          width: localW(123),
                          height: localH(39),
                          fit: BoxFit.fill,
                        )
                      : null,
                ),
              ),

              // 챕터이동 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음
              Positioned(
                left: localX(191),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(onTap: onGoToChapterSelect),
              ),

              // 메인화면으로 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음
              Positioned(
                left: localX(329),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(onTap: onGoToMainScreen),
              ),

              // 게임종료 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음
              Positioned(
                left: localX(469),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(onTap: onExitGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
