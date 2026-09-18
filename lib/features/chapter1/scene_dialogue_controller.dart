// lib/features/chapter1/scene_dialogue_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/dialogue_loader.dart';
import 'package:emotional_bakery/core/services/gif_duration.dart';
import 'package:emotional_bakery/core/services/story_state.dart';

// first_bread.json 전용 dialogue_id. table.json도 line_001/line_002를 같은 노드ID로 쓰므로, 노드ID만으로 지연 로직을 걸면 table.json에서도 오작동함
const String _bubbleDelayDialogueId = 'chapter1_first_bread';

// 이 노드 진입 시 GIF가 다 재생될 때까지 말풍선을 지연 표시함. game_play_widgets.dart의 chaeonSpriteOverrides와 같은 GIF를 가리키므로 값 변경 시 같이 맞출 것
const Map<String, String> _bubbleDelayGifByNodeId = {
  'line_001': 'assets/images/chaeon_emotion_0to100.gif',
  'line_002': 'assets/images/chaeon_emotion_100to0.gif',
};

// first_meet.json에서만 쓰는 dialogue_id
const String _autoAdvanceDialogueId = 'chapter1_first_meet';

// 이 노드는 GIF만 재생 후 탭 없이 자동으로 다음 노드로 넘어감. game_play_widgets.dart의 lillianSpriteOverrides와 같은 GIF를 가리키므로 값 변경 시 같이 맞출 것
const Map<String, String> _autoAdvanceGifByNodeId = {
  'line_029a6_eat': 'assets/images/lillian_eating_bread.gif',
  'line_029a6_cry': 'assets/images/lillian_crying.gif',
};

// 위 GIF들은 루프 전체 길이만큼 안 기다리고 여기 지정한 ms만큼만 보여준 뒤 다음 노드로 넘어감(여기 없는 노드는 GifDuration으로 실제 재생 시간을 잼). 노드별 노출 시간 조정 값
const Map<String, int> _autoAdvanceDurationOverrideMs = {
  'line_029a6_eat': 2000,
  'line_029a6_cry': 3000,
};

class SceneDialogueController extends ChangeNotifier {
  SceneDialogueController({
    required this.onDialogueEnd,
    required this.onLillianHop,
    required this.onChaeonHop,
    int initialTemperature = 3,
  }) : temperature = initialTemperature;

  final VoidCallback onDialogueEnd;
  final VoidCallback onLillianHop;
  final VoidCallback onChaeonHop;

  DialogueGraph? sceneDialogue;
  // loadDialogue()로 마지막으로 불러온 asset 경로. 저장/불러오기 체크포인트 판단용으로 씀 -
  // sceneDialogue는 대사가 끝나면 null로 비워지는데 이 필드는 그때도 안 지우고 그대로 둬서,
  // "마지막으로 재생된 파일이 뭐였는지"를 대사 종료 이후에도 계속 참조할 수 있게 함
  String? currentFilePath;
  String? sceneNodeId;
  // 선택지 노드로 넘어가도 그 직전 대사 말풍선을 검은 배경 아래에 계속 띄워두기 위해 따로 보관
  DialogueNode? lastLineNode;
  // 선택지 노드로 넘어가기 전까지 지나온 line 노드 히스토리. 뒤로가기 시 이걸 따라감
  final List<String> sceneNodeHistory = [];
  // 선택지를 한 번이라도 골랐는지. 골랐는데 히스토리가 비어서 더 못 돌아갈 때만 안내 배지를 띄움
  bool sceneHasLockedChoice = false;
  String? choiceLockedMessage;
  Timer? _choiceLockedMessageTimer;

  // 온도계 레벨. KitchenScreen처럼 다른 화면에서 이어받을 때는 initialTemperature로 시작값을 맞춤
  int temperature;
  String? temperatureChangeText;
  Timer? _temperatureChangeTimer;

  // 말풍선 타이핑 효과
  Timer? _typingTimer;
  int typedCharCount = 0;
  static const Duration _typingInterval = Duration(milliseconds: 50);

  // 말풍선 대기 중인지. line_001/line_002처럼 GIF가 먼저 끝나야 하는 노드에서만 잠깐 false가 됨
  bool bubbleRevealed = true;
  Timer? _bubbleRevealTimer;

  // GIF 종료 후 자동으로 다음 노드로 넘어가는 중인지. true인 동안은 탭해도 advanceScene이 무시함
  bool _autoAdvancePending = false;
  Timer? _autoAdvanceTimer;

  // 공용 메뉴 AUTO 토글용 타이머. line 노드 타이핑이 끝난 시점(또는 탭 스킵으로 끝난 시점)에
  // StoryState.isAutoAdvanceEnabled가 켜져 있으면 2초 뒤 advanceScene()을 대신 호출해줌.
  // 위 _autoAdvanceTimer(GIF 전용 자동진행)랑은 별개 필드라 서로 안 겹침
  Timer? _autoAdvanceModeTimer;

  // 대사 없는 연출용 노드는 타이핑할 글자가 없어 진입 즉시 "다 읽음"으로 판단돼 연속 탭에 순식간에 지나칠 수 있음
  // 이를 막기 위한 최소 노출 시간(현재 500ms, 조정 가능)
  bool _emptyNodeHoldElapsed = true;
  static const Duration _emptyNodeMinHold = Duration(milliseconds: 500);

  bool _isDisposed = false;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  // 주어진 경로의 대화 그래프를 불러와서 처음부터 재생 (first_meet/table/first_bread 등 공용)
  Future<void> loadDialogue(String assetPath) async {
    // sceneDialogue보다 먼저 기록해둠 - 아래서 await 끝나기 전에 disposed 되거나 해도
    // 마지막으로 "로드를 시도한" 경로는 남겨두는 게 저장 시스템 입장에서 더 안전함
    currentFilePath = assetPath;
    final graph = await DialogueLoader.loadDialogue(assetPath);
    if (_isDisposed) return;
    sceneDialogue = graph;
    sceneNodeHistory.clear();
    sceneHasLockedChoice = false;
    // 새 대화가 choice로 바로 시작하면 lastLineNode를 안 거쳐, 이전 대화의 마지막 대사가 선택지 버튼 뒤에 그대로 비쳐 보이는 걸 막기 위한 리셋
    lastLineNode = null;
    _enterSceneNode(graph.start);
    _notify();
  }

  void _enterSceneNode(String? nodeId) {
    _typingTimer?.cancel();
    _bubbleRevealTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _autoAdvanceModeTimer?.cancel();
    final graph = sceneDialogue;
    if (nodeId == null || graph == null || !graph.nodes.containsKey(nodeId)) {
      sceneNodeId = null;
      sceneDialogue = null;
      typedCharCount = 0;
      bubbleRevealed = true;
      _autoAdvancePending = false;
      onDialogueEnd();
      return;
    }
    sceneNodeId = nodeId;
    final node = _resolvePlaceholders(graph, nodeId);
    if (node.type == 'line') {
      lastLineNode = node;
      if (node.temperatureEffect != 0) {
        temperature = (temperature + node.temperatureEffect)
            .clamp(1, 10)
            .toInt();
        // 바뀔 때마다 바로 전역에 동기화해둬야, 이 화면이 dispose 안 되고 그냥 Navigator.push로
        // 다음 화면이 쌓이는 경우(예: GamePlayScreen -> KitchenScreen)에도 다음 화면이 최신
        // 값을 읽을 수 있음. dispose 시점에만 동기화하면 이런 케이스를 놓침
        StoryState.currentTemperature = temperature;
        _showTemperatureChange(node.temperatureEffect);
        // 선택지를 한 번이라도 골랐으면 되돌아갈 수 없게 히스토리 초기화
        sceneNodeHistory.clear();
        sceneHasLockedChoice = true;
      }
      if (node.animation == 'lillian_hop') {
        onLillianHop();
      } else if (node.animation == 'chaeon_hop') {
        onChaeonHop();
      }
      // first_bread.json의 line_001/line_002만 GIF 다 재생될 때까지 말풍선을 숨겨둠
      final String? delayGifAsset = graph.dialogueId == _bubbleDelayDialogueId
          ? _bubbleDelayGifByNodeId[nodeId]
          : null;
      // node.expression이나 node.chaeonExpression에 autoAdvance가 켜져 있으면 대사 없이
      // GIF만 재생 후 탭 없이 다음 노드로 넘어감
      // (예: first_meet.json의 line_029a6_eat/line_029a6_cry, table.json의 line_004a2_laugh)
      final DialogueExpression? autoAdvanceExpression =
          (node.expression != null && node.expression!.autoAdvance)
          ? node.expression
          : (node.chaeonExpression != null &&
                node.chaeonExpression!.autoAdvance)
          ? node.chaeonExpression
          : null;
      if (delayGifAsset != null) {
        bubbleRevealed = false;
        typedCharCount = 0;
        _waitForGifThenRevealBubble(delayGifAsset, node);
      } else if (autoAdvanceExpression != null) {
        bubbleRevealed = true;
        typedCharCount = 0;
        _autoAdvancePending = true;
        _waitForGifThenAutoAdvance(autoAdvanceExpression.asset, node);
      } else {
        bubbleRevealed = true;
        _startTypingEffect(node);
      }
    } else {
      typedCharCount = 0;
      bubbleRevealed = true;
      _autoAdvancePending = false;
    }
  }

  // {{ingredient}} 플레이스홀더를 실제 값으로 치환한 노드를 반환 (없으면 원본 그대로)
  // graph.nodes에 덮어써야 뒤로가기 등으로 같은 노드ID를 다시 조회해도 치환된 텍스트가 유지됨
  DialogueNode _resolvePlaceholders(DialogueGraph graph, String nodeId) {
    final node = graph.nodes[nodeId]!;
    if (node.type != 'line' || !node.spans.any((s) => s.text.contains('{{'))) {
      return node;
    }

    final String ingredientName = StoryState.resolveIngredientName() ?? '???';
    final resolvedSpans = node.spans
        .map(
          (s) => DialogueSpan(
            text: s.text.replaceAll('{{ingredient}}', ingredientName),
            color: s.color,
            bold: s.bold,
            size: s.size,
          ),
        )
        .toList();

    final resolvedNode = DialogueNode(
      id: node.id,
      type: node.type,
      speaker: node.speaker,
      spans: resolvedSpans,
      temperatureEffect: node.temperatureEffect,
      next: node.next,
      options: node.options,
      animation: node.animation,
      expression: node.expression,
      chaeonExpression: node.chaeonExpression,
    );
    graph.nodes[nodeId] = resolvedNode;
    return resolvedNode;
  }

  // GIF 재생 시간만큼 기다렸다가 말풍선 표시. 그 사이 다른 노드로 넘어갔으면(뒤로가기 등) 무시
  void _waitForGifThenRevealBubble(String gifAsset, DialogueNode node) async {
    final int durationMs = await GifDuration.totalMs(gifAsset);
    if (_isDisposed || sceneNodeId != node.id) return;
    _bubbleRevealTimer = Timer(Duration(milliseconds: durationMs), () {
      if (_isDisposed || sceneNodeId != node.id) return;
      bubbleRevealed = true;
      _startTypingEffect(node);
      _notify();
    });
  }

  // GIF 재생 시간만큼 기다렸다가 탭 없이 다음 노드로 진행. advanceScene()처럼 히스토리 추가까지 직접 처리
  void _waitForGifThenAutoAdvance(String gifAsset, DialogueNode node) async {
    final int? overrideMs = node.expression?.durationMs;
    final int durationMs = overrideMs ?? await GifDuration.totalMs(gifAsset);
    if (_isDisposed || sceneNodeId != node.id) return;
    _autoAdvanceTimer = Timer(Duration(milliseconds: durationMs), () {
      if (_isDisposed || sceneNodeId != node.id) return;
      _autoAdvancePending = false;
      sceneNodeHistory.add(node.id);
      _enterSceneNode(node.next);
      _notify();
    });
  }

  // 대사 그래프 밖(예: 회상 컷씬 미니게임)에서 온도 변화를 적용할 때 사용
  void applyTemperatureEffect(int effect) {
    if (effect == 0) return;
    temperature = (temperature + effect).clamp(1, 10).toInt();
    // 위 _enterSceneNode 쪽이랑 동일한 이유로 바로 전역에 동기화함
    StoryState.currentTemperature = temperature;
    _showTemperatureChange(effect);
    _notify();
  }

  // 온도 변화 안내 문구 노출 시간(2초, 조정 가능) 후 자동 닫힘
  void _showTemperatureChange(int effect) {
    _temperatureChangeTimer?.cancel();
    final String sign = effect > 0 ? '+' : '';
    final String verb = effect > 0 ? '상승' : '하락';
    temperatureChangeText = '$sign$effect 감정 온도가 $verb했습니다.';
    _temperatureChangeTimer = Timer(const Duration(seconds: 2), () {
      temperatureChangeText = null;
      _notify();
    });
  }

  void _startTypingEffect(DialogueNode node) {
    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    typedCharCount = 0;
    if (fullLength == 0) {
      _emptyNodeHoldElapsed = false;
      _typingTimer = Timer(_emptyNodeMinHold, () {
        _emptyNodeHoldElapsed = true;
        _maybeScheduleAutoAdvance(node);
        _notify();
      });
      return;
    }
    _typingTimer = Timer.periodic(_typingInterval, (timer) {
      typedCharCount++;
      if (typedCharCount >= fullLength) {
        timer.cancel();
        _maybeScheduleAutoAdvance(node);
      }
      _notify();
    });
  }

  // AUTO 모드가 켜져 있으면, line 타입 노드의 타이핑이 끝난(또는 탭으로 스킵된) 시점에
  // 2초 뒤 advanceScene()을 대신 호출해주는 타이머를 건다. choice 노드나 GIF 전용
  // 자동진행(_autoAdvancePending) 노드는 애초에 이 함수가 호출되는 경로를 안 타서 자동 제외됨
  void _maybeScheduleAutoAdvance(DialogueNode node) {
    if (!StoryState.isAutoAdvanceEnabled) return;
    _autoAdvanceModeTimer?.cancel();
    _autoAdvanceModeTimer = Timer(const Duration(seconds: 2), () {
      if (_isDisposed || sceneNodeId != node.id) return;
      advanceScene();
    });
  }

  static List<DialogueSpan> truncateSpans(
    List<DialogueSpan> spans,
    int charCount,
  ) {
    final List<DialogueSpan> result = [];
    int remaining = charCount;
    for (final span in spans) {
      if (remaining <= 0) break;
      if (span.text.length <= remaining) {
        result.add(span);
        remaining -= span.text.length;
      } else {
        result.add(
          DialogueSpan(
            text: span.text.substring(0, remaining),
            color: span.color,
            bold: span.bold,
          ),
        );
        remaining = 0;
      }
    }
    return result;
  }

  // 말풍선 탭하면 다음 노드로. 타이핑 중이면 다음으로 안 넘기고 텍스트 다 보여주기만 함
  void advanceScene() {
    final graph = sceneDialogue;
    final node = (graph != null && sceneNodeId != null)
        ? graph.nodes[sceneNodeId]
        : null;
    if (node == null || node.type != 'line') return;
    // GIF 재생 중이라 말풍선이 아직 안 떴으면 탭 무시
    if (!bubbleRevealed) return;
    // 릴리안 GIF 재생 끝나면 자동으로 넘어가는 노드는 탭으로 못 넘기게 막음
    if (_autoAdvancePending) return;

    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    if (typedCharCount < fullLength) {
      _typingTimer?.cancel();
      typedCharCount = fullLength;
      // 탭으로 스킵해서 전체 텍스트가 한 번에 드러난 것도 "타이핑 끝"으로 쳐서 AUTO 타이머를
      // 걸어줌 - 안 그러면 AUTO 켜진 상태에서 실수로 탭했을 때 자동진행이 멈춰버림
      _maybeScheduleAutoAdvance(node);
      _notify();
      return;
    }
    // 대사 없는 연출용 노드는 최소 노출 시간이 지나기 전까지 탭으로 못 넘어가게 막음
    if (fullLength == 0 && !_emptyNodeHoldElapsed) return;

    sceneNodeHistory.add(node.id);
    _enterSceneNode(node.next);
    _notify();
  }

  void goBackScene() {
    if (sceneNodeHistory.isEmpty) {
      // 선택지를 이미 골라서 그 이전으로 더는 못 돌아갈 때만 안내 배지를 띄움
      if (sceneHasLockedChoice) {
        _showChoiceLockedMessage();
      }
      return;
    }
    final graph = sceneDialogue;
    if (graph == null) return;
    final previousId = sceneNodeHistory.removeLast();
    final previousNode = graph.nodes[previousId];
    if (previousNode == null) return;

    _typingTimer?.cancel();
    sceneNodeId = previousId;
    lastLineNode = previousNode;
    typedCharCount = previousNode.spans.fold<int>(
      0,
      (sum, s) => sum + s.text.length,
    );
    _notify();
  }

  void _showChoiceLockedMessage() {
    _choiceLockedMessageTimer?.cancel();
    choiceLockedMessage = "당신의 선택은 되돌릴 수 없습니다.";
    _notify();
    _choiceLockedMessageTimer = Timer(const Duration(seconds: 2), () {
      choiceLockedMessage = null;
      _notify();
    });
  }

  void chooseSceneOption(DialogueOption option) {
    // 선택지를 실제로 고른 순간 그 이전 히스토리를 비워서 되돌아갈 수 없게 함
    sceneNodeHistory.clear();
    sceneHasLockedChoice = true;
    // setVars 있으면 전역 저장소에 병합 저장 (나중에 재료 매칭 등에서 참조)
    if (option.setVars != null) {
      StoryState.vars.addAll(option.setVars!);
    }
    _enterSceneNode(option.next);
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _bubbleRevealTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _autoAdvanceModeTimer?.cancel();
    _temperatureChangeTimer?.cancel();
    _choiceLockedMessageTimer?.cancel();
    super.dispose();
  }
}
