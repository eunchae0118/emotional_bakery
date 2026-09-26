// lib/core/widgets/shared_ui.dart
// 튜토리얼/챕터1 화면에서 같이 쓰는 대사창, 가상 패드 버튼 공용 위젯

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 페이드아웃 300ms -> 완전 검은 화면 유지 1000ms -> 페이드인 300ms, 총 1600ms
const Duration _fadeThroughBlackFadeOut = Duration(milliseconds: 150);
const Duration _fadeThroughBlackHold = Duration(milliseconds: 800);
const Duration _fadeThroughBlackFadeIn = Duration(milliseconds: 300);

// fadeOutDuration/holdDuration/fadeInDuration을 안 넘기면 기존 기본값(150/800/300ms)
// 그대로 씀. 특정 전환만 암전을 더 길게 주고 싶을 때 이 셋만 넘기면 됨(다른 호출부는
// 안 건드려도 기존 그대로 동작함)
PageRouteBuilder fadeThroughBlackRoute(
  Widget page, {
  Duration? fadeOutDuration,
  Duration? holdDuration,
  Duration? fadeInDuration,
}) {
  final Duration fadeOut = fadeOutDuration ?? _fadeThroughBlackFadeOut;
  final Duration hold = holdDuration ?? _fadeThroughBlackHold;
  final Duration fadeIn = fadeInDuration ?? _fadeThroughBlackFadeIn;
  final Duration total = fadeOut + hold + fadeIn;
  final double fadeOutEnd = fadeOut.inMilliseconds / total.inMilliseconds;
  final double holdEnd =
      (fadeOut + hold).inMilliseconds / total.inMilliseconds;

  // 페이지 전환 시, 화면이 검은색으로 페이드아웃 -> 잠시 유지 -> 페이드인 되도록 하는 커스텀 트랜지션
  return PageRouteBuilder(
    transitionDuration: total,
    reverseTransitionDuration: total,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final double v = animation.value;
      final double blackOpacity;
      final double childOpacity;
      if (v < fadeOutEnd) {
        blackOpacity = v / fadeOutEnd;
        childOpacity = 0.0;
      } else if (v < holdEnd) {
        blackOpacity = 1.0;
        childOpacity = 1.0;
      } else {
        blackOpacity = 1.0 - (v - holdEnd) / (1.0 - holdEnd);
        childOpacity = 1.0;
      }
      return Stack(
        children: [
          Opacity(opacity: childOpacity, child: child),
          IgnorePointer(
            child: Opacity(
              opacity: blackOpacity.clamp(0.0, 1.0),
              child: Container(color: Colors.black),
            ),
          ),
        ],
      );
    },
  );
}

// 애니메이션 없이 바로 화면을 바꾸는 라우트. 검은 배경 화면끼리 이어지는 구간(암전 ->
// iOS 설치 안내 -> 콘텐츠 경고 -> 로고 화면)에서 기본 MaterialPageRoute의 전환
// 애니메이션 때문에 화면이 겹쳐 보이거나 번쩍이는 것처럼 보이는 문제가 있어서 씀
PageRouteBuilder instantRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

// tutorial_dialogue_box.png(1119x285)를 9-slice로 그릴 때 쓰는 테두리 영역.
// 실측해보면 테두리 두께가 상하좌우 약 30px이라 이 값을 써야 어떤 크기로 늘려도
// 테두리 두께가 균일하게 유지됨 (5px처럼 실제보다 얇게 잡으면 테두리 대부분이
// 늘어나는 중앙 영역으로 취급돼서 두께가 들쑥날쑥해짐)
const Rect tutorialDialogueBoxCenterSlice = Rect.fromLTRB(31, 31, 1088, 252);

// ScaledNineSliceImage 테두리 두께 공식: dst = 원본두께(31px 등) * kDialogueBoxBorderThicknessRatio
// * scale(화면 배율). "scale이 1.0 넘으면 원본으로 고정" 같은 클램프를 예전엔 뒀었는데,
// 그러면 기준 해상도(874x402) 바로 위(예: 896x414)에서 배율이 1.0에 걸려 갑자기
// "원본 그대로"로 튀어버리고, 바로 아래(예: 667x375)에서만 매끄럽게 얇아지는 부자연스러운
// 경계가 생겼음(896x414이 667x375보다 살짝만 큰데 테두리는 3배 가까이 두꺼워짐). 그래서
// 클램프 없이 모든 해상도에서 똑같이 선형으로 스케일하고, 절대적인 두께 자체가 다른 UI
// 요소(패딩 rW(20), 글자 rW(13) 등)에 비해 너무 두꺼웠던 것을 이 비율로 낮춤. 값은
// "667x375에서 의도한 대로 보인다"는 피드백을 기준으로 역산한 값(0.763배율일 때
// 31*0.45*0.763≈10.6px가 되도록). 여전히 두껍거나 얇으면 이 숫자만 조정하면 됨
const double kDialogueBoxBorderThicknessRatio = 0.45;

// Flutter의 DecorationImage(centerSlice: ...) / drawImageNine은 모서리(테두리) 영역을
// 항상 "원본 이미지 픽셀 크기 그대로" 그리고, 상자가 커지거나 작아져도 그 두께가 화면
// 배율(rW/rH)에 맞춰 얇아지지 않는다(가운데 영역만 늘어남). 그래서 화면이 작아져서
// 상자 전체가 작아져도 테두리는 그대로라 상대적으로 두꺼워 보이는 문제가 있었음. 이
// 위젯은 9개 조각을 직접 canvas.drawImageRect로 그려서, 테두리 두께(destLeft/Right/
// Top/Bottom)를 화면 배율에 맞춰 클램프 없이 선형으로 스케일함(자세한 설명은
// kDialogueBoxBorderThicknessRatio 주석 참고)
class ScaledNineSliceImage extends StatefulWidget {
  const ScaledNineSliceImage({
    super.key,
    required this.imagePath,
    required this.sourceCenterSlice,
    required this.scaleX,
    required this.scaleY,
  });

  final String imagePath;
  // 9-slice 기준 영역. 원본 이미지 픽셀 좌표
  final Rect sourceCenterSlice;
  // 테두리 두께에 곱할 배율(가로/세로 따로). rW(1)/rH(1)을 넘기면 다른 UI 요소와 동일한
  // 기준으로 스케일됨
  final double scaleX;
  final double scaleY;

  @override
  State<ScaledNineSliceImage> createState() => _ScaledNineSliceImageState();
}

class _ScaledNineSliceImageState extends State<ScaledNineSliceImage> {
  ui.Image? _image;
  ImageStream? _imageStream;
  late ImageStreamListener _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _imageStreamListener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ScaledNineSliceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _resolveImage();
  }

  void _resolveImage() {
    _imageStream?.removeListener(_imageStreamListener);
    _imageStream = AssetImage(
      widget.imagePath,
    ).resolve(const ImageConfiguration());
    _imageStream!.addListener(_imageStreamListener);
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_imageStreamListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _image;
    if (image == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _NineSlicePainter(
        image: image,
        centerSlice: widget.sourceCenterSlice,
        scaleX: widget.scaleX,
        scaleY: widget.scaleY,
      ),
    );
  }
}

class _NineSlicePainter extends CustomPainter {
  _NineSlicePainter({
    required this.image,
    required this.centerSlice,
    required this.scaleX,
    required this.scaleY,
  });

  final ui.Image image;
  final Rect centerSlice;
  final double scaleX;
  final double scaleY;

  // 인접한 조각끼리 이 값만큼(destination 기준) 살짝 겹치게 그려서, 서브픽셀 반올림으로
  // 생기는 1px 미만의 이음새 틈을 메움. 조각 하나하나가 이만큼 더 넓게 그려질 뿐이라
  // 육안으로는 안 보임
  static const double _seamBleed = 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();
    final double leftSrc = centerSlice.left;
    final double topSrc = centerSlice.top;
    final double rightSrc = srcW - centerSlice.right;
    final double bottomSrc = srcH - centerSlice.bottom;

    // 테두리 두께 = 원본두께 * kDialogueBoxBorderThicknessRatio * scale. 클램프나 지수
    // 없이 모든 해상도에서 동일하게 선형 스케일(자세한 설명은 파일 상단
    // kDialogueBoxBorderThicknessRatio 주석 참고). scaleX/scaleY를 각각 따로 쓰면 화면
    // 비율이 874:402(기준 캔버스 비율)랑 다를 때 좌우/상하 테두리 두께가 서로 많이
    // 달라져서 비대칭으로 이상하게 보이므로, 둘 중 더 작은 쪽(min) 하나로 통일해서
    // 네 변 전부 같은 두께로 그림
    final double scale =
        math.min(scaleX, scaleY) * kDialogueBoxBorderThicknessRatio;
    final double leftDst = (leftSrc * scale).clamp(0.0, size.width / 2);
    final double rightDst = (rightSrc * scale).clamp(0.0, size.width / 2);
    final double topDst = (topSrc * scale).clamp(0.0, size.height / 2);
    final double bottomDst = (bottomSrc * scale).clamp(0.0, size.height / 2);

    final List<double> srcXs = [0, leftSrc, centerSlice.right, srcW];
    final List<double> srcYs = [0, topSrc, centerSlice.bottom, srcH];
    final List<double> dstXs = [0, leftDst, size.width - rightDst, size.width];
    final List<double> dstYs = [
      0,
      topDst,
      size.height - bottomDst,
      size.height,
    ];

    // FilterQuality.medium(이중선형 보간)을 쓰면 조각과 조각이 맞닿는 경계에서 인접
    // 조각의 픽셀이 살짝 섞여 들어와 가느다란 이음새 선이 보이는 문제가 있었음.
    // FilterQuality.none(최근접 샘플링)으로 바꾸면 각 조각이 자기 영역 밖 픽셀을
    // 절대 참조하지 않아서 필터링으로 인한 이음새는 안 생김(다만 서브픽셀 반올림으로
    // 인한 1px 미만 틈은 별도로 _seamBleed가 메워줌)
    final Paint paint = Paint()..filterQuality = FilterQuality.none;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final Rect src = Rect.fromLTRB(
          srcXs[col],
          srcYs[row],
          srcXs[col + 1],
          srcYs[row + 1],
        );
        // 바깥쪽 가장자리(0 또는 size)는 그대로 두고, 다른 조각과 맞닿는 안쪽 경계만
        // bleed만큼 늘려서 겹치게 함
        final double left = dstXs[col] - (col > 0 ? _seamBleed : 0);
        final double top = dstYs[row] - (row > 0 ? _seamBleed : 0);
        final double right = dstXs[col + 1] + (col < 2 ? _seamBleed : 0);
        final double bottom = dstYs[row + 1] + (row < 2 ? _seamBleed : 0);
        final Rect dst = Rect.fromLTRB(left, top, right, bottom);
        if (src.width <= 0 || src.height <= 0) continue;
        if (dst.width <= 0 || dst.height <= 0) continue;
        canvas.drawImageRect(image, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NineSlicePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.centerSlice != centerSlice ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY;
  }
}

// 대사창 텍스트 공통 스타일
TextStyle dialogueTextStyle(double Function(double) rW) {
  return TextStyle(
    color: const Color(0xFF5A3E2B),
    fontSize: rW(13),
    height: 1.5,
    fontWeight: FontWeight.w500,
    fontFamily: 'SCDream',
  );
}

// 대사창 프레임. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
class DialogueBoxFrame extends StatelessWidget {
  final Widget textWidget;
  final double Function(double) rW;
  final double Function(double) rH;

  const DialogueBoxFrame({
    super.key,
    required this.textWidget,
    required this.rW,
    required this.rH,
  });

  @override
  Widget build(BuildContext context) {
    // 배경(9-slice)은 바깥 Stack에 Positioned.fill로만 얹고, 텍스트/화살표/패딩 구조는
    // 예전(centerSlice 직접 쓰던 시절) Container(padding:, decoration:, child: Stack(...))
    // 그대로 유지함. 예전엔 IntrinsicWidth가 "Container(네이티브 padding 포함)"의 고유
    // 너비를 기준으로 상자 크기를 정했는데, 배경 분리 작업 때 padding을 별도 Padding
    // 위젯 + 중첩 Stack으로 바꿨더니 상자 크기 계산이 미묘하게 달라져서 화살표가
    // 마지막 글자 옆이 아니라 상자 가운데 쪽으로 어긋나 보이는 해상도가 생겼음. 지금처럼
    // "Container가 네이티브 padding으로 직접 크기를 정하고, 배경은 그 바깥 Stack에서
    // Positioned.fill로 크기만 따라감" 구조로 두면 크기 계산 기준이 예전과 완전히 같아짐
    return IntrinsicWidth(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ScaledNineSliceImage(
              imagePath: 'assets/images/tutorial_dialogue_box.png',
              sourceCenterSlice: tutorialDialogueBoxCenterSlice,
              scaleX: rW(1),
              scaleY: rH(1),
            ),
          ),
          Container(
            // 세로 패딩/minHeight도 rW 기준으로 씀. 글자 크기(fontSize: rW(13))와 상자
            // 너비가 전부 rW(화면 가로 기준)로 스케일되는데, 세로 패딩/minHeight만 rH
            // (화면 세로 기준)를 쓰면 화면 비율이 기준 캔버스(874x402)와 많이 다를 때
            // (예: 태블릿처럼 가로 대비 세로가 긴 화면) 글자 크기는 그대로인데
            // minHeight만 훨씬 커져서 상자가 글자에 비해 과도하게 높아 보이는 문제가
            // 있었음. 전부 rW로 통일하면 글자/패딩/최소너비/최소높이가 항상 같은
            // 비율로 같이 커지고 작아짐
            padding: EdgeInsets.symmetric(horizontal: rW(20), vertical: rW(19)),
            constraints: BoxConstraints(
              minWidth: rW(180),
              maxWidth: rW(500),
              minHeight: rW(70),
            ),
            // 텍스트와 화살표를 겹치지 않게 배치
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 텍스트 위젯
                Padding(
                  padding: EdgeInsets.fromLTRB(rW(20), 0, rW(20), 0),
                  child: textWidget,
                ),
                Positioned(
                  right: rW(0),
                  // 세로 위치/크기도 rW 기준으로 통일(위 padding/minHeight랑 동일한 이유)
                  bottom: rW(7),
                  child: Image.asset(
                    'assets/images/tutorial_arrow.png',
                    width: rW(12),
                    height: rW(10),
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 대사창을 화면 중앙에 띄우는 위젯. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
class CenteredDialogueBox extends StatelessWidget {
  final Widget textWidget;
  final double Function(double) rW;
  final double Function(double) rH;

  const CenteredDialogueBox({
    super.key,
    required this.textWidget,
    required this.rW,
    required this.rH,
  });

  // 화면 중앙에 대사창을 띄움. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.2),
      child: DialogueBoxFrame(textWidget: textWidget, rW: rW, rH: rH),
    );
  }
}

// 가상 패드 버튼 (좌우 이동 공용)
class DpadButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback? onTapCancel;
  final double Function(double) rW;
  final double Function(double) rH;
  // 버튼 한 변 크기(디자인 기준 px). 안 넘기면 기존 기본값(64) 그대로 씀 - tutorial_screen.dart
  // 처럼 이 값을 안 넘기는 기존 호출부는 전혀 안 건드려도 원래 크기 그대로 유지됨. 모바일에서
  // 너무 작다는 피드백을 받은 화면(game_play_screen.dart/chaeon_room_screen.dart/
  // kitchen_screen.dart)만 더 큰 값을 넘겨서 씀
  final double? size;

  const DpadButton({
    super.key,
    required this.imagePath,
    required this.onTapDown,
    required this.onTapUp,
    this.onTapCancel,
    required this.rW,
    required this.rH,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonSize = size ?? 64;
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel ?? onTapUp, // 버튼 밖으로 손가락이 미끄러져 나가도 멈추도록 예외 처리
      child: Container(
        width: rW(buttonSize),
        height: rH(buttonSize),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// 이미지 경로가 바뀔 때, 이전 이미지는 완전히 불투명하게 그대로 둔 채 새 이미지만 그 위에서
// 서서히 나타나게 하는 위젯(릴리안/채온이 표정 전환용). 일반 크로스페이드(AnimatedSwitcher
// 기본 동작)는 신구 이미지가 동시에 반투명해지는데, 배경이 투명한 캐릭터 PNG에서는 그 순간
// 두 장이 흐릿하게 겹쳐 비치면서 캐릭터가 옅어졌다 사라지는 것처럼 보임. 이전 이미지를 안
// 흐리고 새 이미지만 덮어씌우듯 페이드인하면 그 문제가 없음
class PopInImage extends StatefulWidget {
  const PopInImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit,
    this.duration = const Duration(milliseconds: 120),
  });

  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Duration duration;

  @override
  State<PopInImage> createState() => _PopInImageState();
}

class _PopInImageState extends State<PopInImage>
    with SingleTickerProviderStateMixin {
  late String _currentPath = widget.imagePath;
  // 새 이미지가 완전히 덮을 때까지만 밑에 깔아두는 이전 이미지. 애니메이션 끝나면 비워서
  // 불필요하게 계속 들고 있지 않게 함
  String? _previousPath;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _previousPath = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant PopInImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != _currentPath) {
      // duration은 initState에서 한 번만 넘겨지는 게 아니라 매 전환마다 새로 반영해야
      // 함(예: kitchen_screen.dart의 채온이 스프라이트처럼 "표정 전환은 페이드,
      // 걷기/정지 전환은 즉시"를 같은 PopInImage 하나로 표현하려고 duration을 상황에
      // 따라 다르게 넘기는 경우)
      _controller.duration = widget.duration;
      setState(() {
        _previousPath = _currentPath;
        _currentPath = widget.imagePath;
      });
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_previousPath != null)
          Image.asset(
            _previousPath!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          ),
        FadeTransition(
          opacity: _controller,
          child: Image.asset(
            _currentPath,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          ),
        ),
      ],
    );
  }
}
