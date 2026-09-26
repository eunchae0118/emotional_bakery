// lib/features/menu/ios_install_gate_screen.dart

// 앱 최초 진입점(main.dart의 home). 로고 화면(MainScreen)이 뜨기 전에 한 번 거쳐가는
// 부팅 게이트 화면 - iOS 사파리(웹 배포판)로 아직 홈 화면에 추가 안 한 상태로 보고
// 있으면 새까만 배경 위에 "홈 화면에 추가" 안내창을 먼저 띄우고, 확인을 눌러야만
// 콘텐츠 경고 화면으로 넘어감. 그 외(안드로이드/데스크톱/이미 홈 화면 추가된 iOS)에서는
// 안내창 없이 바로 콘텐츠 경고 화면으로 넘어감

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotional_bakery/core/services/ios_install_prompt.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/content_warning_screen.dart';

// 확인 버튼 전용 9-slice 테두리 영역. shared_ui.dart의 tutorialDialogueBoxCenterSlice
// (상하좌우 31px)를 그대로 쓰면 이 버튼처럼 작은 크기에서 테두리가 상대적으로 두꺼워
// 보여서, 이 화면 전용으로 더 얇은 값을 따로 뺌 - 화면 보면서 조정 예정
const Rect _confirmButtonCenterSlice = Rect.fromLTRB(12, 12, 1107, 273);

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
  // 이 화면을 그냥 건너뛰고 바로 콘텐츠 경고 화면으로 넘어감
  Future<void> _checkIosInstallPrompt() async {
    if (!shouldShowIosInstallPrompt()) {
      _goToContentWarningScreen();
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool dismissed = prefs.getBool(_dismissedKey) ?? false;
    if (dismissed) {
      _goToContentWarningScreen();
      return;
    }
    if (!mounted) return;
    setState(() {
      _showNotice = true;
    });
  }

  // 확인 버튼을 누르면 닫음 상태를 저장해서 다음에 앱을 다시 켰을 때 이 안내를 또
  // 안 거치게 하고, 바로 콘텐츠 경고 화면으로 넘어감
  Future<void> _confirmAndGoToContentWarningScreen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    _goToContentWarningScreen();
  }

  // pushReplacement라 뒤로가기를 눌러도 이 게이트 화면으로는 다시 못 돌아옴
  void _goToContentWarningScreen() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(instantRoute(const ContentWarningScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // 판별이 끝나기 전(또는 안내가 필요 없어서 콘텐츠 경고 화면으로 넘어가는 중)에는
    // 그냥 새까만 화면만 잠깐 보여줌 - main_screen.dart가 이미지 로딩 전에 검은 배경을
    // 깔아두는 것과 같은 이유
    if (!_showNotice) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    // main_screen.dart랑 동일한 874x402 기준 비율 계산기
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // content_warning_screen.dart랑 스타일(검은 배경 + 흰 글씨 SCDream Medium)을
    // 맞추려고 예전에 쓰던 tutorial_dialogue_box.png 패널은 빼고 문구만 바로 띄움
    //
    // 문구랑 확인 버튼 사이 간격. 원래 rH(24)였는데 너무 붙어 보여서 넓힘 - 화면
    // 보면서 조정 예정
    const double textToButtonGap = 48;

    // 확인 버튼 전용 단일 스케일. choice_screen.dart의 로고/버튼 겹침·잘림 문제를
    // 고칠 때 쓴 것과 동일한 min(w/874, h/402) 방식 - rW/rH처럼 가로세로를 따로 계산해서
    // 버튼 박스 자체가 화면 비율에 따라 늘어나거나 찌그러지는 일이 없게 함. 이 화면은
    // 보통 가로로 진입하지만, 혹시 OrientationGateScreen을 우회해서 세로로 들어오는
    // 경우에도 안전망으로 작동함
    final double buttonScale = (w / 874) < (h / 402) ? (w / 874) : (h / 402);
    double s(double px) => px * buttonScale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          // 문구가 길어서 화면 끝까지 안 붙게 좌우 여백을 넉넉하게 둠
          padding: EdgeInsets.symmetric(horizontal: rW(60)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Safari 상단의 공유 버튼을 누르고\n"홈 화면에 추가"를 선택하면 앱처럼 사용할 수 있습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: rW(20),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SCDream',
                  // 두 줄이 너무 붙어 보여서 행간 넣음. 화면 보면서 조정 예정
                  height: 2.0,
                ),
              ),
              SizedBox(height: rH(textToButtonGap)),
              GestureDetector(
                onTap: _confirmAndGoToContentWarningScreen,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // button.png 대신 다른 안내창들이랑 같은 tutorial_dialogue_box.png
                    // 9-slice 패널을 씀. 크기는 원래 button.png 쓰던 값(rW(110)/rH(36))
                    // 보다 키움 - 화면 보면서 조정 예정
                    SizedBox(
                      width: s(160),
                      height: s(50),
                      child: ScaledNineSliceImage(
                        imagePath: 'assets/images/tutorial_dialogue_box.png',
                        sourceCenterSlice: _confirmButtonCenterSlice,
                        scaleX: s(1),
                        scaleY: s(1),
                      ),
                    ),
                    Text(
                      '확인',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: s(14),
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
      ),
    );
  }
}
