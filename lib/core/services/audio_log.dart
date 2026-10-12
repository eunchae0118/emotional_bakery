// lib/core/services/audio_log.dart
//
// 오디오 재생 실패 로그 공용 함수. 예전엔 kDebugMode일 때만 찍었는데, 그러면 릴리즈 빌드
// (실제 배포되는 웹 버전)에서는 iOS Safari에서 재생이 거부돼도 콘솔에 아무 흔적도 안 남아서
// 디버깅이 안 됐음 - 그래서 디버그/릴리즈 상관없이 항상 콘솔에 찍히게 바꿈. debugPrint는
// Flutter가 릴리즈 빌드에서도 그대로 동작하는 print 래퍼라, 화면엔 아무것도 안 보이고
// 브라우저 개발자 도구 콘솔에만 남음 - 사용자에게 노출되는 건 없음
//
// (업데이트: 맥이 없어서 아이폰 사파리 콘솔을 못 보는 상황 때문에, 호출될 때마다 메시지를
// audioLogNotifier에도 같이 쌓아둠 - 화면 위 진단 패널(audio_diagnostics_overlay.dart)이
// 이 값을 구독해서 그대로 보여줌. 콘솔 출력(debugPrint)은 진단 모드 여부와 상관없이 항상
// 그대로 남음 - 여기선 그냥 "메모리에도 하나 더 쌓아두는" 일만 추가된 거라 기존 동작엔
// 영향 없음)

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;

// 오디오 진단 로그 전체 내역(최근 [_maxAudioLogLines]줄). 화면 진단 패널이 이 값을
// ValueListenableBuilder로 구독해서 그대로 띄움 - 패널이 없어도(진단 모드 꺼짐) 그냥
// 아무도 안 보는 리스트가 메모리에 쌓일 뿐이라 부담 없음
final ValueNotifier<List<String>> audioLogNotifier = ValueNotifier<List<String>>(
  <String>[],
);

const int _maxAudioLogLines = 40;

// 연속으로 똑같은 내용이 들어오면 새 줄을 또 안 늘리고 "(xN)"으로 개수만 올림 - 터치할
// 때마다 찍히는 pointerdown/pointerup 로그처럼 같은 문구가 쏟아질 수 있는 경우를 대비함
String? _lastRawMessage;
int _lastRawCount = 0;

void logAudioError(String where, Object error) {
  final String message = '$where 실패: $error';
  debugPrint('[AudioService] $message');
  _pushAudioLog(message);
}

void _pushAudioLog(String rawMessage) {
  final List<String> current = audioLogNotifier.value;
  if (rawMessage == _lastRawMessage && current.isNotEmpty) {
    _lastRawCount++;
    final List<String> next = List<String>.of(current);
    next[next.length - 1] = '${_timestamp()} $rawMessage (x$_lastRawCount)';
    audioLogNotifier.value = next;
    return;
  }
  _lastRawMessage = rawMessage;
  _lastRawCount = 1;
  final List<String> next = List<String>.of(current)
    ..add('${_timestamp()} $rawMessage');
  if (next.length > _maxAudioLogLines) {
    next.removeRange(0, next.length - _maxAudioLogLines);
  }
  audioLogNotifier.value = next;
}

String _timestamp() {
  final DateTime now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final String millis = now.millisecond.toString().padLeft(3, '0');
  return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.$millis';
}
