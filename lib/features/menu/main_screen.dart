// lib/features/menu/main_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart'; // 다음 화면

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 로고 화면 보여주는 시간. 화면 보면서 조정 예정
  static const Duration _autoAdvanceDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    Future.delayed(_autoAdvanceDelay, _goToChoiceScreen);
  }

  void _goToChoiceScreen() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChoiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 비율 계산기
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

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
        ],
      ),
    );
  }
}
