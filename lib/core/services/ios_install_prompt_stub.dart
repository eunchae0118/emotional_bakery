// lib/core/services/ios_install_prompt_stub.dart

// 웹이 아닌 빌드(안드로이드/iOS 네이티브/데스크톱)용 구현. "홈 화면에 추가" 안내는 iOS 웹
// 배포판에서만 필요한 거라 여기선 그냥 무조건 false만 반환함. ios_install_prompt.dart의
// 조건부 export로 dart.library.io가 있을 때만 쓰임

bool shouldShowIosInstallPrompt() => false;
