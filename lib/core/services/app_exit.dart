// lib/core/services/app_exit.dart

// MenuOverlay의 "게임종료" 버튼이 부르는 공용 진입점. dart:io는 웹 빌드에서 컴파일 자체가
// 안 되기 때문에, 조건부 export로 플랫폼별 구현을 갈라둠 - dart.library.io가 있으면(안드로이드/
// iOS/데스크톱) app_exit_io.dart를, 없으면(웹) app_exit_stub.dart를 씀
export 'app_exit_stub.dart' if (dart.library.io) 'app_exit_io.dart';
