// lib/core/services/audio_log.dart
//
// 오디오 재생 실패 로그 공용 함수. 예전엔 kDebugMode일 때만 찍었는데, 그러면 릴리즈 빌드
// (실제 배포되는 웹 버전)에서는 iOS Safari에서 재생이 거부돼도 콘솔에 아무 흔적도 안 남아서
// 디버깅이 안 됐음 - 그래서 디버그/릴리즈 상관없이 항상 콘솔에 찍히게 바꿈. debugPrint는
// Flutter가 릴리즈 빌드에서도 그대로 동작하는 print 래퍼라, 화면엔 아무것도 안 보이고
// 브라우저 개발자 도구 콘솔에만 남음 - 사용자에게 노출되는 건 없음

import 'package:flutter/foundation.dart' show debugPrint;

void logAudioError(String where, Object error) {
  debugPrint('[AudioService] $where 실패: $error');
}
