// lib/features/chapter1/game_play_widgets.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';

// table.json a분기(먹는 대사, 온도 -1 구간)에서 전체화면 클로즈업으로 보여줄 노드.
// line_004a1(대사 끝)~line_004a2(다음 대사 시작) 사이에 넣은 빈 대사 노드 동안만 보여줌
const List<String> eatingCloseupNodeIdsA = ['line_004a1_eat'];
// table.json b분기(먹는 대사, 온도 +1 구간)에서 전체화면 클로즈업으로 보여줄 노드.
// line_004b2(대사 끝)~line_004b3(다음 대사 시작) 사이에 넣은 빈 대사 노드 동안만 보여줌
const List<String> eatingCloseupNodeIdsB = ['line_004b_eat'];

// 채온이 빵 먹는 장면에서 전체화면 클로즈업으로 보여주는 이미지. 분기와 상관없이 항상 동일한 2프레임 번갈이
const List<String> eatingCloseupFrames = [
  'assets/images/chaeon_eating_1.png',
  'assets/images/chaeon_eating_2.png',
];

// 채온이가 빵을 먹으면서 감정 온도가 오르는 진행 단계별 GIF(0%->20%->50%->80%).
// kitchen_screen.dart/game_play_screen.dart 양쪽에서 채온이 스프라이트를 그릴 때, 이
// 목록에 있는 에셋으로 전환될 땐 PopInImage 크로스페이드 없이 즉시(duration: Duration.zero)
// 바뀌어야 함 — 자세 차이가 커서(예: 팔이 올라가는 중간 프레임이 흐릿하게 겹쳐 보임)
// 페이드를 걸면 어색해 보임
const List<String> chaeonEatingSprites = [
  'assets/images/chaeon_0_eat.gif',
  'assets/images/chaeon_20_eat.gif',
  'assets/images/chaeon_50_eat.gif',
  'assets/images/chaeon_80_eat.gif',
];

// chaeonSpriteOverrides 항목 하나. beforeReveal은 말풍선 뜨기 전(GIF 재생 중)에 보여줄 에셋이고,
// afterReveal은 말풍선이 뜬 순간부터 바꿔줄 에셋. afterReveal이 없으면 그 시점부턴 기본 idle로 폴백.
// verticalOffsetPx는 그 에셋이 기본 idle 이미지 대비 세로로 어긋나 보일 때 보정하는 값(위로 보정하려면 음수)
class ChaeonSpriteOverride {
  const ChaeonSpriteOverride({
    required this.beforeReveal,
    this.beforeRevealVerticalOffsetPx = 0,
    this.afterReveal,
    this.afterRevealVerticalOffsetPx = 0,
  });

  final String beforeReveal;
  final double beforeRevealVerticalOffsetPx;
  final String? afterReveal;
  final double afterRevealVerticalOffsetPx;
}

// first_bread.json 특정 노드에 머무는 동안만 채온이 스프라이트를 잠깐 바꿔주는 매핑.
// 여기 없는 노드거나 first_bread.json 단계가 아니면 기존 idle/holding_bread 로직을 그대로 씀.
// 주의: table.json도 line_001/line_002 같은 같은 이름의 노드 ID를 쓰므로, 이 맵은 반드시
// DialoguePhase.firstBread일 때만 참조해야 함 (game_play_screen.dart 쪽에서 처리)
const Map<String, ChaeonSpriteOverride> chaeonSpriteOverrides = {
  'line_001': ChaeonSpriteOverride(
    beforeReveal: 'assets/images/chaeon_emotion_0to100.gif',
    afterReveal: 'assets/images/chaeon_emotion_reveal.gif',
  ),
  'line_002': ChaeonSpriteOverride(
    beforeReveal: 'assets/images/chaeon_emotion_100to0.gif',
  ),
};

// first_meet.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// eat/cry 노드는 대사 없이 GIF만 한 번 재생되고 끝나면 자동으로 다음 노드로 넘어가고,
// a7/a8 노드는 crying 정지 이미지를 대사가 있는 동안 계속 보여줌.
// 여기 없는 노드거나 first_meet.json 단계가 아니면 기존 idle/walk 로직을 그대로 씀
const Map<String, String> lillianSpriteOverrides = {
  'line_003b1': 'assets/images/lillian_happy.png',
  'line_010a1': 'assets/images/lillian_grieve.png',
  'line_010b1': 'assets/images/lillian_grudge.png',
  'line_017': 'assets/images/lillian_grudge.png',
  'line_018a1': 'assets/images/lillian_surprise.png',
  'line_018b1': 'assets/images/lillian_happy.png',
  'line_029a1': 'assets/images/lillian_surprise.png',
  'line_029a2': 'assets/images/lillian_surprise.png',
  'line_029a3': 'assets/images/lillian_thinking2.png',
  'line_029a6_eat': 'assets/images/lillian_eating_bread.gif',
  'line_029a6_cry': 'assets/images/lillian_crying.gif',
  'line_029a7': 'assets/images/lillian_cry.gif',
  'line_029a8': 'assets/images/lillian_cry.gif',
  'line_029b2': 'assets/images/lillian_happy.png',
};

// table.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// table.json도 line_001/choice_001 같은 노드 ID를 first_meet.json과 공유하므로,
// lillianSpriteOverrides와 합치지 않고 별도 맵으로 분리함 (DialoguePhase.table일 때만 참조)
const Map<String, String> tableLillianSpriteOverrides = {
  'line_004a2': 'assets/images/lillian_surprise.png',
  'line_004a3': 'assets/images/lillian_surprise.png',
  'line_004a4': 'assets/images/lillian_thinking2.png',
};

// first_bread.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// first_bread.json도 line_001/line_002 같은 노드 ID를 table.json과 공유하므로,
// 다른 오버라이드 맵과 합치지 않고 별도 맵으로 분리함 (DialoguePhase.firstBread일 때만 참조)
const Map<String, String> firstBreadLillianSpriteOverrides = {
  'line_008': 'assets/images/lillian_happy.png',
  'line_018': 'assets/images/lillian_thinking3.png',
  'line_022b9': 'assets/images/lillian_happy.png',
  'line_026': 'assets/images/lillian_grudge.png',
};

// kitchen_arrival.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// kitchen_screen.dart는 chapter2_ready.json과도 line_002 같은 노드 ID를 공유하므로,
// 반드시 KitchenScreenMode.chapter1End(kitchen_arrival.json 로드 중)일 때만 참조해야 함
const Map<String, String> kitchenArrivalLillianSpriteOverrides = {
  'line_002': 'assets/images/lillian_happy.png',
};

// chapter2_ready.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// 다른 챕터2 대화 파일(chapter2_after_quiz.json 등)도 line_003b1 같은 노드 ID를 공유할 수
// 있어서, 반드시 현재 로드된 대화가 chapter2_ready.json일 때만 참조해야 함
const Map<String, String> chapter2ReadyLillianSpriteOverrides = {
  'line_003b1': 'assets/images/lillian_grieve.png',
  'line_003b5': 'assets/images/lillian_happy.png',
  'line_003a7': 'assets/images/lillian_happy.png',
  'line_011': 'assets/images/lillian_happy.png',
  'line_013': 'assets/images/lillian_thinking2.png',
  'line_017': 'assets/images/lillian_thinking3.png',
  'line_019': 'assets/images/lillian_happy.png',
  'line_021a': 'assets/images/lillian_surprise.png',
  'line_021a1': 'assets/images/lillian_grudge.png',
  'line_021b': 'assets/images/lillian_happy.png',
  'line_021b1': 'assets/images/lillian_happy.png',
  'line_021b2': 'assets/images/lillian_happy.png',
  'line_021b6': 'assets/images/lillian_thinking2.png',
};

// chapter2_ingredient_quiz.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는
// 매핑. 다른 챕터2 대화 파일들도 같은 노드 ID를 공유할 수 있어서, 반드시 현재 로드된 대화가
// chapter2_ingredient_quiz.json일 때만 참조해야 함
const Map<String, String> chapter2IngredientQuizLillianSpriteOverrides = {
  'line_q1a2': 'assets/images/lillian_happy.png',
  'line_q1b2': 'assets/images/lillian_happy.png',
  'line_q1c3': 'assets/images/lillian_happy.png',
  'line_q2a4': 'assets/images/lillian_surprise.png',
  'line_q2b2': 'assets/images/lillian_surprise.png',
  'line_q2c2': 'assets/images/lillian_thinking3.png',
};

// chapter2_after_quiz.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// 다른 챕터2 대화 파일들도 같은 노드 ID를 공유할 수 있어서, 반드시 현재 로드된 대화가
// chapter2_after_quiz.json일 때만 참조해야 함
const Map<String, String> chapter2AfterQuizLillianSpriteOverrides = {
  'line_002b1': 'assets/images/lillian_thinking1.png',
  'line_002a3': 'assets/images/lillian_happy.png',
  'line_010': 'assets/images/lillian_thinking3.png',
  'line_017': 'assets/images/lillian_happy.png',
  'line_019a3': 'assets/images/lillian_happy.png',
  'line_019b2': 'assets/images/lillian_thinking2.png',
  'line_019b9': 'assets/images/lillian_happy.png',
};

// chapter2_after_first_game.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는
// 매핑. 다른 챕터2 대화 파일들도 같은 노드 ID를 공유할 수 있어서, 반드시 현재 로드된 대화가
// chapter2_after_first_game.json일 때만 참조해야 함
const Map<String, String> chapter2AfterFirstGameLillianSpriteOverrides = {
  'line_001': 'assets/images/lillian_happy.png',
  'line_003a3': 'assets/images/lillian_happy.png',
  'line_003b3': 'assets/images/lillian_happy.png',
};

// chapter2_after_second_game.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는
// 매핑. 다른 챕터2 대화 파일들도 같은 노드 ID를 공유할 수 있어서, 반드시 현재 로드된 대화가
// chapter2_after_second_game.json일 때만 참조해야 함
const Map<String, String> chapter2AfterSecondGameLillianSpriteOverrides = {
  'line_006': 'assets/images/lillian_happy.png',
};

// 챕터2 대화 파일별 릴리안 스프라이트 오버라이드 맵을 dialogueId로 바로 찾을 수 있게 묶어둠.
// 파일이 늘어날 때마다 kitchen_screen.dart의 _resolveLillianSprite에 else-if를 추가하는 대신
// 여기에 한 줄만 추가하면 됨
const Map<String, Map<String, String>>
chapter2LillianSpriteOverridesByDialogueId = {
  'chapter2_ready': chapter2ReadyLillianSpriteOverrides,
  'chapter2_ingredient_quiz': chapter2IngredientQuizLillianSpriteOverrides,
  'chapter2_after_quiz': chapter2AfterQuizLillianSpriteOverrides,
  'chapter2_after_first_game': chapter2AfterFirstGameLillianSpriteOverrides,
  'chapter2_after_second_game': chapter2AfterSecondGameLillianSpriteOverrides,
};

class EatingCloseupOverlay extends StatefulWidget {
  const EatingCloseupOverlay({super.key, this.onFinished, this.repeatCount = 1});

  // eating_1 -> eating_2 순서로 한 번씩 보여준 뒤 호출되는 콜백 (다음 대사로 자동 진행용)
  final VoidCallback? onFinished;
  // eating_1 -> eating_2 사이클을 몇 번 반복할지 (기본 1번)
  final int repeatCount;

  @override
  State<EatingCloseupOverlay> createState() => _EatingCloseupOverlayState();
}

class _EatingCloseupOverlayState extends State<EatingCloseupOverlay> {
  static const Duration _frame1HoldDuration = Duration(milliseconds: 500);
  static const Duration _crossfadeDuration = Duration(milliseconds: 600);
  static const Duration _frame2HoldDuration = Duration(milliseconds: 500);

  int _frameIndex = 0;
  int _completedCycles = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _playCycle();
  }

  // eating_1을 500ms 그대로 보여준 뒤 eating_2로 전환. 크로스페이드(600ms) + eating_2
  // 유지(500ms)까지 끝나면 한 사이클 완료. repeatCount만큼 다 돌면 완료 콜백 호출,
  // 아니면 eating_1로 되돌아가 다시 반복
  void _playCycle() {
    _timer = Timer(_frame1HoldDuration, () {
      if (!mounted) return;
      setState(() => _frameIndex = 1);
      _timer = Timer(_crossfadeDuration + _frame2HoldDuration, () {
        if (!mounted) return;
        _completedCycles++;
        if (_completedCycles >= widget.repeatCount) {
          widget.onFinished?.call();
        } else {
          setState(() => _frameIndex = 0);
          _playCycle();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      // 화면을 꽉 채우도록 BoxFit.cover 적용. AnimatedSwitcher(양쪽 다 반투명해지는 크로스페이드)
      // 대신 PopInImage를 써서, 검은 배경 위에서 두 이미지가 동시에 옅어지며 검은 화면이
      // 살짝 비치는("번쩍") 현상 없이 새 프레임만 이전 프레임 위에서 페이드인되게 함
      child: PopInImage(
        imagePath: eatingCloseupFrames[_frameIndex],
        duration: _crossfadeDuration,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

// main_dialogue_box_1~9.png의 원본 가로 크기(px). 전부 높이는 60으로 고정.
const List<double> dialogueBoxWidths = [
  107,
  147,
  188,
  232,
  274,
  317,
  361,
  404,
  451,
];

Widget buildInteractionBox({
  required String text,
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  return CenteredDialogueBox(
    key: const ValueKey('interaction_box'),
    textWidget: Text(
      text,
      textAlign: TextAlign.center,
      style: dialogueTextStyle(rW),
    ),
    rW: rW,
    rH: rH,
  );
}

// 온도계 위젯 (암전 레이어 위/아래 두 슬롯에서 재사용)
Widget buildThermometer({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required int temperature,
  required String? temperatureChangeText,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(7),
    top: rH(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/main_thermometer_$temperature.png',
          gaplessPlayback: true,
          width: rW(422),
          fit: BoxFit.contain,
        ),
        if (temperatureChangeText != null) ...[
          SizedBox(height: rH(5)),
          Padding(
            padding: EdgeInsets.only(left: rW(77)),
            child: buildBlackRoundedBadge(
              temperatureChangeText,
              rW: rW,
              rH: rH,
            ),
          ),
        ],
      ],
    ),
  );
}

// 검은 반투명 배경에 둥근 모서리 흰 글씨 안내 배지. 선택지 되돌리기 불가 안내용으로만 쓰임
Widget buildBlackRoundedBadge(
  String text, {
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  return Container(
    width: rW(210),
    height: rH(30),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(rW(26)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: rW(12),
        fontWeight: FontWeight.w300,
        fontFamily: 'SCDream',
      ),
    ),
  );
}

// 저장 완료 안내 배지("저장되었습니다" 등). buildBlackRoundedBadge보다 딤을 더 진하게(0.7)
// 주려고 따로 뺌 - buildBlackRoundedBadge는 다른 데서도 같이 쓰고 있어서 그쪽 opacity를
// 그냥 올리면 거기도 다 같이 진해짐. kitchen_screen.dart/chaeon_room_screen.dart/
// game_play_screen.dart 저장 버튼이 전부 이걸 재사용함
Widget buildSaveConfirmationBadge(
  String text, {
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  return Container(
    width: rW(210),
    height: rH(30),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(rW(26)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: rW(12),
        fontWeight: FontWeight.w300,
        fontFamily: 'SCDream',
      ),
    ),
  );
}

// 뒤로가기 버튼
Widget buildBackButton({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required VoidCallback onTap,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(714),
    top: rH(15),
    child: GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/main_back_btn.png',
        width: rW(54),
        height: rH(54),
        fit: BoxFit.contain,
      ),
    ),
  );
}

// 설정(메뉴) 버튼
Widget buildSettingButton({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required VoidCallback onTap,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(788), // 뒤로가기 버튼(714) + 너비(54) + 간격(20)
    top: rH(15),
    child: GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/main_setting_btn.png',
        width: rW(54),
        height: rH(54),
        fit: BoxFit.contain,
      ),
    ),
  );
}

// 커스텀 대사창 레이아웃 빌더
Widget buildCustomDialogue({
  required String key,
  required int step,
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  List<TextSpan> spans = [];
  if (step == 0) {
    spans = [
      const TextSpan(text: "지금부터 감정의 온도를 확인할 수 있습니다.\n"),
      const TextSpan(
        text: "당신의 선택에 따라 ",
        style: TextStyle(color: Color(0xFFFF7100), fontWeight: FontWeight.w600),
      ),
      const TextSpan(text: "감정의 온도는 오를수도, 내려갈 수도 있습니다."),
    ];
  } else {
    spans = [
      const TextSpan(text: "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 "),
      const TextSpan(
        text: "선택은 돌릴 수 없습니다.",
        style: TextStyle(color: Color(0xFFFF7100), fontWeight: FontWeight.w600),
      ),
    ];
  }

  return Positioned(
    key: ValueKey(key),
    left: step == 0 ? rW(26) : null,
    right: step == 0 ? null : rW(32),
    top: rH(75),
    child: DialogueBoxFrame(
      textWidget: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(style: dialogueTextStyle(rW), children: spans),
      ),
      rW: rW,
      rH: rH,
    ),
  );
}

// spriteTopY 기준으로 말풍선을 배치하는 화면(kitchen_screen.dart)에서, 캐릭터가 화면
// 위쪽에 서 있을 때 말풍선이 온도계(buildThermometer, top: rH(15))랑 겹치지 않게 두는
// 최소 top값. 온도계 이미지 실측(main_thermometer_*.png 1688x204, rW(422)로 렌더 시
// 종횡비상 높이 약 rW(51)) + top(15) + 온도 변화 배지 있을 때 간격(5)+배지 높이(30)를
// 전부 더한 값(15+51+5+30=101) - 배지가 없을 때도 이 값 그대로 써서 항상 안전하게 잡음
const double kSceneBubbleMinTopRef = 101;

// 채온-릴리안 말풍선. 대사 길이에 맞는 가장 작은 이미지 골라서 top 100, 말하는 캐릭터 중심에 표시. 채온이면 좌우 반전.
Widget buildSceneBubble({
  required DialogueNode node,
  required double Function(double) rW,
  required double Function(double) rH,
  required double chaeonCenterX,
  required double lillianCenterX,
  required int typedCharCount,
  int? charCount,
  // 캐릭터 스프라이트 top의 화면 절대좌표(px). 주어지면 그 위치 바로 위에 말풍선을 띄움.
  // 안 주어지면(기존 game_play_screen.dart처럼 캐릭터가 항상 화면 하단에 고정 배치되는 화면)
  // 기존처럼 rH(100 + chaeonTopExtra) 고정값을 씀
  double? chaeonSpriteTopY,
  double? lillianSpriteTopY,
}) {
  final bool isChaeon = node.speaker == 'chaeon';
  final double centerX = isChaeon ? chaeonCenterX : lillianCenterX;
  final double? spriteTopY = isChaeon ? chaeonSpriteTopY : lillianSpriteTopY;
  final bool isLargeText = node.spans.any((s) => s.size == 18);

  final TextStyle baseStyle = TextStyle(
    color: const Color(0xFF5A3E2B),
    fontSize: rW(13),
    height: 1.1,
    fontWeight: FontWeight.w500,
    fontFamily: 'SCDream',
  );

  InlineSpan spanToInline(DialogueSpan s) => TextSpan(
    text: s.text,
    style: baseStyle.copyWith(
      color: s.color ?? baseStyle.color,
      fontWeight: s.bold ? FontWeight.w700 : baseStyle.fontWeight,
      fontSize: s.size != null ? rW(s.size!) : baseStyle.fontSize,
    ),
  );

  // 말풍선 크기는 전체 대사 기준으로 고정
  final List<InlineSpan> fullSpans = node.spans.map(spanToInline).toList();
  final TextPainter tp = TextPainter(
    text: TextSpan(children: fullSpans),
    textDirection: TextDirection.ltr,
  )..layout();

  // 실제로 그리는 텍스트는 타이핑 진행도만큼만 잘라서 표시
  final List<InlineSpan> visibleSpans = SceneDialogueController.truncateSpans(
    node.spans,
    charCount ?? typedCharCount,
  ).map(spanToInline).toList();

  // 여백 뺀 안쪽 공간에 텍스트 들어가는 가장 작은 말풍선 선택, 안 들어가면 제일 큰 걸로
  const double nativeHorizontalPadding = 24;
  int boxIndex = dialogueBoxWidths.length;
  for (int i = 0; i < dialogueBoxWidths.length; i++) {
    double boxWidthPx = rW(dialogueBoxWidths[i]);
    double availableWidth = boxWidthPx - rW(nativeHorizontalPadding * 2);
    if (tp.width <= availableWidth) {
      boxIndex = i + 1;
      break;
    }
  }

  final double bubbleWidth = rW(dialogueBoxWidths[boxIndex - 1]);
  // 말풍선 높이는 원본 이미지가 전부 60px이므로 rW 기준으로 고정
  final double bubbleHeight = rW(60);

  Widget bubbleImage = Image.asset(
    'assets/images/main_dialogue_box_$boxIndex.png',
    gaplessPlayback: true,
    width: bubbleWidth,
    height: bubbleHeight,
    fit: BoxFit.fill,
  );
  if (isChaeon) {
    bubbleImage = Transform.flip(flipX: true, child: bubbleImage);
  }

  // 채온 말풍선이면 top을 20px 더 내려서 릴리안 말풍선과 겹치지 않게 함
  final double chaeonTopExtra = isChaeon ? 20 : 0;

  // spriteTopY가 주어졌으면 그 캐릭터 머리 위로 헤드갭만큼 띄운 위치에 배치,
  // 아니면 기존 고정값(rH(100 + chaeonTopExtra))을 그대로 씀. 릴리안은 20, 채온이는 그 절반인 10
  final double headGap = isChaeon ? 10 : 20;
  final double bubbleTop = spriteTopY != null
      // 캐릭터가 화면 위쪽에 있으면 계산 결과가 온도계 영역까지 올라갈 수 있어서,
      // kSceneBubbleMinTopRef보다 위로는 못 올라가게 최소값을 강제함(fallback 분기는
      // 이미 화면 하단 고정값이라 이 문제 자체가 없어서 그쪽엔 안 건드림)
      ? math.max(spriteTopY - bubbleHeight - rH(headGap), rH(kSceneBubbleMinTopRef))
      : rH(100 + chaeonTopExtra);

  return Positioned(
    key: ValueKey('scene_bubble_${node.id}'),
    left: centerX - bubbleWidth / 2,
    top: bubbleTop,
    width: bubbleWidth,
    height: bubbleHeight,
    child: Stack(
      children: [
        bubbleImage,
        // 대사 텍스트: 말풍선 기준 bottom 24, 가로 가운데 정렬
        Positioned(
          left: rW(12),
          right: rW(12),
          bottom: isLargeText ? rW(25) : rW(28),
          child: RichText(
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: visibleSpans),
          ),
        ),
      ],
    ),
  );
}

// 선택지 화면. 검은 반투명(50%) 배경 위에 choice_box를 옵션 개수만큼 가로로 나열, 하단(35)에 표시
Widget buildSceneChoices({
  required DialogueNode node,
  required double Function(double) rW,
  required double Function(double) rH,
  required void Function(DialogueOption option) onChooseOption,
}) {
  const double nativeW = 1264;
  const double nativeH = 240;
  double boxHeight = rW(60);
  double boxWidth = boxHeight * (nativeW / nativeH);
  double gap = rW(16);

  // 옵션이 3개 이상이면 기존 크기 그대로는 화면 밖으로 넘쳐서(overflow) 잘려 보이므로,
  // 한 줄에 다 들어오도록 가로 폭과 간격만 축소함. boxHeight는 옵션 개수와 무관하게
  // 항상 동일하게 유지해서, 2개일 때와 3개일 때 박스 세로 길이가 달라지지 않도록 함
  final double maxRowWidth = rW(834);
  final double naturalRowWidth =
      boxWidth * node.options.length + gap * (node.options.length - 1);
  if (naturalRowWidth > maxRowWidth) {
    final double scale = maxRowWidth / naturalRowWidth;
    boxWidth *= scale;
    gap *= scale;
  }

  return Stack(
    key: ValueKey('scene_choices_${node.id}'),
    children: [
      Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),
      Positioned(
        left: 0,
        right: 0,
        bottom: rH(35),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < node.options.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                  child: GestureDetector(
                    onTap: () => onChooseOption(node.options[i]),
                    child: SizedBox(
                      width: boxWidth,
                      height: boxHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/choice_box.png',
                            width: boxWidth,
                            height: boxHeight,
                            fit: BoxFit.fill,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: rW(24)),
                            child: Text(
                              node.options[i].text,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: rW(14),
                                fontWeight: FontWeight.w400,
                                fontFamily: 'SCDream',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
