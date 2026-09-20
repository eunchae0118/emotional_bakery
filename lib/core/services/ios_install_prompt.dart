// lib/core/services/ios_install_prompt.dart

// main_screen.dart가 부르는 공용 진입점. package:web은 웹 빌드에서만 쓸 수 있어서,
// app_exit.dart(app_exit.dart/app_exit_stub.dart/app_exit_io.dart)랑 똑같은 패턴으로
// 조건부 export를 씀 - dart.library.io가 있으면(안드로이드/iOS 네이티브/데스크톱, 즉 웹이
// 아닌 빌드) 항상 false만 반환하는 ios_install_prompt_stub.dart를, 없으면(웹) 진짜 판별
// 로직이 들어있는 ios_install_prompt_web.dart를 씀
export 'ios_install_prompt_web.dart'
    if (dart.library.io) 'ios_install_prompt_stub.dart';
