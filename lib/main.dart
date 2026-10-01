import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/menu/orientation_gate_screen.dart';
import 'core/services/ios_viewport_patch.dart';
import 'core/services/ending_unlocks.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화

  // Flutter 엔진이 viewport meta 태그를 만드는 건 ensureInitialized() 안에서 이미 끝나
  // 있어서, 이 타이밍이면 태그를 찾아서 patch하기에 안전함(iOS 아니거나 웹이 아니면
  // 내부에서 바로 return되는 함수라 다른 플랫폼엔 영향 없음)
  patchIosViewportMeta();

  // "엔딩보기" 갤러리용 엔딩 해금 상태를 앱 켜지자마자 미리 불러둠 - save_data_v1(단일
  // 세이브 슬롯)이랑은 별개 저장소라 "시작하기"로 새 게임을 시작해도 여기 값은 안 지워짐
  await EndingUnlocks.load();

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
      // 세로모드 안내(가로면 바로 통과) -> 순수 암전 -> iOS 홈 화면 추가 안내(부팅
      // 게이트) -> 콘텐츠 경고 -> 로고 화면(MainScreen) 순으로 이어지는 최초 실행
      // 흐름의 시작점
      home: const OrientationGateScreen(),
    );
  }
}
