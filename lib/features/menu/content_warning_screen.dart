// lib/features/menu/content_warning_screen.dart

// ios_install_gate_screen.dart 다음, 로고 화면(MainScreen) 전에 한 번 보여주는 콘텐츠
// 경고 문구 화면. 확인 버튼 없이 검은 배경에 문구만 띄워두고, 일정 시간 지나면 자동으로
// MainScreen으로 넘어감(pushReplacement라 뒤로가기로 다시 이 화면에 못 돌아옴)

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/main_screen.dart';

class ContentWarningScreen extends StatefulWidget {
  const ContentWarningScreen({super.key});

  @override
  State<ContentWarningScreen> createState() => _ContentWarningScreenState();
}

class _ContentWarningScreenState extends State<ContentWarningScreen> {
  // 문구 띄워두는 시간. 화면 보면서 조정 예정
  static const Duration _autoAdvanceDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    Future.delayed(_autoAdvanceDelay, _goToMainScreen);
  }

  void _goToMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(instantRoute(const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // main_screen.dart랑 동일한 874x402 기준 비율 계산기(가로 폭만 필요해서 rW만 씀)
    double w = MediaQuery.of(context).size.width;
    double rW(double px) => (px / 874) * w;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          // 문구가 길어서 화면 끝까지 안 붙게 좌우 여백을 넉넉하게 둠
          padding: EdgeInsets.symmetric(horizontal: rW(60)),
          child: Text(
            '이 이야기는 상실과 그리움, 슬픔을 담은 감정적인 내용을 포함하고 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: rW(20),
              fontWeight: FontWeight.w500,
              fontFamily: 'SCDream',
              // 두 줄 행간. ios_install_gate_screen.dart랑 값 맞춤 - 화면 보면서 조정 예정
              height: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}
