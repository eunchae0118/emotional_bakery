// lib/core/services/app_exit_stub.dart

// 웹 빌드용 구현. dart:io를 못 써서 exit()을 못 쓰고 SystemNavigator.pop()만 시도함 -
// 브라우저 정책상 스크립트로 연 탭이 아니면 이것도 사실상 아무 동작 안 함(웹은 완전한
// 강제 종료 자체가 불가능함). app_exit.dart의 조건부 export로 dart.library.io가 없을 때만 쓰임

import 'package:flutter/services.dart';

void exitGame() {
  // SystemNavigator.pop()은 Future를 반환하는데, 그냥 호출만 하고 안 받아주면 이 채널을
  // 구현 안 한 플랫폼(웹이 대표적)에서 reject됐을 때 아무도 안 받는 예외로 남아서 콘솔에만
  // 조용히 에러가 찍힘 - 화면엔 아무 표시도 없어서 버튼이 아예 안 눌리는 것처럼 보임.
  // catchError로 받아서 그런 경우에도 조용히 넘어가게 함(웹은 브라우저 정책상 강제 종료
  // 자체가 안 되는 게 원래 한계라 이걸로 "진짜 종료"가 되는 건 아님)
  SystemNavigator.pop().catchError((_) {});
}
