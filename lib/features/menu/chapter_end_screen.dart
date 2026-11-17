// lib/features/menu/chapter_end_screen.dart
//
// 챕터가 끝났을 때 뜨는 종료 화면. 간지(chapter_intro_screen.dart)랑 배경/제목 레이아웃을
// 그대로 공유하고, 대신 자동으로 안 사라지고 버튼 두 개(메인 메뉴로 / 다음 챕터로) 중
// 하나를 눌러야 다음으로 넘어감. 여기서는 화면 자체랑 자동 입장 연결(goToChapterSelectClearingStack
// + ChapterSelectScreen.autoEnterChapterNumber)만 만들고, 실제로 어느 챕터가 끝나는
// 지점에서 이 화면을 띄울지는 다음 단계에서 연결함(kitchen_screen.dart/chaeon_room_screen.dart/
// 프롤로그 쪽은 아직 안 건드림)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/menu/chapter_intro_screen.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart';

// 화면이 뜰 때 페이드인 시간. 간지(kChapterIntroFadeInDuration)랑 똑같이 500ms로 맞춤
const Duration kChapterEndFadeInDuration = Duration(milliseconds: 500);

// 버튼 두 개(bt1/bt2) 크기/위치(874x402 디자인 캔버스 기준). 둘 다 원본이 546x165(가로:세로
// 약 3.3:1)라 가로 크기만 정하고 세로는 비율로 맞춤. 가운데 쌍으로 모아서 화면 하단에 둠 -
// 화면 보면서 조정 예정
const double kChapterEndButtonWidthRef = 200;
const double kChapterEndButtonHeightRef = kChapterEndButtonWidthRef * 165 / 546;
const double kChapterEndButtonGapRef = 24;
const double kChapterEndButtonBottomRef = 40;

// 버튼을 누르고 있는 동안 살짝 작아지고 어두워지는 정도
const double kChapterEndButtonPressedScale = 0.95;
const double kChapterEndButtonPressedOpacity = 0.75;

class ChapterEndScreen extends StatefulWidget {
  const ChapterEndScreen({super.key, required this.chapterNumber})
    : assert(
        chapterNumber >= 0 && chapterNumber <= 4,
        '챕터 종료 화면은 0(프롤로그)~4만 받음 - 5는 다음 챕터가 없어서 대상이 아님',
      );

  // 지금 끝난 챕터 번호. 0이면 프롤로그, 1~4면 그 챕터. 다음 챕터 번호는 이 값 + 1로 계산함
  final int chapterNumber;

  @override
  State<ChapterEndScreen> createState() => _ChapterEndScreenState();
}

class _ChapterEndScreenState extends State<ChapterEndScreen> {
  double _opacity = 0.0;
  bool _hasStartedPrecache = false;
  // 버튼 하나를 누르면 즉시 켜서 두 버튼 다 더는 안 먹게 막음 - 연타로 화면 이동이
  // 두 번 일어나는 걸 방지함
  bool _isNavigating = false;
  // 지금 눌려있는 버튼(1=메인 메뉴, 2=다음 챕터). null이면 아무것도 안 눌려있음
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    // 간지랑 동일한 이유로 postFrameCallback에서 올려야 0->1 페이드인이 실제로 재생됨
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  // bt1/bt2/gan을 화면이 완전히 보이기 전에 미리 디코딩해둠. precacheImage가
  // BuildContext를 써야 해서 initState가 아니라 여기서 부름(다른 미니게임 화면들이랑
  // 동일한 패턴)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedPrecache) return;
    _hasStartedPrecache = true;
    final int ganWidth = ganPngCacheWidth(context);
    final int buttonWidth = _buttonCacheWidth(context);
    precacheImage(
      ResizeImage.resizeIfNeeded(
        ganWidth,
        null,
        const AssetImage('assets/images/gan.png'),
      ),
      context,
    ).catchError((Object _) {});
    precacheImage(
      ResizeImage.resizeIfNeeded(
        buttonWidth,
        null,
        const AssetImage('assets/images/bt1.png'),
      ),
      context,
    ).catchError((Object _) {});
    precacheImage(
      ResizeImage.resizeIfNeeded(
        buttonWidth,
        null,
        const AssetImage('assets/images/bt2.png'),
      ),
      context,
    ).catchError((Object _) {});
  }

  // 버튼 실제 표시 크기(디자인 폭 * 화면 스케일)에 맞춘 cacheWidth. precacheImage랑
  // Image.asset이 여기서 똑같은 값을 받아야 ResizeImage 캐시 키가 일치함(ganPngCacheWidth
  // 주석 참고). build()의 LayoutBuilder 제약 대신 MediaQuery 화면 크기로 근사함 - 이 화면은
  // Scaffold가 전체 화면을 그대로 채워서 둘이 거의 항상 같음
  int _buttonCacheWidth(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double scale = math.min(mq.size.width / 874, mq.size.height / 402);
    final double displayWidth = kChapterEndButtonWidthRef * scale;
    return (displayWidth * mq.devicePixelRatio).round();
  }

  // 다음 챕터 번호. 5를 넘으면(이 화면 생성 자체가 0~4로 막혀있어서 실제로는 안 생기지만,
  // 방어적으로) null을 줘서 bt2를 안 보이게 함
  int? get _nextChapterNumber {
    final int next = widget.chapterNumber + 1;
    return next <= 5 ? next : null;
  }

  void _handleGoToMainMenu() {
    if (_isNavigating) return;
    if (!context.mounted) return;
    _isNavigating = true;
    goToChapterSelectClearingStack(context);
  }

  void _handleEnterNextChapter() {
    if (_isNavigating) return;
    final int? next = _nextChapterNumber;
    if (next == null) return;
    if (!context.mounted) return;
    _isNavigating = true;
    goToChapterSelectClearingStack(context, autoEnterChapterNumber: next);
  }

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle) =
        kChapterCardTitles[widget.chapterNumber]!;
    final int? nextChapterNumber = _nextChapterNumber;
    final String? nextChapterLabel = nextChapterNumber != null
        ? kChapterCardTitles[nextChapterNumber]!.$1
        : null;

    return PopScope(
      // 간지랑 동일한 이유로 뒤로가기를 막음 - 버튼 두 개 중 하나로만 나가게 해야
      // 호출한 쪽(챕터 선택 화면)이 흐름을 안 놓침
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final double h = constraints.maxHeight;
            final double scale = math.min(w / 874, h / 402);
            final double offsetX = (w - 874 * scale) / 2;
            final double offsetY = (h - 402 * scale) / 2;
            double s(double px) => px * scale;

            return AnimatedOpacity(
              opacity: _opacity,
              duration: kChapterEndFadeInDuration,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/gan.png',
                    fit: BoxFit.cover,
                    cacheWidth: ganPngCacheWidth(context),
                  ),
                  // 제목/부제 - 간지랑 똑같은 안전영역 위치/스타일(공개 상수 재사용)
                  Positioned(
                    left: offsetX + s(kChapterTitleLeftRef),
                    top: offsetY + s(kChapterTitleTopRef),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: s(kChapterTitleFontSizeRef),
                            fontWeight: FontWeight.w800,
                            fontFamily: 'SCDream',
                          ),
                        ),
                        SizedBox(height: s(kChapterTitleSubtitleGapRef)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: s(kChapterSubtitleFontSizeRef),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SCDream',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 버튼 두 개(또는 다음 챕터가 없으면 하나) - 화면 하단에 가운데로 모아서 둠
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: offsetY + s(kChapterEndButtonBottomRef),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildButton(
                            s: s,
                            index: 1,
                            asset: 'assets/images/bt1.png',
                            onTap: _handleGoToMainMenu,
                          ),
                          if (nextChapterLabel != null) ...[
                            SizedBox(width: s(kChapterEndButtonGapRef)),
                            _buildButton(
                              s: s,
                              index: 2,
                              asset: 'assets/images/bt2.png',
                              onTap: _handleEnterNextChapter,
                              overlayText: nextChapterLabel,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 버튼 하나(이미지 + 필요하면 가운데 글자 + 눌림 반응)를 그려줌. bt1은 overlayText 없이
  // 이미지 자체 글자를 그대로 씀, bt2는 overlayText로 다음 챕터 이름을 가운데 얹음
  Widget _buildButton({
    required double Function(double) s,
    required int index,
    required String asset,
    required VoidCallback onTap,
    String? overlayText,
  }) {
    final bool isPressed = _pressedIndex == index;
    final double width = s(kChapterEndButtonWidthRef);
    final double height = s(kChapterEndButtonHeightRef);

    return GestureDetector(
      onTapDown: (_) {
        if (_isNavigating) return;
        setState(() => _pressedIndex = index);
      },
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTapUp: (_) {
        if (_isNavigating) return;
        setState(() => _pressedIndex = null);
        onTap();
      },
      child: AnimatedScale(
        scale: isPressed ? kChapterEndButtonPressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: isPressed ? kChapterEndButtonPressedOpacity : 1.0,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  asset,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  cacheWidth: _buttonCacheWidth(context),
                ),
                if (overlayText != null)
                  Text(
                    overlayText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s(kChapterSubtitleFontSizeRef),
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SCDream',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
