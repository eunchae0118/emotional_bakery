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

// (업데이트 3: 챕터이동 자리(191,265,123,39)를 저장 버튼으로 바꿈 - 저장/불러오기 시스템
// 연결하면서 메뉴에 저장 기능이 필요해졌는데, 자리가 4개뿐이라 챕터이동을 대신 뺌. 전용
// 이미지 에셋이 없어서 다른 버튼들처럼 투명 히트박스만 얹는 대신, 배경에 박힌 "챕터이동"
// 글자를 가리도록 간단한 텍스트 라벨을 그 위에 얹었음. onGoToChapterSelect 콜백은 없어지고
// onSave로 대체됨 - 이 위젯을 쓰는 화면들 전부 호출부를 맞춰줘야 함)

// (업데이트 4: main_setting_ex.png 시안이 저장 버튼 그림까지 포함해서 새로 교체됨 - 위
// 업데이트 3에서 코드로 얹던 텍스트 라벨은 이제 필요 없어져서 뺐고, 다른 버튼들이랑 동일하게
// 투명 히트박스만 남겨둠)

// (업데이트 5: 게임종료 버튼을 없애고 그 자리(469,265,123,39)를 저장 버튼이 이어받음.
// 저장이 있던 자리(329,265,123,39)는 챕터이동이 새로 들어옴. 게임종료 콜백(onExitGame)은
// 빼고 챕터이동용 콜백(onGoToChapterSelect)을 새로 받음. main_setting_ex.png엔 아직
// 챕터이동 그림이 없어서(저장 자리를 그대로 쓰는 거라 "저장" 글자가 비쳐 보임) 그 위에
// 덮어씌울 이미지를 kChapterMoveButtonImagePath 경로로 따로 얹음 - 파일이 아직 없어도
// errorBuilder로 받아서 빈 자리로만 두고 앱은 안 죽게 해둠)

// (업데이트 6: 업데이트 5에서 넣은 kChapterMoveButtonImagePath 이미지 얹기 방식을 뺌 -
// Image.asset의 errorBuilder가 돌려주는 위젯엔 width/height가 전혀 안 먹혀서(Flutter
// Image 위젯 소스 확인함), 파일이 없는 동안 child가 진짜로 0x0이 되고 GestureDetector도
// child가 있으면 기본이 deferToChild라 터치 영역까지 같이 0x0이 돼버렸음 - 그래서 챕터이동
// 버튼을 눌러도 아무 반응이 없었던 거임. 어차피 main_setting_ex.png가 글자까지 다 그려진
// 통이미지라 이 버튼 전용 이미지 자체가 필요 없어서, 다른 버튼들처럼 child 없는 GestureDetector로
// 되돌리고 behavior만 명시함)

// (업데이트 7: 배경음악/효과음 볼륨 조절을 연결함. main_setting_ex.png 위쪽에 그려진 -/+
// 버튼이랑 점 5칸짜리 단계 표시에 투명 히트박스/덮개를 얹어서 AudioService.bgmVolume/
// sfxVolume을 직접 조절함. 다른 버튼들(AUTO 등)은 상태가 밖에서(isAutoAdvanceEnabled
// 파라미터) 들어오는데, 볼륨은 AudioService가 전역 static 값이라 이 위젯이 직접 읽고 바로
// 반영하면 돼서 StatelessWidget에서 StatefulWidget으로 바꿈 - 탭할 때마다 setState로
// 점 표시만 다시 그리면 됨)

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';

class MenuOverlay extends StatefulWidget {
  const MenuOverlay({
    super.key,
    required this.rW,
    required this.rH,
    required this.isAutoAdvanceEnabled,
    required this.onClose,
    required this.onToggleAuto,
    required this.onSave,
    required this.onGoToMainScreen,
    required this.onGoToChapterSelect,
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
  final VoidCallback onSave;
  final VoidCallback onGoToMainScreen;
  final VoidCallback onGoToChapterSelect;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  // 아래 볼륨 UI 좌표는 main_setting_ex.png 실제 픽셀(1300x685)을 색 경계 스캔으로 직접
  // 읽어서 구한 값임(눈대중 아님) - 650x342 디자인 캔버스 기준으로 절반(÷2)해서 옮겼음.
  // -/+ 버튼은 배경음악/효과음 두 줄 다 가로 위치(220.5, 541.0)가 같고 세로 위치만 다름
  static const double _volumeMinusLeftRef = 220.5;
  static const double _volumePlusLeftRef = 541.0;
  static const double _volumeButtonSizeRef = 29.0;
  static const double _bgmRowTopRef = 78.5;
  static const double _sfxRowTopRef = 143.5;

  // 점 5칸의 가로 위치(간격이 균등해서 그대로 리스트로 뺌). 폭/높이는 실측값에 테두리
  // 안티앨리어싱까지 확실히 덮도록 사방으로 살짝 여유를 더함
  static const List<double> _volumeDotLeftRefs = [
    289.5,
    341.0,
    392.5,
    443.5,
    495.0,
  ];
  static const double _volumeDotWidthRef = 12.5;
  static const double _volumeDotHeightRef = 10.5;
  static const double _bgmDotTopRef = 88.0;
  static const double _sfxDotTopRef = 153.0;

  // 점 칸을 가릴 때 덮어씌우는 사각형 색. main_setting_ex.png의 점 주변 패널 안쪽 배경색을
  // 그대로 픽셀에서 읽은 값(222,141,83) - 이 색으로 덮으면 배경이랑 구분이 안 가서 점이
  // 꺼진 것처럼 보임
  static const Color _volumeDotMaskColor = Color(0xFFDE8D53);

  void _changeBgmVolume(int delta) {
    final int next = AudioService.bgmVolume + delta;
    if (next < 0 || next > AudioService.maxVolumeStep) return; // 범위 밖이면 무시
    AudioService.setBgmVolume(next);
    setState(() {});
  }

  void _changeSfxVolume(int delta) {
    final int next = AudioService.sfxVolume + delta;
    if (next < 0 || next > AudioService.maxVolumeStep) return;
    AudioService.setSfxVolume(next);
    setState(() {});
    // 바뀐 효과음 볼륨을 바로 들어볼 수 있게 확인용으로 한 번 재생함. volumePreview가
    // audio_ids.dart에 아직 등록 안 된 자리라 지금은 조용히 무시됨
    AudioService.playSfx(AudioIds.volumePreview);
  }

  // 배경음악/효과음 한 줄 분(=-버튼 + +버튼 + 점 5칸)을 통째로 만들어주는 공용 빌더.
  // 두 줄이 가로 위치/크기는 똑같고 세로 위치(rowTopRef/dotTopRef)랑 현재 단계만 달라서
  // 함수 하나로 묶었음
  List<Widget> _buildVolumeRow({
    required double Function(double) localX,
    required double Function(double) localY,
    required double Function(double) localW,
    required double Function(double) localH,
    required double rowTopRef,
    required double dotTopRef,
    required int currentStep,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    return [
      Positioned(
        left: localX(_volumeMinusLeftRef),
        top: localY(rowTopRef),
        width: localW(_volumeButtonSizeRef),
        height: localH(_volumeButtonSizeRef),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDecrease,
          child: kDebugMode ? _buildDebugTouchAreaOverlay() : null,
        ),
      ),
      Positioned(
        left: localX(_volumePlusLeftRef),
        top: localY(rowTopRef),
        width: localW(_volumeButtonSizeRef),
        height: localH(_volumeButtonSizeRef),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onIncrease,
          child: kDebugMode ? _buildDebugTouchAreaOverlay() : null,
        ),
      ),
      // currentStep보다 높은 칸만 가림 - 예를 들어 currentStep=3이면 인덱스 3,4(4번째,
      // 5번째 점)만 덮어서 앞 3칸만 켜진 것처럼 보임
      for (int i = 0; i < _volumeDotLeftRefs.length; i++)
        if (i >= currentStep)
          Positioned(
            left: localX(_volumeDotLeftRefs[i]),
            top: localY(dotTopRef),
            width: localW(_volumeDotWidthRef),
            height: localH(_volumeDotHeightRef),
            child: Container(color: _volumeDotMaskColor),
          ),
    ];
  }

  // 디버그 빌드에서만 버튼 터치 영역을 반투명 빨간색으로 보여주는 용도. 시안 글자 위치랑
  // 실제 터치 영역(Positioned 박스)이 맞는지 눈으로 바로 확인하려고 넣음. Positioned가
  // width/height를 주고 있어서 이 Container는 부모가 준 크기를 그대로 채움. 릴리즈
  // 빌드에선 호출하는 쪽에서 kDebugMode 체크로 아예 안 부르니까 완전히 안 보임
  Widget _buildDebugTouchAreaOverlay() {
    return Container(color: Colors.red.withOpacity(0.3));
  }

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

              // 배경음악 볼륨 줄(-버튼/+버튼/점 5칸)
              ..._buildVolumeRow(
                localX: localX,
                localY: localY,
                localW: localW,
                localH: localH,
                rowTopRef: _bgmRowTopRef,
                dotTopRef: _bgmDotTopRef,
                currentStep: AudioService.bgmVolume,
                onDecrease: () => _changeBgmVolume(-1),
                onIncrease: () => _changeBgmVolume(1),
              ),

              // 효과음 볼륨 줄(-버튼/+버튼/점 5칸)
              ..._buildVolumeRow(
                localX: localX,
                localY: localY,
                localW: localW,
                localH: localH,
                rowTopRef: _sfxRowTopRef,
                dotTopRef: _sfxDotTopRef,
                currentStep: AudioService.sfxVolume,
                onDecrease: () => _changeSfxVolume(-1),
                onIncrease: () => _changeSfxVolume(1),
              ),

              // X 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음. behavior를
              // opaque로 명시해서 child 유무랑 상관없이 Positioned가 준 영역 전체가
              // 눌리는 걸 보장함(명시 안 하면 child 없을 때 기본값인 translucent라도
              // 결과적으로는 똑같이 동작하긴 하지만, 나중에 누가 child를 붙여도 안전하게
              // 명시적으로 박아둠)
              Positioned(
                left: localX(593),
                top: localY(15),
                width: localW(47),
                height: localH(43),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                ),
              ),

              // AUTO 버튼. 켜져 있으면 auto.png를 배경 위에 겹쳐서 켜짐 표시, 꺼져 있으면
              // 배경 그림 그대로 노출. 탭 히트박스는 이미지 유무랑 상관없이 항상 이 자리에 유지됨.
              // behavior: opaque를 명시해서, auto.png 로드가 혹시 실패해도(챕터이동 버튼
              // 때 겪은 것과 동일한 문제) 터치 영역이 줄어들지 않게 안전장치를 걸어둠
              Positioned(
                left: localX(51),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggleAuto,
                  child: Stack(
                    children: [
                      if (widget.isAutoAdvanceEnabled)
                        Image.asset(
                          'assets/images/auto.png',
                          width: localW(123),
                          height: localH(39),
                          fit: BoxFit.fill,
                        ),
                      if (kDebugMode) _buildDebugTouchAreaOverlay(),
                    ],
                  ),
                ),
              ),

              // 챕터이동 버튼. 저장 버튼이 있던 자리(329)를 이어받음. main_setting_ex.png가
              // 글자까지 전부 그려진 통이미지라 이 버튼은 따로 이미지가 필요 없어서, 다른
              // 버튼들이랑 동일하게 child 없는 투명 히트박스로 둠(업데이트 6 참고 - 예전엔
              // 여기에 별도 이미지를 Image.asset+errorBuilder로 얹었다가 그게 터치 영역을
              // 0으로 만드는 원인이었음)
              Positioned(
                left: localX(329),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onGoToChapterSelect,
                  child: kDebugMode ? _buildDebugTouchAreaOverlay() : null,
                ),
              ),

              // 메인화면으로 버튼. 이미지에 이미 그려져 있어서 투명 히트박스만 얹음
              Positioned(
                left: localX(191),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onGoToMainScreen,
                  child: kDebugMode ? _buildDebugTouchAreaOverlay() : null,
                ),
              ),

              // 저장 버튼. 게임종료 버튼이 있던 자리(469)를 이어받음 - 게임종료 버튼 자체는
              // 없앰. main_setting_ex.png엔 아직 "게임종료" 글자가 그대로 그려져 있을 수
              // 있는데(시안 교체 전까지는 그대로임), 탭 동작은 저장으로 바뀜
              Positioned(
                left: localX(469),
                top: localY(265),
                width: localW(123),
                height: localH(39),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSave,
                  child: kDebugMode ? _buildDebugTouchAreaOverlay() : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
