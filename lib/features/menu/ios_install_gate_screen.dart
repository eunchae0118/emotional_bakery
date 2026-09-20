// lib/features/menu/ios_install_gate_screen.dart

// 앱 최초 진입점(main.dart의 home). 로고 화면(MainScreen)이 뜨기 전에 한 번 거쳐가는
// 부팅 게이트 화면 - iOS 사파리(웹 배포판)로 아직 홈 화면에 추가 안 한 상태로 보고
// 있으면 새까만 배경 위에 "홈 화면에 추가" 안내창을 먼저 띄우고, 확인을 눌러야만
// MainScreen으로 넘어감. 그 외(안드로이드/데스크톱/이미 홈 화면 추가된 iOS)에서는
// 안내창 없이 바로 MainScreen으로 넘어감

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotional_bakery/core/services/ios_install_prompt.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/main_screen.dart';

class IosInstallGateScreen extends StatefulWidget {
  const IosInstallGateScreen({super.key});

  @override
  State<IosInstallGateScreen> createState() => _IosInstallGateScreenState();
}

class _IosInstallGateScreenState extends State<IosInstallGateScreen> {
  // 예전에 배너 방식으로 만들 때 쓰던 것과 동일한 키. 이 화면이 그 판단 로직을 그대로
  // 이어받는 거라 저장해둔 값도 그대로 재사용함
  static const String _dismissedKey = 'ios_install_prompt_dismissed_v1';

  bool _showNotice = false;

  @override
  void initState() {
    super.initState();
    // Navigator를 쓰는 작업은 첫 프레임이 다 그려진 다음에 하는 게 안전해서
    // addPostFrameCallback으로 한 프레임 미뤄둠
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIosInstallPrompt();
    });
  }

  // iOS 사파리로 브라우저에서 보고 있는 상태인지(shouldShowIosInstallPrompt)랑 예전에
  // 안내를 확인한 적 있는지(shared_preferences)를 둘 다 확인해서, 안내가 필요 없으면
  // 이 화면을 그냥 건너뛰고 바로 MainScreen으로 넘어감
  Future<void> _checkIosInstallPrompt() async {
    if (!shouldShowIosInstallPrompt()) {
      _goToMainScreen();
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool dismissed = prefs.getBool(_dismissedKey) ?? false;
    if (dismissed) {
      _goToMainScreen();
      return;
    }
    if (!mounted) return;
    setState(() {
      _showNotice = true;
    });
  }

  // 확인 버튼을 누르면 닫음 상태를 저장해서 다음에 앱을 다시 켰을 때 이 안내를 또
  // 안 거치게 하고, 바로 MainScreen으로 넘어감
  Future<void> _confirmAndGoToMainScreen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    _goToMainScreen();
  }

  // pushReplacement라 뒤로가기를 눌러도 이 게이트 화면으로는 다시 못 돌아옴
  void _goToMainScreen() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // 판별이 끝나기 전(또는 안내가 필요 없어서 MainScreen으로 넘어가는 중)에는 그냥
    // 새까만 화면만 잠깐 보여줌 - main_screen.dart가 이미지 로딩 전에 검은 배경을
    // 깔아두는 것과 같은 이유
    if (!_showNotice) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    // main_screen.dart랑 동일한 874x402 기준 비율 계산기
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // choice_screen.dart의 확인/안내 팝업(_buildNoticeDialog)이랑 같은 패널 크기 기준
    const double panelWidthRef = 420;
    const double panelHeightRef = 160;

    return Scaffold(
      // 다른 팝업들처럼 검은 반투명 딤 배경이 아니라, 뒤에 보여줄 화면 자체가 아직 없는
      // 부팅 단계라 완전 불투명한 검은 배경 위에 바로 안내창을 띄움
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: rW(panelWidthRef),
          height: rH(panelHeightRef),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: rW(panelWidthRef),
                height: rH(panelHeightRef),
                child: ScaledNineSliceImage(
                  imagePath: 'assets/images/tutorial_dialogue_box.png',
                  sourceCenterSlice: tutorialDialogueBoxCenterSlice,
                  scaleX: rW(1),
                  scaleY: rH(1),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: rW(28),
                  vertical: rH(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Safari 하단의 공유 버튼을 누르고 "홈 화면에 추가"를 선택하면 앱처럼 사용할 수 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF5A3E2B),
                        fontSize: rW(15),
                        fontFamily: 'SCDream',
                      ),
                    ),
                    SizedBox(height: rH(14)),
                    GestureDetector(
                      onTap: _confirmAndGoToMainScreen,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/button.png',
                            width: rW(110),
                            height: rH(36),
                            fit: BoxFit.fill,
                          ),
                          Text(
                            '확인',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: rW(14),
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SCDream',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
