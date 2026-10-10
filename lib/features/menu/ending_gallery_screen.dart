// lib/features/menu/ending_gallery_screen.dart
//
// "엔딩보기" 화면. 다이어리/스크랩북을 펼친 모습으로, EndingUnlocks(ending_unlocks.dart)에
// 영구 저장된 해금 상태를 읽어서 해금된 엔딩만 스크린샷+요약 텍스트를 보여줌. main.dart에서
// 앱 시작 시 이미 EndingUnlocks.load()를 해둔 전제라 여기선 static 값을 바로 읽기만 함

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';
import 'package:emotional_bakery/core/services/ending_unlocks.dart';

// 스프레드(ending_zip_1.png)/배경(ending_zip_bg.png) 원본 크기 기준 좌표계
const double _paperWidth = 3508;
const double _paperHeight = 1987;

// 엔딩 요약 텍스트용 폰트("그리운고딕 사랑스러운"). pubspec.yaml fonts: 섹션에 등록된 family명
const String _summaryFontFamily = 'GriunGothicSarangseureoun';

// 엔딩 요약 텍스트 폰트 크기/행간(3508x1987 기준 좌표계 값, *scale로 화면에 맞게 환산해서 씀).
// 원래 10pt/14.4pt였는데 실제로 보니 너무 작아서 28pt/40pt로 키움 - 더 조정 필요하면 이
// 두 숫자만 바꾸면 됨
const double _summaryFontSizeRef = 40;
const double _summaryLineHeightRef = 70;

// 박스 바닥에서 요약 텍스트 시작 지점까지 여백(3508x1987 기준 좌표계 값, *scale로 환산).
// 텍스트가 박스랑 안 겹치게 떨어뜨리는 용도 - 더 조정 필요하면 이 숫자만 바꾸면 됨
const double _summaryTextGapRef = -300;

// 뒤로가기 버튼 전용 단일 스케일. chapter_select_screen.dart 뒤로가기 버튼이랑 완전히 같은
// 식(u = min(w/874, h/402))을 써야 같은 기기에서 두 버튼이 항상 같은 크기로 보임 - 이 화면
// 고유의 3508 기준 scale이랑 무관하게 다른 메뉴 화면들이 쓰는 874x402 기준을 그대로 가져다 씀.
// 가로/세로를 따로 계산하던 예전 방식(_backButtonRW/_backButtonRH)은 min 하나로 합쳐서
// 항상 정사각형이 유지되게 함
double _backButtonU(double px, double screenWidth, double screenHeight) =>
    px * min(screenWidth / 874, screenHeight / 402);

// 엔딩 하나당 박스 위치/크기/회전각 + 표시할 에셋/텍스트를 묶어둔 데이터.
// 중심점(cx, cy)/폭(width)/높이(height)는 전부 3508x1987 기준 좌표계 값
class _EndingBoxSpec {
  const _EndingBoxSpec({
    required this.unlocked,
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.angleDeg,
    required this.screenshotAsset,
    required this.summaryText,
    this.textOffsetX = 0,
    this.textOffsetY = 0,
  });

  final bool unlocked;
  final double cx;
  final double cy;
  final double width;
  final double height;
  final double angleDeg;
  final String screenshotAsset;
  final String summaryText;
  // 이 엔딩의 요약 텍스트만 따로 미세조정할 때 쓰는 추가 오프셋(3508x1987 기준 좌표계 값,
  // *scale로 환산해서 적용됨). 공용 _summaryTextGapRef 등 다른 전체 조정값 위에 "이 박스만"
  // 더 얹는 값 - 기본 0이면 아무 영향 없음. +면 오른쪽/아래, -면 왼쪽/위로 이동
  final double textOffsetX;
  final double textOffsetY;
}

class EndingGalleryScreen extends StatefulWidget {
  const EndingGalleryScreen({super.key});

  @override
  State<EndingGalleryScreen> createState() => _EndingGalleryScreenState();
}

class _EndingGalleryScreenState extends State<EndingGalleryScreen> {
  static const String _happyText =
      "채온이는 감정을 마주하기로 했어요.\n그러던 어느 날, 엄마를 꿈속에서\n"
      "다시 만나 환하게 웃어보였어요.\n이후 모든 감정을 되찾게 되었어요.";
  static const String _normalText =
      "채온이는 빵집을 찾아갔지만,\n빵집은 사라졌있었어요.\n"
      "감정이 온전히 돌아오지 못했지만\n이제는 괜찮다는 것을 알고있어요.";
  static const String _badText =
      "채온이는 행복의 빵에 중독되었어요.\n그러던 어느 날, 빵집이 사라졌어요.\n"
      "채온이는 지금도, 어디선가 빵집을\n찾아 헤매고있을지도 몰라요.";
  static const String _hiddenText =
      "채온이는 엄마를 위한 빵을 구웠어요.\n그리고 꿈에서 엄마에게 환하게\n"
      "웃어보였어요. 이후, 모든 감정을 되찾았어요.\n그리고 제빵사라는 꿈을 꾸게 되었어요.";

  @override
  void initState() {
    super.initState();
    // 메인 메뉴/챕터 선택/빵집이랑 같은 곡. ChoiceScreen에서 "엔딩보기"로 들어오면 이미
    // main_theme이 재생 중이라 AudioService가 아무것도 안 하고 그대로 이어짐
    AudioService.playBgm(AudioIds.mainTheme);
  }

  // ★ 테스트용 임시 코드 - EndingGalleryScreen 레이아웃/회전 확인 끝나면 이 메서드와
  // build()의 DEBUG 버튼 Positioned 블록을 통째로 지울 것. kDebugMode라 release 빌드엔
  // 안 들어가지만, 그래도 테스트 끝나면 바로 제거하기로 함
  Future<void> _debugUnlockAllEndings() async {
    await EndingUnlocks.unlock(EndingType.happy);
    await EndingUnlocks.unlock(EndingType.normal);
    await EndingUnlocks.unlock(EndingType.bad);
    await EndingUnlocks.unlock(EndingType.hidden);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // 종이 스프레드(ending_zip_1.png) 전용 스케일 - 종횡비 유지하며 화면에 맞춤(BoxFit.contain
    // 방식). 배경(ending_zip_bg.png)은 이 스케일과 무관하게 화면을 항상 꽉 채움(BoxFit.cover)
    final double scale = min(
      screenWidth / _paperWidth,
      screenHeight / _paperHeight,
    );
    final double renderedPaperWidth = _paperWidth * scale;
    final double renderedPaperHeight = _paperHeight * scale;
    final double paperOriginX = (screenWidth - renderedPaperWidth) / 2;
    final double paperOriginY = (screenHeight - renderedPaperHeight) / 2;

    final List<_EndingBoxSpec> boxes = [
      _EndingBoxSpec(
        unlocked: EndingUnlocks.hasUnlockedHappy,
        cx: 582.5,
        cy: 682,
        width: 708.4,
        height: 421.4,
        angleDeg: 1.187,
        screenshotAsset: 'assets/images/endig_happy_8.png',
        summaryText: _happyText,
        // 해피엔딩 텍스트만 따로 조정하고 싶으면 이 두 값만 바꾸면 됨(3508 기준 좌표계 px)
        textOffsetX: 750,
        textOffsetY: -20,
      ),
      _EndingBoxSpec(
        unlocked: EndingUnlocks.hasUnlockedNormal,
        cx: 588.5,
        cy: 1174,
        width: 708.4,
        height: 421.4,
        angleDeg: 1.187,
        screenshotAsset: 'assets/images/ending_nomal_4.png',
        summaryText: _normalText,
        // 노말엔딩 텍스트만 따로 조정하고 싶으면 이 두 값만 바꾸면 됨(3508 기준 좌표계 px)
        textOffsetX: 760,
        textOffsetY: 0,
      ),
      _EndingBoxSpec(
        unlocked: EndingUnlocks.hasUnlockedBad,
        cx: 2283.5,
        cy: 991.5,
        width: 707.5,
        height: 418.8,
        angleDeg: -1.319,
        screenshotAsset: 'assets/images/endig_bad_5.png',
        summaryText: _badText,
        // 베드엔딩 텍스트만 따로 조정하고 싶으면 이 두 값만 바꾸면 됨(3508 기준 좌표계 px)
        textOffsetX: 775,
        textOffsetY: 30,
      ),
      _EndingBoxSpec(
        unlocked: EndingUnlocks.hasUnlockedHidden,
        cx: 2275,
        cy: 1477.5,
        width: 706.6,
        height: 418.8,
        angleDeg: -1.319,
        screenshotAsset: 'assets/images/ending_hidden_9.png',
        summaryText: _hiddenText,
        // 히든엔딩 텍스트만 따로 조정하고 싶으면 이 두 값만 바꾸면 됨(3508 기준 좌표계 px)
        textOffsetX: 750,
        textOffsetY: 30,
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 배경 레이어: 화면 비율과 무관하게 항상 화면을 꽉 채움
          Image.asset('assets/images/ending_zip_bg.png', fit: BoxFit.cover),

          // 2. 종이 스프레드 레이어: 종횡비 유지, 중앙 정렬. 남는 공간은 위 배경이 그대로 보임
          Positioned(
            left: paperOriginX,
            top: paperOriginY,
            width: renderedPaperWidth,
            height: renderedPaperHeight,
            child: Image.asset(
              'assets/images/ending_zip_1.png',
              fit: BoxFit.contain,
            ),
          ),

          // 3. 엔딩 박스 오버레이 레이어: 해금된 것만 스크린샷+요약 텍스트를 그 위에 덧그림
          for (final box in boxes)
            if (box.unlocked)
              ..._buildUnlockedOverlay(
                box: box,
                paperOriginX: paperOriginX,
                paperOriginY: paperOriginY,
                scale: scale,
              ),

          // 뒤로가기 버튼. 이 화면은 원래 3508x1987 기준 로컬 scale을 쓰는데, 뒤로가기
          // 버튼만큼은 그 캔버스랑 무관하게 chapter_select_screen.dart 뒤로가기 버튼이랑
          // 완전히 똑같은 식(u = min(w/874, h/402), 874x402 기준)을 그대로 씀. 기준 캔버스가
          // 다른 채로 숫자만 맞추면 화면비 바뀔 때마다 또 어긋나서, 아예 같은 계산식을 써서
          // 같은 기기에서 두 화면 버튼이 항상 똑같은 크기(+정사각형)로 보이게 함
          Positioned(
            left: _backButtonU(10, screenWidth, screenHeight),
            top: _backButtonU(10, screenWidth, screenHeight),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Image.asset(
                'assets/images/main_back_btn.png',
                width: _backButtonU(54, screenWidth, screenHeight),
                height: _backButtonU(54, screenWidth, screenHeight),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ★ 테스트용 임시 버튼 - 디버그 빌드에서만 보임(kDebugMode). 4개 엔딩을 전부
          // 강제 해금해서 박스 위치/회전/텍스트를 한 번에 확인할 수 있게 함.
          // 테스트 끝나면 이 Positioned 블록 전체 + 위 _debugUnlockAllEndings() 삭제할 것
          if (kDebugMode)
            Positioned(
              right: 20,
              top: 20,
              child: GestureDetector(
                onTap: _debugUnlockAllEndings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '전체 해금(DEBUG)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 해금된 엔딩 하나의 스크린샷+요약 텍스트 오버레이. 둘 다 각자 자기 Positioned 박스의
  // 중심을 기준으로 Transform.rotate(기본 Alignment.center)해서, 박스/텍스트 각각 자기
  // 중심을 축으로 같은 각도만큼 회전함
  List<Widget> _buildUnlockedOverlay({
    required _EndingBoxSpec box,
    required double paperOriginX,
    required double paperOriginY,
    required double scale,
  }) {
    final double screenX = paperOriginX + box.cx * scale;
    final double screenY = paperOriginY + box.cy * scale;
    final double screenW = box.width * scale;
    final double screenH = box.height * scale;
    // Flutter의 Transform.rotate는 양수 각도가 시계방향 회전인데, 실제 화면에서 반대 방향으로
    // 기울어 보여서 부호를 뒤집음(-1 곱함). 스크린샷/텍스트 둘 다 이 변수 하나를 그대로
    // angle로 쓰고 있어서 여기 한 곳만 고치면 양쪽에 다 반영됨
    final double angleRad = -1 * box.angleDeg * pi / 180;

    // 3508 기준 좌표계 스펙(_summaryFontSizeRef/_summaryLineHeightRef)을 화면 스케일로 환산.
    // Flutter TextStyle.height는 fontSize의 배수라 행간/폰트크기 비율 그대로 씀
    final double fontSize = _summaryFontSizeRef * scale;
    final double lineHeightMultiplier =
        _summaryLineHeightRef / _summaryFontSizeRef;

    // 텍스트 블록의 "고정" 높이를 줄 수 x 행간으로 미리 계산함. 아래 Positioned가
    // height를 직접 안 주고 Text의 실측 높이에 맡기면, 그 실측값이 PC/모바일(폰트 렌더링
    // 엔진·DPR 차이)에 따라 달라질 수 있고, Transform.rotate는 "자기 child 박스의 중심"을
    // 축으로 회전하기 때문에 그 흔들림이 그대로 회전축 어긋남 = 텍스트 위치 틀어짐으로
    // 이어짐. 스크린샷(width+height 둘 다 고정)처럼 텍스트도 scale에서만 결정되는 고정
    // height를 줘서 회전축을 플랫폼 무관하게 고정시킴. 여유분(+0.5줄)은 폰트 측정이
    // 살짝 더 커도 아래쪽이 잘리지 않게 하는 안전 마진
    final int lineCount = '\n'.allMatches(box.summaryText).length + 1;
    final double textBlockHeight = _summaryLineHeightRef * scale * (lineCount + 0.5);

    return [
      // 스크린샷 - 박스 중심에 박스 크기(screenW x screenH)로 덮어씌움
      Positioned(
        left: screenX - screenW / 2,
        top: screenY - screenH / 2,
        width: screenW,
        height: screenH,
        child: Transform.rotate(
          angle: angleRad,
          child: Image.asset(box.screenshotAsset, fit: BoxFit.cover),
        ),
      ),
      // 요약 텍스트 - 박스의 왼쪽 아래 모서리를 기준점으로 삼아, 왼쪽 정렬 + 박스 바닥에서
      // _summaryTextGapRef만큼 아래로 띄움(4개 엔딩 공통 조정). 그 위에 box.textOffsetX/Y를
      // 한 번 더 더해서 이 엔딩 하나만 따로 미세조정할 수 있게 함(기본 0이면 영향 없음).
      // 가로폭은 박스 폭(screenW)으로 제한해서 줄바꿈이 박스 범위 안에서 자연스럽게 되게 함
      Positioned(
        left: screenX - screenW / 2 + box.textOffsetX * scale,
        top:
            screenY +
            screenH / 2 +
            _summaryTextGapRef * scale +
            box.textOffsetY * scale,
        width: screenW,
        height: textBlockHeight,
        child: Transform.rotate(
          angle: angleRad,
          child: Text(
            box.summaryText,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: _summaryFontFamily,
              fontSize: fontSize,
              height: lineHeightMultiplier,
              color: const Color(0xFF4A3426),
            ),
          ),
        ),
      ),
    ];
  }
}
