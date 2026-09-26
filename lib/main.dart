import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/menu/ios_install_gate_screen.dart';
import 'core/services/ios_viewport_patch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화

  // Flutter 엔진이 viewport meta 태그를 만드는 건 ensureInitialized() 안에서 이미 끝나
  // 있어서, 이 타이밍이면 태그를 찾아서 patch하기에 안전함(iOS 아니거나 웹이 아니면
  // 내부에서 바로 return되는 함수라 다른 플랫폼엔 영향 없음)
  patchIosViewportMeta();

  // 가로 화면 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const EmotionalBakery());
}

// 테스트 환경에서 마우스 드래그 가능
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, // 마우스 드래그 활성화
  };
}

class EmotionalBakery extends StatelessWidget {
  const EmotionalBakery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 우측 상단 디버그 배너 제거
      scrollBehavior: MyCustomScrollBehavior(), // 커스텀 스크롤 행동
      theme: ThemeData(fontFamily: 'NanumGothic'), // 폰트
      // 로고 화면(MainScreen) 뜨기 전에 iOS 홈 화면 추가 안내를 먼저 거쳐가는 부팅 게이트
      home: const IosInstallGateScreen(),
    );
  }
}
