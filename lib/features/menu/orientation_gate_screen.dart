// lib/features/menu/orientation_gate_screen.dart

// 게임 도입부 맨 앞에서 한 번 거쳐가는 세로모드 안내 화면(main.dart의 home). 화면이
// 이미 가로면 안내 문구 없이 바로 통과시키고, 세로면 검은 배경에 "가로로 돌려달라"는
// 문구만 띄워두고 대기하다가, 가로로 돌아가는 순간 자동으로 InitialBlackoutScreen으로
// 넘어감(pushReplacement라 뒤로가기로 다시 이 화면에 못 돌아옴)

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/initial_blackout_screen.dart';

class OrientationGateScreen extends StatefulWidget {
  const OrientationGateScreen({super.key});

  @override
  State<OrientationGateScreen> createState() => _OrientationGateScreenState();
}

class _OrientationGateScreenState extends State<OrientationGateScreen> {
  // InitialBlackoutScreen으로 넘어가는 중인지 표시. build()가 가로 상태에서 여러 번
  // 다시 불려도 pushReplacement가 중복으로 안 걸리게 막는 용도
  bool _isLeaving = false;

  // 가로로 확인되면 다음 프레임에 InitialBlackoutScreen으로 넘어감. Navigator를 쓰는
  // 작업은 build() 도중이 아니라 프레임이 다 그려진 다음에 하는 게 안전해서
  // addPostFrameCallback으로 한 프레임 미룸
  void _scheduleGoToInitialBlackoutScreen() {
    if (_isLeaving) return;
    _isLeaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(instantRoute(const InitialBlackoutScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final Orientation orientation = MediaQuery.of(context).orientation;

    // 화면 방향이 바뀌면(기기 회전 등) Flutter가 MediaQuery 의존성 때문에 build()를
    // 자동으로 다시 불러줘서, 별도 WidgetsBindingObserver 없이도 여기서 회전을 감지할
    // 수 있음 - 그래서 처음부터 가로로 열었을 때(안내 문구 없이 즉시 통과)랑, 세로로
    // 있다가 가로로 돌렸을 때(대기 중 자동 전환) 둘 다 이 한 분기로 처리됨
    if (orientation == Orientation.landscape) {
      _scheduleGoToInitialBlackoutScreen();
      return const Scaffold(backgroundColor: Colors.black);
    }

    // 다른 도입부 화면들(content_warning_screen.dart 등)은 가로 화면 기준(874 너비)으로
    // rW를 계산하는데, 이 화면은 항상 세로 상태에서만 보여서 그 기준을 그대로 쓰면
    // 세로 폭이 874보다 훨씬 좁아서 글자가 너무 작아짐. 그래서 여기는 세로 폭(w) 자체를
    // 기준으로 따로 계산함 - 일반적인 폰 세로 폭(약 400 논리 픽셀)을 기준값으로 잡음.
    // 텍스트 하나만 중앙에 놓는 화면이라(버튼처럼 서로 다른 축끼리 맞출 일이 없음)
    // choice_screen.dart에서 고쳤던 가로/세로 축 어긋남 문제는 애초에 생길 수가 없음
    final double w = size.width;
    double rW(double px) => px / 400 * w;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: rW(40)),
          child: Text(
            '게임은 가로 화면에 최적화되어 있습니다.\n화면을 가로로 돌려주시기 바랍니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: rW(16),
              fontWeight: FontWeight.w500,
              fontFamily: 'SCDream',
              // 두 줄이 좀 붙어 보여서 행간 넣음. 화면 보면서 조정 예정
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
