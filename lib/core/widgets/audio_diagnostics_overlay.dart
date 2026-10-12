// lib/core/widgets/audio_diagnostics_overlay.dart
//
// 맥이 없어서 아이폰 사파리 콘솔을 못 보는 상황을 위한 화면 내 오디오 진단 패널.
// 주소 뒤에 ?audiolog=1이 붙어있을 때만 보임(audioDiagnosticsEnabled) - 평소 접속에서는
// 이 파일의 위젯 자체가 child를 그대로 반환하고 끝나서 완전히 안 보이고 아무 영향도 없음.
// 로그 표시 영역은 IgnorePointer로 감싸서 게임 조작을 가로채지 않고, 버튼 2개(비프 테스트/
// 음악 재시작)만 따로 터치를 받게 둠

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/audio_log.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';

// ?audiolog=1일 때만 true. Uri.base는 웹에서 현재 페이지 주소를 가리키고 앱 실행 중에
// 안 바뀌니까, 앱 켤 때 한 번만 읽어서 전역 값으로 둠
final bool audioDiagnosticsEnabled =
    Uri.base.queryParameters['audiolog'] == '1';

class AudioDiagnosticsOverlay extends StatelessWidget {
  const AudioDiagnosticsOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!audioDiagnosticsEnabled) return child;
    return Stack(
      children: [child, const _AudioDiagnosticsPanel()],
    );
  }
}

class _AudioDiagnosticsPanel extends StatefulWidget {
  const _AudioDiagnosticsPanel();

  @override
  State<_AudioDiagnosticsPanel> createState() =>
      _AudioDiagnosticsPanelState();
}

class _AudioDiagnosticsPanelState extends State<_AudioDiagnosticsPanel> {
  // 패널이 뜰 때만(=진단 모드일 때만) 이 State 자체가 만들어지니까, 타이머도 자연히
  // 진단 모드일 때만 돎 - 꺼져 있으면 이 클래스 자체가 안 만들어짐
  Timer? _statusTimer;
  String _status = '';

  // 로그 한 줄에 몇 개까지 보여줄지. 너무 많으면 화면을 다 덮어서 적당히 제한함
  static const int _visibleLogLines = 12;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshStatus(),
    );
  }

  void _refreshStatus() {
    if (!mounted) return;
    setState(() => _status = AudioService.debugAudioStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleBeepTest() async {
    await AudioService.playDiagnosticBeep();
  }

  void _handleRestartMusic() {
    AudioService.playBgm(AudioService.currentOrDefaultBgmTrackId());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 로그 표시 영역 - IgnorePointer라 이 안쪽은 터치해도 그냥 아래(게임)로 그대로
          // 전달됨
          IgnorePointer(
            child: Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.65),
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<List<String>>(
                    valueListenable: audioLogNotifier,
                    builder: (context, logs, _) {
                      final List<String> recent = logs.length > _visibleLogLines
                          ? logs.sublist(logs.length - _visibleLogLines)
                          : logs;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final String line in recent)
                            Text(
                              line,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // 버튼 영역 - IgnorePointer 밖이라 정상적으로 터치를 받음
          Container(
            color: Colors.black.withOpacity(0.65),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _diagButton('비프 테스트', _handleBeepTest),
                const SizedBox(width: 8),
                _diagButton('음악 재시작', _handleRestartMusic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagButton(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
