// lib/core/services/ios_install_prompt_web.dart

// 웹 빌드용 실제 구현. ios_install_prompt.dart의 조건부 export로 dart.library.io가
// 없을 때(웹)만 쓰임. package:web + dart:js_interop으로 브라우저 navigator 정보를 읽어서
// "iOS 사파리 + 아직 홈 화면에 추가 안 한 상태(브라우저로 보고 있는 상태)"인지만 판별함

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool shouldShowIosInstallPrompt() {
  // 이 파일 자체가 조건부 export로 웹 빌드에서만 쓰이긴 하는데, 그거랑 별개로 명세에
  // 나온 조건을 그대로 다 체크해두는 게 안전할 거 같아서 kIsWeb도 한 번 더 확인함
  if (!kIsWeb) return false;

  final String userAgent = web.window.navigator.userAgent;
  final bool isIos =
      userAgent.contains('iPhone') ||
      userAgent.contains('iPad') ||
      userAgent.contains('iPod');
  if (!isIos) return false;

  // navigator.standalone은 사파리 전용 비표준 프로퍼티라 package:web의 Navigator 타입엔
  // 없음 - js_interop_unsafe의 getProperty로 JS 쪽 값을 직접 꺼내서 봄. true면 이미 홈
  // 화면에 추가해서 실행 중인 거라 안내를 또 띄울 필요가 없음
  final JSBoolean? standalone = web.window.navigator.getProperty<JSBoolean?>(
    'standalone'.toJS,
  );
  final bool isStandalone = standalone?.toDart ?? false;
  return !isStandalone;
}
