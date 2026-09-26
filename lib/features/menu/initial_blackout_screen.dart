// lib/features/menu/initial_blackout_screen.dart

// 앱을 켜자마자 제일 먼저 보여주는 순수 암전 화면(main.dart의 home). 텍스트나 버튼
// 없이 검은 배경만 잠깐 띄워두고, 일정 시간 지나면 자동으로 ios_install_gate_screen.dart로
// 넘어감(pushReplacement라 뒤로가기로 다시 이 화면에 못 돌아옴)

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/ios_install_gate_screen.dart';

class InitialBlackoutScreen extends StatefulWidget {
  const InitialBlackoutScreen({super.key});

  @override
  State<InitialBlackoutScreen> createState() => _InitialBlackoutScreenState();
}

class _InitialBlackoutScreenState extends State<InitialBlackoutScreen> {
  // 암전 유지 시간. 화면 보면서 조정 예정
  static const Duration _holdDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    Future.delayed(_holdDuration, _goToIosInstallGateScreen);
  }

  void _goToIosInstallGateScreen() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(instantRoute(const IosInstallGateScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.black);
  }
}
