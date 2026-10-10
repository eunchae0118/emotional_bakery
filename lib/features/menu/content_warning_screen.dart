// lib/features/menu/content_warning_screen.dart

// ios_install_gate_screen.dart 다음, 로고 화면(MainScreen) 전에 한 번 보여주는 콘텐츠
// 경고 문구 화면. 확인 버튼 없이 검은 배경에 문구만 띄워두고, 일정 시간 지나면 자동으로
// MainScreen으로 넘어감(pushReplacement라 뒤로가기로 다시 이 화면에 못 돌아옴)

// (업데이트: 자동 전환을 없애고, 최소 표시 시간이 지나면 "화면을 터치해주세요" 안내를
// 띄운 뒤 실제 터치가 있어야 넘어가게 바꿈 - 웹(특히 아이패드 사파리)은 사용자 제스처가
// 있어야 오디오 재생이 풀리는데, 이 화면이 부팅 흐름에서 가장 먼저 "눌러주세요"라고 말할
// 수 있는 자리라 여기서 main_theme을 깨우는 첫 신호로 같이 씀)

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/menu/main_screen.dart';

class ContentWarningScreen extends StatefulWidget {
  const ContentWarningScreen({super.key});

  @override
  State<ContentWarningScreen> createState() => _ContentWarningScreenState();
}

class _ContentWarningScreenState extends State<ContentWarningScreen>
    with SingleTickerProviderStateMixin {
  // 문구만 띄워두는 최소 시간. 이 시간이 지나야 "화면을 터치해주세요" 안내가 뜨고, 터치로
  // 넘어갈 수 있음 - 화면 보면서 조정 예정
  static const Duration _minDisplayDuration = Duration(seconds: 3);

  // 터치 안내 문구가 천천히 깜빡이는(페이드 반복) 주기
  static const Duration _hintBlinkDuration = Duration(milliseconds: 1500);

  // 최소 표시 시간이 지나서 터치로 넘어갈 수 있는 상태인지. 이 전엔 화면을 눌러도 안 넘어감
  bool _canAdvance = false;

  late final AnimationController _hintBlinkController;

  @override
  void initState() {
    super.initState();
    // 이미 unlock된 상태(재방문 등)라면 여기서 바로 재생되고, 아직이면 AudioService가
    // 요청만 기억해뒀다가 이 화면의 터치(또는 main.dart의 전역 첫 터치)에서 풀림
    AudioService.playBgm(AudioIds.mainTheme);

    _hintBlinkController = AnimationController(
      vsync: this,
      duration: _hintBlinkDuration,
    )..repeat(reverse: true);

    Future.delayed(_minDisplayDuration, () {
      if (!mounted) return;
      setState(() => _canAdvance = true);
    });
  }

  @override
  void dispose() {
    _hintBlinkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 최소 표시 시간 전엔 터치해도 무시 - 문구를 다 읽기 전에 넘어가 버리는 걸 막음
    if (!_canAdvance || !mounted) return;
    // main.dart의 _AudioUnlockGate가 같은 터치의 포인터 다운 단계에서 먼저 unlock()을
    // 불러주지만, 혹시 이미 unlock된 상태(initState 호출만으로 충분했던 경우)에도 여기서
    // 한 번 더 불러서 확실히 재생을 요청함 - 이미 main_theme이 재생 중이면 AudioService가
    // 알아서 아무것도 안 함
    AudioService.playBgm(AudioIds.mainTheme);
    Navigator.of(context).pushReplacement(instantRoute(const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // main_screen.dart랑 동일한 874x402 기준 비율 계산기(가로 폭만 필요해서 rW만 씀)
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    // 터치 안내 문구 전용 단일 스케일(min 기준). 경고 문구 자체(rW)는 안 건드리고, 새로
    // 추가하는 안내 문구만 이 스케일을 씀 - rW/rH를 섞으면 아이패드처럼 화면 비율이
    // 디자인 기준(874:402)이랑 멀어질 때 글자가 찌그러져 보일 수 있어서 min으로 통일함
    final double u = (w / 874) < (h / 402) ? (w / 874) : (h / 402);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
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
            // 화면 하단 중앙에 작게 뜨는 터치 안내. 최소 표시 시간 지나기 전엔 아예 안 띄움
            if (_canAdvance)
              Positioned(
                left: 0,
                right: 0,
                bottom: u * 30,
                child: FadeTransition(
                  opacity: _hintBlinkController,
                  child: Center(
                    child: Text(
                      '화면을 터치해주세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: u * 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SCDream',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
