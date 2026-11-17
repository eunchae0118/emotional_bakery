// lib/features/menu/chapter_intro_screen.dart
//
// 챕터 시작 전에 뜨는 "간지"(소개) 화면. gan.png 한 장을 모든 챕터가 공유하고, 그 위에
// 제목/부제만 코드로 얹음. 자동으로 페이드인 -> 유지 -> 페이드아웃 되면서 사라지고, 화면을
// 탭하면 그 자리에서 바로 건너뛸 수 있음. 실제로 어느 화면으로 넘어갈지는 이 위젯이 모르고
// (넘어가기 전 chapter_select_screen.dart에 있던 진입 로직을 그대로 두고 싶어서), 그냥
// 끝나면 Navigator.pop만 함 - 호출하는 쪽이 이 화면을 push한 뒤 await로 기다렸다가,
// pop되면 원래 하려던 진입 로직을 이어서 그대로 실행하는 방식으로 연결함

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// 페이드 인 -> 유지 -> 페이드 아웃 시간. 숫자만 바꾸면 전체 타이밍이 바로 조정됨
const Duration kChapterIntroFadeInDuration = Duration(milliseconds: 500);
const Duration kChapterIntroHoldDuration = Duration(milliseconds: 2000);
const Duration kChapterIntroFadeOutDuration = Duration(milliseconds: 500);

// 제목/부제 위치(874x402 디자인 캔버스 기준, 왼쪽 위). chapter_select_screen.dart의
// u()/main_screen.dart의 s()랑 동일하게 가로세로 배율 중 작은 쪽으로 스케일해서, 아이패드
// (4:3)처럼 가로세로 비율이 design 캔버스(874:402)랑 많이 다른 기기에서도 글자가 화면
// 밖으로 안 나가게 함 - 화면 보면서 조정 예정
//
// (수정: chapter_end_screen.dart도 간지랑 똑같은 제목/부제 위치·크기를 써야 해서 private
// 접두사(_)를 떼고 공개 상수로 바꿈 - 값 자체는 안 바뀜, 이 파일 안에서 쓰던 곳도 이름만 바뀜)
const double kChapterTitleLeftRef = 60;
const double kChapterTitleTopRef = 50;
const double kChapterTitleSubtitleGapRef = 10;
const double kChapterTitleFontSizeRef = 44;
const double kChapterSubtitleFontSizeRef = 20;

// precacheImage(챕터 카드 탭 시점)랑 여기 Image.asset이 정확히 같은 크기를 줘야 ResizeImage
// 캐시 키가 일치해서 미리 디코딩해둔 걸 그대로 재사용함 - 하나라도 다르면 두 번 디코딩됨
int ganPngCacheWidth(BuildContext context) {
  final MediaQueryData mq = MediaQuery.of(context);
  return (mq.size.width * mq.devicePixelRatio).round();
}

class ChapterIntroScreen extends StatefulWidget {
  const ChapterIntroScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  // 챕터 선택 카드에 쓰는 문구를 그대로 넘겨받음(새로 하드코딩 안 함)
  final String title;
  final String subtitle;

  @override
  State<ChapterIntroScreen> createState() => _ChapterIntroScreenState();
}

class _ChapterIntroScreenState extends State<ChapterIntroScreen> {
  double _opacity = 0.0;
  bool _isFinished = false;
  Timer? _fadeOutTimer;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    // build에서 바로 1.0을 주면 AnimatedOpacity가 애니메이션 없이 그냥 바로 보여버림 -
    // 첫 프레임이 그려지고 난 다음 틱에 올려야 0->1 페이드인이 실제로 재생됨
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
    _fadeOutTimer = Timer(
      kChapterIntroFadeInDuration + kChapterIntroHoldDuration,
      () {
        if (mounted) setState(() => _opacity = 0.0);
      },
    );
    _finishTimer = Timer(
      kChapterIntroFadeInDuration +
          kChapterIntroHoldDuration +
          kChapterIntroFadeOutDuration,
      _finish,
    );
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    _finishTimer?.cancel();
    super.dispose();
  }

  // 자동 종료 타이머랑 탭 둘 다 여기로 들어옴 - 먼저 들어온 쪽이 끝내고 나면 나머지 하나는
  // _isFinished에 걸려서 그냥 무시됨(pop이 두 번 불리는 일이 없음)
  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    _fadeOutTimer?.cancel();
    _finishTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 자동 재생 + 탭 스킵만으로 끝나는 화면이라 시스템 뒤로가기로 빠져나가는 경로는 안
      // 열어둠 - 뒤로가기로 여기서 나가버리면 호출한 쪽은 그걸 모르고 그대로 챕터 진입을
      // 이어가 버려서 간지만 건너뛰고 챕터는 그대로 시작돼버림(의도한 "취소"가 안 됨)
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
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
                duration: kChapterIntroFadeInDuration,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 배경은 안전 캔버스 레터박싱 없이 화면 전체를 꽉 채움(비율 안 맞으면 cover로 크롭)
                    Image.asset(
                      'assets/images/gan.png',
                      fit: BoxFit.cover,
                      cacheWidth: ganPngCacheWidth(context),
                    ),
                    Positioned(
                      left: offsetX + s(kChapterTitleLeftRef),
                      top: offsetY + s(kChapterTitleTopRef),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: s(kChapterTitleFontSizeRef),
                              // chapter_select_screen.dart 카드 제목이랑 동일한 폰트/굵기
                              fontWeight: FontWeight.w800,
                              fontFamily: 'SCDream',
                            ),
                          ),
                          SizedBox(height: s(kChapterTitleSubtitleGapRef)),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: s(kChapterSubtitleFontSizeRef),
                              // chapter_select_screen.dart 카드 부제목이랑 동일한 폰트/굵기
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SCDream',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
