import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/menu/orientation_gate_screen.dart';
import 'core/services/ios_viewport_patch.dart';
import 'core/services/ending_unlocks.dart';
import 'core/services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화

  // Flutter 엔진이 viewport meta 태그를 만드는 건 ensureInitialized() 안에서 이미 끝나
  // 있어서, 이 타이밍이면 태그를 찾아서 patch하기에 안전함(iOS 아니거나 웹이 아니면
  // 내부에서 바로 return되는 함수라 다른 플랫폼엔 영향 없음)
  patchIosViewportMeta();

  // "엔딩보기" 갤러리용 엔딩 해금 상태를 앱 켜지자마자 미리 불러둠 - save_data_v1(단일
  // 세이브 슬롯)이랑은 별개 저장소라 "시작하기"로 새 게임을 시작해도 여기 값은 안 지워짐
  await EndingUnlocks.load();

  // 볼륨 값 불러오기 + 앱 생명주기 감지 등록. 오디오 자체의 재생 잠금 해제(웹 오디오는
  // 사용자 제스처가 있어야 풀림)는 아직 안 된 상태라, 여기서 playBgm을 불러도 실제 재생은
  // 안 되고 요청만 기억해둠 - 화면 최상위에 깔린 _AudioUnlockGate가 첫 탭을 감지하면 그때
  // AudioService.unlock()이 불리면서 기억해둔 트랙이 재생됨
  await AudioService.init();

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
      // Navigator를 포함한 트리 전체를 감싸서, 어느 화면에서 첫 탭이 일어나든(iOS 홈
      // 화면 추가 안내의 "확인"이든, 안내 없이 바로 메인 메뉴의 버튼이든) 놓치지 않고
      // 오디오 잠금을 풀 수 있게 함
      builder: (context, child) =>
          _AudioUnlockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

// 웹(특히 아이패드 Safari)은 사용자 제스처 없이 재생된 오디오를 막는데, 이 게이트가 앱
// 전체에서 처음 일어나는 포인터 다운 한 번만 감지해서 AudioService.unlock()을 불러줌.
// 한 번 풀리고 나면 더 이상 Listener를 거치지 않고 child를 그대로 반환해서, 이후 모든
// 탭에 대해 별도 일을 안 함
class _AudioUnlockGate extends StatefulWidget {
  const _AudioUnlockGate({required this.child});

  final Widget child;

  @override
  State<_AudioUnlockGate> createState() => _AudioUnlockGateState();
}

class _AudioUnlockGateState extends State<_AudioUnlockGate> {
  bool _hasUnlocked = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_hasUnlocked) return;
    setState(() => _hasUnlocked = true);
    AudioService.unlock();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasUnlocked) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: widget.child,
    );
  }
}
