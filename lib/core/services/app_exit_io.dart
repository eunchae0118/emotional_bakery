// lib/core/services/app_exit_io.dart

// 안드로이드/iOS/데스크톱(윈도우/맥/리눅스) 빌드용 구현. app_exit.dart의 조건부 export로
// dart.library.io가 있을 때만 쓰임

import 'dart:io';
import 'package:flutter/services.dart';

void exitGame() {
  if (Platform.isAndroid || Platform.isIOS) {
    // 안드로이드는 이 앱을 최근 목록에서 제거하면서 확실히 꺼짐.
    // iOS는 애플 정책상 앱이 스스로 종료되면 안 돼서 이 호출이 사실상 무시됨(의도된 동작,
    // iOS 앱은 원래 사용자가 직접 스와이프해서 꺼야 함)
    // 여기도 app_exit_stub.dart랑 동일한 이유로 catchError 붙여둠 - 채널이 없는 임베더에서
    // reject되면 안 받아주는 예외가 조용히 남는 걸 막기 위함
    SystemNavigator.pop().catchError((_) {});
  } else {
    // 윈도우/맥/리눅스는 SystemNavigator.pop()이 안 먹혀서 프로세스를 직접 종료함
    exit(0);
  }
}
