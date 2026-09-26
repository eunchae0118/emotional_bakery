// lib/core/services/ios_viewport_patch.dart

// main.dart가 부르는 공용 진입점. ios_install_prompt.dart랑 똑같은 패턴으로 조건부
// export를 씀 - dart.library.io가 있으면(안드로이드/iOS 네이티브/데스크톱, 즉 웹이
// 아닌 빌드) 아무것도 안 하는 ios_viewport_patch_stub.dart를, 없으면(웹) 진짜 패치
// 로직이 들어있는 ios_viewport_patch_web.dart를 씀
export 'ios_viewport_patch_web.dart'
    if (dart.library.io) 'ios_viewport_patch_stub.dart';
