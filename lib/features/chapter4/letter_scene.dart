// lib/features/chapter4/letter_scene.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

// 챕터4에서 채온이가 엄마 편지를 읽는 컷씬. dialogue_overlay.dart처럼 화면 전체를
// 덮고 탭으로 진행하는 구조를 그대로 따르긴 하는데, 여긴 이전 줄이 사라지는 대신
// 편지 줄이 계속 아래로 쌓이면서 보이는 게 다름
class LetterScene extends StatefulWidget {
  final VoidCallback onComplete;

  const LetterScene({super.key, required this.onComplete});

  @override
  State<LetterScene> createState() => _LetterSceneState();
}

class _LetterSceneState extends State<LetterScene> {
  // letter_bg.png 원본은 1920x1142(비율은 874x520이랑 거의 동일, 1920/1142≈1.681 vs
  // 874/520≈1.681)이라 874 기준 레퍼런스 프레임은 874x520을 그대로 씀.
  // 아래 네 값(85, 35.709, 줄 시작/끝 x)은 letter_bg.png를 직접 픽셀 스캔해서 잰 값임 -
  // 줄은 가로 76~797.5 사이에 그려져 있어서 시작(85)/끝(874-85=789, 797.5랑 거의 대칭)
  // 둘 다 그 안쪽에 적당히 여백을 두고 앉게 잡음
  static const double _bgRefWidth = 874;
  static const double _bgRefHeight = 520;
  static const double _letterStartXRef = 85;
  // 가로 보호 클램프 하한값 - 화면 가로폭 중 최소 이 비율만큼은 글자 시작 x가 화면
  // 왼쪽 끝에서 떨어져 있게 함(아이패드 프로 13처럼 정사각형에 가까운 화면에서 글자가
  // 화면 끝에 바로 붙는 걸 막으려고 넣음). 5%는 임의로 잡은 값 - 더 크게 잡고 싶으면
  // 이 숫자만 올리면 됨
  static const double _letterMinLeftMarginRatio = 0.05;
  // 편지지 가로줄 17개를 10개 x열에서 서브픽셀 단위(밝기 가중 평균)로 스캔해서 잰 값.
  // 줄 간격은 평균 27.998(최대 편차 0.026)로 거의 완벽하게 일정하고, 첫 줄 중심이
  // 36이 아니라 35.709라서 여기만 그 값으로 고침
  static const double _letterStartYRef = 35.709;
  // 처음엔 height:2.02 그대로 두고 시작 y만 고쳐도 될 줄 알았는데(기준 크기 874x520,
  // scale=1에선 실제로 줄당 오차 0.03px 이하로 거의 완벽했음), scale이 1이 아닌
  // 화면(예: 아이폰 에뮬레이션처럼 높이에 맞춰 축소되는 경우)에서 다시 재보니 줄마다
  // 오차가 꾸준히 쌓여서 마지막 줄 기준 7~10px까지 벌어지는 걸 확인함. 원인은 Flutter가
  // TextStyle.height로 정해지는 줄 높이를 정수 px로 올림 처리해서인 걸로 보이는데(실제
  // 필요한 줄 높이가 소수점이면 scale!=1일 때마다 반올림 오차가 줄마다 누적됨), 그래서
  // 아예 글자 줄마다 자동 줄간격에 맡기지 않고 이 선 좌표 리스트에 직접 앉히는 쪽으로
  // 바꿈(_ruleYForLine 참고). 인덱스는 선 번호고, 값은 874 기준 y좌표임
  static const List<double> _letterRuleYRef = [
    35.709,
    63.683,
    91.707,
    119.686,
    147.703,
    175.690,
    203.700,
    231.696,
    259.696,
    287.698,
    315.693,
    343.703,
    371.690,
    399.707,
    427.687,
    455.709,
    483.682,
  ];
  // 폰트 크기/아이콘 크기/문단 여백도 배경 기준(874x520) 레퍼런스 값. 배경이랑 똑같은
  // scale로 키워야, 배경 줄 간격이 늘어나거나 줄어들 때 글자도 같이 늘어나거나 줄어들어서
  // 계속 줄에 맞음
  static const double _letterFontSizeRef = 14;
  static const double _letterIconSizeRef = 20;
  static const double _letterParagraphGapRef = 28;
  // 마지막 줄 아래 최소 여백(레퍼런스 기준) - 글자 아랫부분이 화면 끝에 바로 닿지
  // 않게 조금 띄워두는 값. 측정값이 아니라 다른 여백들(85, 36)이랑 비슷한 크기로
  // 잡은 디자인 값임
  static const double _letterBottomPaddingRef = 24;
  // letter_bg.png 가장자리(종이 바깥 크림색 배경) 픽셀을 직접 스캔해서 뽑은 색.
  // 화면을 cover보다 작은 스케일로 줄였을 때 남는 빈 공간을 이 색으로 채워서, 종이
  // 가장자리랑 이어져 보이게 함(흰색이면 거기만 튀어 보임)
  static const Color _letterBgColor = Color(0xFFFFF8E6);

  // 편지 원문. 원본엔 12번째 줄("사랑해, 우리 채온.") 앞에 문단 구분용 빈 줄이 있었는데,
  // 그건 별도 탭 없이 렌더링할 때 인덱스 11부터 선 하나를 건너뛰고 앉히는 걸로 처리함
  // (_ruleYForLine 참고)
  static const List<String> _letterLines = [
    '채온아,',
    '이 편지를 쓰는 지금, 엄마는 네가 자는 걸 보고 있어.',
    '조용히 숨을 쉬고, 작은 손을 꼭 쥐고 자는 너를 보면서',
    '엄마는 한참을 울었단다.',
    '엄마가 곁에 없어도, 너무 무서워하지 마.',
    '네가 아침에 눈을 뜰 때도, 밥을 먹을 때도, 혼자서 긴 하루를 버텨낼 때도,',
    '엄마는 항상 네 옆에 있을 거야.',
    '보이지 않아도, 항상.',
    '채온아, 엄마한테 너는 너무나도 소중한 채온이야.',
    '강한 날도, 너무 힘들어서 무너지는 날도, 엄마 눈엔 언제나 똑같이 소중해.',
    '어떤 모습이어도, 엄마가 너를 사랑하는 마음은 변하지 않아.',
    '사랑해, 우리 채온.',
    '엄마가.',
  ];

  // 지금까지 공개된 줄 수. 처음엔 1줄만 보이다가 탭할 때마다 하나씩 늘어남
  int _revealedCount = 1;

  void _handleTap() {
    if (_revealedCount < _letterLines.length) {
      setState(() => _revealedCount++);
    } else {
      // 마지막 줄까지 다 공개된 상태에서 한 번 더 탭하면 여기서 끝
      widget.onComplete();
    }
  }

  // 줄 인덱스 -> 그 줄이 앉아야 할 선 번호(_letterRuleYRef 인덱스). 인덱스 11("사랑해,
  // 우리 채온.")부터는 문단 구분용 빈 줄 때문에 선 하나(11번)를 건너뛰고 12번 선에
  // 앉아야 해서 +1을 해줌. 그 전까지는 줄 인덱스랑 선 번호가 그대로 1:1로 맞음
  static double _ruleYForLine(int lineIndex) =>
      _letterRuleYRef[lineIndex <= 10 ? lineIndex : lineIndex + 1];

  // 편지 13줄(+문단 여백) 전체를 주어진 컬럼 폭/글자 크기로 실제로 줄바꿈했을 때 총
  // 높이가 얼마나 나오는지 TextPainter로 직접 측정함. _revealedCount랑 상관없이 항상
  // 전체 줄 기준으로 재는 이유: 화면 스케일이 "지금 몇 줄째 보이는지"에 따라 들쭉날쭉
  // 바뀌면 탭할 때마다 종이 크기가 변하는 것처럼 보이니까, 편지를 펼친 순간부터 끝까지
  // 스케일은 한 번 정해지면 고정돼야 함. columnWidth/fontSize 단위는 호출하는 쪽에서
  // 맞춰서 넘기면 됨(레퍼런스 단위든 실제 화면 px든 상관없이 똑같이 동작함)
  double _measureFullLetterHeight({
    required double columnWidth,
    required double fontSize,
  }) {
    final TextStyle style = TextStyle(
      fontFamily: 'SCDream',
      fontWeight: FontWeight.w500,
      fontSize: fontSize,
      height: 2.02,
    );
    final double scaleForGap = fontSize / _letterFontSizeRef;
    double total = 0;
    for (var i = 0; i < _letterLines.length; i++) {
      if (i == 11) total += _letterParagraphGapRef * scaleForGap;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: _letterLines[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: columnWidth);
      total += tp.height;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // 배경이 화면을 항상 꽉 채워야 해서(BoxFit.cover랑 동일한 효과) min이 아니라 max를
    // 씀 - min을 쓰면 화면 비율이 874x520이랑 많이 다를 때(예: 아주 가로로 넓은 창)
    // 한쪽 축만 꽉 차고 반대 축엔 빈 공간이 남음. max를 쓰면 더 많이 늘려야 하는 쪽
    // 기준으로 맞춰서 반대 축은 화면 밖으로 넘치게(=잘리게) 되니까 항상 꽉 참. 다만
    // 이 스케일 그대로 쓰면 화면이 가로로 넓고 세로는 짧을 때(예: 874x402) 종이가
    // 세로로 잘려서 마지막 줄이 화면 밖으로 밀려날 수 있음 - 그래서 이 값은 "화면을
    // 덮는 데 필요한 스케일" 후보로만 쓰고, 실제로 쓸 스케일은 아래에서 정함
    final double coverScale = math.max(w / _bgRefWidth, h / _bgRefHeight);

    // coverScale을 그대로 썼을 때 실제로 쓰일 가로 앵커/글자 컬럼 폭을 먼저 구해봄(글자
    // 시작 지점이 화면 밖으로 안 밀리게 보호하는 로직 - 화면이 세로로 많이 길어서 양옆이
    // 심하게 잘리면 가운데 정렬로는 글자 시작 지점(85)까지 화면 밖으로 밀려나서, "글자
    // 시작 x가 화면 안에 들어오는 선"까지만 가운데에서 오른쪽으로 밀어줌)
    final double centeredAnchorXAtCover = (w - _bgRefWidth * coverScale) / 2;
    // 원래 하한은 "글자 시작 x >= 0"(안 잘리기만 하면 OK)이었는데, 아이패드 프로
    // 13(1376x1032)처럼 편지지 비율(874:520)이랑 많이 다른(정사각형에 가까운) 화면에서
    // 하한이 딱 0에 걸려서 글자가 화면 왼쪽 끝에 바로 붙어버리는 걸 확인함. 그래서 하한을
    // "0 이상"이 아니라 "화면 가로폭의 5% 이상"으로 올림 - 이 비율만큼은 최소한 보장함.
    // (참고: 이 하한을 올려도 편지지 오른쪽 끝이 화면 안으로 들어오는 일(오른쪽 빈 틈)은
    // 생길 수 없음 - coverScale 자체가 "874*coverScale >= w"를 항상 보장해서, anchorX를
    // 오른쪽으로 밀수록 편지지 오른쪽 끝(anchorX + 874*coverScale)은 w에서 더 멀어지기만
    // 함. 그래서 따로 오른쪽 틈 방지용 상한은 안 둬도 됨)
    final double clampedAnchorXAtCover = math.max(
      centeredAnchorXAtCover,
      w * _letterMinLeftMarginRatio - _letterStartXRef * coverScale,
    );
    final double columnWidthAtCover =
        w - 2 * (clampedAnchorXAtCover + _letterStartXRef * coverScale);
    // coverScale로 실제 렌더될 컬럼 폭/글자 크기 기준으로 편지 전체(13줄) 높이를 재서,
    // 첫 줄 시작 지점부터 마지막 줄 아래 여백까지 화면 높이 안에 들어오는지 확인함
    final double neededHeightAtCover =
        _letterStartYRef * coverScale +
        _measureFullLetterHeight(
          columnWidth: columnWidthAtCover,
          fontSize: _letterFontSizeRef * coverScale,
        ) +
        _letterBottomPaddingRef * coverScale;

    final double scale;
    final double bgAnchorX;
    if (neededHeightAtCover <= h) {
      // (a) cover 스케일 그대로 써도 첫 줄부터 마지막 줄까지 다 들어옴 - 화면을
      // 최대한 꽉 채우는 쪽을 그대로 씀
      scale = coverScale;
      bgAnchorX = clampedAnchorXAtCover;
    } else {
      // (b) cover 스케일로는 마지막 줄이 화면 밖으로 밀려남 - 컬럼 폭을 레퍼런스
      // 그대로(874-85*2=704, 안 잘린 폭) 두고 쟀을 때의 높이를 기준으로, 화면 높이
      // 안에 꼭 맞는 스케일을 새로 구함. 그리고 이 스케일을 w/_bgRefWidth로 한 번 더
      // 묶어서 종이 가로폭이 화면보다 커지는 일 자체가 없게 함 - 그래야 글자 컬럼도
      // 항상 이 레퍼런스 폭(704) 그대로 나와서 방금 잰 높이랑 어긋나지 않고, 가로로
      // 잘릴 일도 없어서 글자 보호용 가로 클램프도 따로 필요 없어짐
      final double idealContentHeight = _measureFullLetterHeight(
        columnWidth: _bgRefWidth - 2 * _letterStartXRef,
        fontSize: _letterFontSizeRef,
      );
      final double neededRefHeight =
          _letterStartYRef + idealContentHeight + _letterBottomPaddingRef;
      final double heightFitScale = h / neededRefHeight;
      scale = math.min(heightFitScale, w / _bgRefWidth);
      // scale이 항상 w/_bgRefWidth 이하로 묶여 있어서 이 값은 절대 음수가 안 됨
      bgAnchorX = (w - _bgRefWidth * scale) / 2;
    }
    // 세로는 가운데 정렬이 아니라 항상 위쪽을 고정함 - 편지는 늘 첫 줄("채온아,")부터
    // 보여야 하니까, 종이가 화면보다 작든 크든 위쪽 기준으로 두고 남는/잘리는 공간은
    // 전부 아래쪽에 두는 게 맞음
    final double bgAnchorY = 0.0;
    final double letterStartX = bgAnchorX + _letterStartXRef * scale;
    // 오른쪽 여백은 시작 지점(85)과 대칭이라고 보고 그대로 미러링함
    final double letterEndMargin = bgAnchorX + _letterStartXRef * scale;
    // 배경 기준(874x520) 픽셀을 실제 화면 픽셀로 옮길 때 쓰는 배율. 폰트/아이콘/문단
    // 여백도 이걸로 키워야 배경 줄 간격이랑 계속 맞음
    double bgScale(double px) => px * scale;

    final textStyle = TextStyle(
      fontFamily: 'SCDream',
      fontWeight: FontWeight.w500,
      fontSize: bgScale(_letterFontSizeRef),
      height: 2.02,
      color: const Color(0xFF451805),
    );

    // 공개된 줄마다 선 좌표(_ruleYForLine)에 스케일만 곱해서 직접 Positioned로 앉힘.
    // Column + TextStyle.height 자동 줄간격으로 쌓으면 scale이 1이 아닐 때 줄마다
    // 생기는 반올림 오차가 누적되길래(위 _letterRuleYRef 주석 참고), 아예 줄마다
    // 독립적으로 선 좌표에 고정하는 쪽으로 바꿈 - 이러면 앞줄 오차가 뒷줄로 안 번짐.
    // 제일 마지막 줄에만 진행 안내 아이콘을 붙여줌
    final lineWidgets = <Widget>[
      for (var i = 0; i < _revealedCount; i++)
        Positioned(
          left: letterStartX,
          top: bgAnchorY + _ruleYForLine(i) * scale,
          right: letterEndMargin,
          child: i == _revealedCount - 1
              ? Text.rich(
                  TextSpan(
                    style: textStyle,
                    children: [
                      TextSpan(text: _letterLines[i]),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: const Color(0xFF451805),
                          size: bgScale(_letterIconSizeRef),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(_letterLines[i], style: textStyle),
        ),
    ];

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: w,
        height: h,
        // (b) 스케일을 쓰면 종이가 화면보다 작아져서 옆/아래에 빈 공간이 생기는데,
        // 흰색 대신 이 색(letter_bg.png 가장자리 색)으로 채워서 종이 바깥이랑
        // 이어져 보이게 함
        color: _letterBgColor,
        child: Stack(
          children: [
            Positioned(
              left: bgAnchorX,
              top: bgAnchorY,
              width: _bgRefWidth * scale,
              height: _bgRefHeight * scale,
              // 이 박스 크기 자체가 이미 원본 비율(874:520)을 그대로 유지한 채 계산된
              // 거라 fit은 안 줘도 되지만, Stack이 화면을 벗어나는 부분을 잘라내는
              // 걸 명확히 하려고 fill로 명시해둠(비율이 같아서 fill이든 cover든 결과는 동일)
              child: Image.asset(
                'assets/images/letter_bg.png',
                fit: BoxFit.fill,
              ),
            ),
            ...lineWidgets,
          ],
        ),
      ),
    );
  }
}
