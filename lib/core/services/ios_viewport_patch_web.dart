// lib/core/services/ios_viewport_patch_web.dart

// 웹 빌드용 실제 구현. ios_viewport_patch.dart의 조건부 export로 dart.library.io가
// 없을 때(웹)만 쓰임.
//
// Flutter 엔진이 부팅하면서 <meta name="viewport"> 태그를 무조건 지우고
// viewport-fit 옵션 없이 새로 만들어버리는 걸 확인함(flutter_web_sdk의
// FullPageEmbeddingStrategy._applyViewportMeta() 참고) - 그래서 index.html을 직접
// 고쳐봐야 런타임에 덮어써져서 소용없고, 엔진이 태그를 다 만든 다음 시점에 여기서
// content를 patch해줘야 함. choice_screen.dart의 버튼 간격이 iOS Safari에서만 흔들려
// 보이는 문제가 iOS Safari의 documentElement.clientHeight 계산 방식(주소창 표시/숨김에
// 영향받음) 때문으로 추정되고, viewport-fit=cover가 그 계산 기준에 영향을 줄 수 있어서
// 시도해보는 완화책임 - 이 패치만으로 100% 해결된다는 보장은 없음

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void patchIosViewportMeta() {
  if (!kIsWeb) return;

  // ios_install_prompt_web.dart가 iOS 판별할 때 쓰는 것과 동일한 체크. 그 파일을 안
  // 건드리려고 여기서 똑같이 3줄 다시 씀(공용 함수로 뺄 만큼 복잡한 로직도 아님)
  final String userAgent = web.window.navigator.userAgent;
  final bool isIos =
      userAgent.contains('iPhone') ||
      userAgent.contains('iPad') ||
      userAgent.contains('iPod');
  if (!isIos) return;

  final web.Element? viewportMeta = web.window.document.head?.querySelector(
    'meta[name="viewport"]',
  );
  // 엔진이 아직 태그를 안 만들었거나(타이밍이 어긋난 경우) 태그 자체를 못 찾으면 그냥
  // 조용히 넘어감 - 이 패치가 실패해도 원래 있던 흔들림 문제로 돌아갈 뿐이지 에러가 나면
  // 안 됨
  if (viewportMeta == null) return;

  final String? currentContent = viewportMeta.getAttribute('content');
  if (currentContent == null || currentContent.contains('viewport-fit')) {
    // 이미 viewport-fit이 들어있으면(엔진이 나중에 기본값을 바꿔서 넣어주는 경우 등)
    // 중복으로 안 붙임
    return;
  }
  viewportMeta.setAttribute('content', '$currentContent, viewport-fit=cover');
}
