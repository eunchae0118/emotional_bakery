// lib/features/menu/main_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart'; // 다음 화면

// 프롤로그(dialogue_overlay.dart의 _DialogueOverlayState._prologueData)가 참조하는 이미지
// 전체 - 로고 화면에서 미리 로딩해두려고 뽑음. _prologueData는 그 클래스 안에 private
// 인스턴스 필드라 여기서 직접 참조는 못 하고 목록을 그대로 옮겨 적음(중복 제거해서
// prolog_1~8.png 8개만 남김) - _prologueData가 바뀌면 이 목록도 같이 업데이트해줘야 함
const List<String> _prologueImagePaths = [
  'assets/images/prolog_1.png',
  'assets/images/prolog_2.png',
  'assets/images/prolog_3.png',
  'assets/images/prolog_4.png',
  'assets/images/prolog_5.png',
  'assets/images/prolog_6.png',
  'assets/images/prolog_7.png',
  'assets/images/prolog_8.png',
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 로딩이 너무 빨리 끝나면 로고 화면이 순식간에 지나가서 어색하니까, 최소 이만큼은
  // 로딩바를 보여줌 - 화면 보면서 조정 예정
  static const Duration _minLoadingScreenDuration = Duration(
    milliseconds: 1500,
  );

  // didChangeDependencies가 여러 번 불려도 프리캐싱이 중복으로 안 걸리게 막는 용도
  bool _hasStartedPrecache = false;
  int _loadedImageCount = 0;
  bool _isImageLoadingComplete = false;
  bool _isMinTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minLoadingScreenDuration, () {
      if (!mounted) return;
      setState(() => _isMinTimeElapsed = true);
      _maybeGoToChoiceScreen();
    });
  }

  // precacheImage는 BuildContext로 MediaQuery/Directionality 등을 참조해야 해서, 아직
  // 위젯 트리에 완전히 연결 안 된 initState보다 didChangeDependencies에서 부르는 게
  // Flutter 공식 권장 패턴임
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedPrecache) return;
    _hasStartedPrecache = true;
    _precachePrologueImages();
  }

  // 프롤로그 이미지를 순서대로 미리 로딩. 하나씩 끝날 때마다 진행률 갱신해서 로딩바에 반영함
  Future<void> _precachePrologueImages() async {
    for (final String path in _prologueImagePaths) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {
        // 에러 나는 이미지는 그냥 건너뜀 - 하나 실패했다고 로딩이 무한 대기하면 안 됨
      }
      if (!mounted) return;
      setState(() => _loadedImageCount++);
    }
    if (!mounted) return;
    setState(() => _isImageLoadingComplete = true);
    _maybeGoToChoiceScreen();
  }

  // "로딩 완료 && 최소 노출 시간 경과" 둘 다 만족해야 다음 화면으로 넘어감
  void _maybeGoToChoiceScreen() {
    if (!_isImageLoadingComplete || !_isMinTimeElapsed) return;
    if (!mounted) return;
    Navigator.push(context, instantRoute(const ChoiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 비율 계산기
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    final double loadingProgress =
        (_loadedImageCount / _prologueImagePaths.length).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black, // 이미지 로딩 전 깜빡임 방지
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1층: 배경 이미지
          Image.asset(
            'assets/images/main_bg.png', // 로고 없는 배경 파일명
            fit: BoxFit.cover,
          ),

          // 2층: 로고 이미지
          // 피그마에서 로고가 왼쪽 위 기준 어디쯤 있는지 확인해서 숫자 넣어!
          Positioned(
            left: rW(68), // X축 위치
            top: rH(191), // Y축 위치
            child: Image.asset(
              'assets/images/logo.png', // 로고
              width: rW(232), // 로고 크기
              fit: BoxFit.contain,
            ),
          ),

          // 3층: 프롤로그 에셋 로딩바. 화면 하단에 작게 깔아둠 - 도입부 화면들 톤(검은
          // 배경 + 흰색/주황색)에 맞춰서 트랙은 반투명 흰색, 채워지는 부분은 앱 전체에서
          // 쓰는 포인트 컬러(0xFFFF7100)로 맞춤
          Positioned(
            left: rW(68),
            right: rW(68),
            bottom: rH(30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(rW(4)),
              child: LinearProgressIndicator(
                value: loadingProgress,
                minHeight: rH(8),
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF7100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
