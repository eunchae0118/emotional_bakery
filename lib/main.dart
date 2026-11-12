import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/menu/orientation_gate_screen.dart';
import 'core/services/ios_viewport_patch.dart';
import 'core/services/ending_unlocks.dart';
import 'core/services/audio_service.dart';
import 'core/constants/audio_ids.dart';
import 'core/services/audio_log.dart';
import 'core/widgets/audio_diagnostics_overlay.dart';

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
  // 안 되고 요청만 기억해둠 - 화면 최상위에 깔린 _AudioUnlockGate가 터치마다
  // AudioService.onUserGesture()를 불러주면서 기억해둔 트랙을 재생/복구함
  await AudioService.init();

  // 대사 타자 효과 블립음 - 매 글자마다 쓰이니까 첫 대사가 뜨기 전에 미리 디코딩/준비만
  // 해둠(재생은 안 함). 여기서 실패해도(에셋 없음 등) 조용히 넘어가고, 첫 블립 재생
  // 시도 때 다시 시도됨
  AudioService.prefetchSfx(AudioIds.chaeonBlip);
  AudioService.prefetchSfx(AudioIds.lillianBlip);
  // 발소리도 동일한 이유로 여기서 미리 준비해둠 - 걸을 때 매번 디코딩하면 안 됨
  AudioService.prefetchSfx(AudioIds.footstepA);
  AudioService.prefetchSfx(AudioIds.footstepB);
  // 계단 발소리도 똑같이 미리 준비해둠
  AudioService.prefetchSfx(AudioIds.footstepStairsUpA);
  AudioService.prefetchSfx(AudioIds.footstepStairsUpB);
  AudioService.prefetchSfx(AudioIds.footstepStairsDownA);
  AudioService.prefetchSfx(AudioIds.footstepStairsDownB);
  // 대사 리액션 효과음도 같은 이유로 미리 준비해둠 - 대사 중 처음 울리는 순간 디코딩
  // 지연이 있으면 안 됨
  AudioService.prefetchSfx(AudioIds.shock);
  AudioService.prefetchSfx(AudioIds.surprise);
  AudioService.prefetchSfx(AudioIds.ovenDing);
  AudioService.prefetchSfx(AudioIds.confident);
  AudioService.prefetchSfx(AudioIds.pout);

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
      // Navigator를 포함한 트리 전체를 감싸서, 어느 화면에서 탭이 일어나든(iOS 홈
      // 화면 추가 안내의 "확인"이든, 메인 메뉴의 버튼이든) 놓치지 않고 오디오 상태를
      // 확인/복구할 수 있게 함
      builder: (context, child) =>
          _AudioUnlockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

// 웹(특히 아이폰/아이패드 Safari)은 사용자 제스처 없이 재생된 오디오를 막고, 한 번 풀렸던
// 오디오도 탭이 백그라운드로 가거나 전화/Siri/알림 등으로 오디오 세션이 끊기면 다시 잠길 수
// 있음 - 그래서 이 게이트는 첫 탭에서만 동작하고 끝나는 게 아니라, 포인터 다운이 일어날
// 때마다(=세션 내내) AudioService.onUserGesture()를 계속 불러줌. onUserGesture 자체가
// 가벼운 함수라(이미 정상 재생 중이면 바로 return) 매번 불러도 성능에 영향 없음. 예전엔
// _hasUnlocked 플래그로 첫 탭 이후 Listener를 아예 떼어버렸는데, 그러면 나중에 iOS가
// 오디오를 다시 잠갔을 때 풀어줄 방법이 없어서 이렇게 바꿈 - Listener는 위젯 트리에
// 항상 그대로 둠(떼지 않음)
//
// (업데이트: 포인터 다운뿐 아니라 포인터 업에서도 똑같이 onUserGesture를 불러줌.
// onPointerCancel은 제외함 - 드래그가 취소된 경우라 "사용자가 의도한 탭"으로 보기 애매함)
//
// (업데이트 2: iOS Safari는 pointerdown을 "사용자 활성화"로 안 쳐주는 경우가 있어서,
// 거기서 resume()을 부르면 Promise가 영원히 안 끝나고 멈춰있을 수 있다는 게 실기기
// 테스트로 확인됨(진단 패널에 pointerdown/pointerup 로그는 찍히는데 resume 성공 로그가
// 전혀 안 남는 증상). 그래서 resume() 시도는 pointerup(canAttemptResume=true)에서만
// 하고, pointerdown(canAttemptResume=false)에서는 안 함 - 실제 resume 판단은
// WebAudioBackend 쪽에서 함. 또한 Flutter의 Listener 경로는 이벤트가 프레임 단위로
// 지연 전달될 수 있어서 iOS가 활성화로 안 쳐줄 가능성이 있어, WebAudioBackend 생성자에서
// document에 직접 touchend/pointerup/click 네이티브 리스너를 달아서 더 확실하게 잡음 -
// 이 Listener 경로는 그 보조 역할)
class _AudioUnlockGate extends StatelessWidget {
  const _AudioUnlockGate({required this.child});

  final Widget child;

  void _handlePointerEvent(PointerEvent event) {
    // pointerup만 "사용자 활성화로 인정되는 이벤트"로 침 - pointerdown에서 resume()을
    // 부르면 iOS에서 Promise가 안 풀릴 수 있어서(main.dart 위쪽 업데이트2 주석 참고)
    final bool isPointerUp = event is PointerUpEvent;

    // 진단 모드(?audiolog=1)일 때만 터치 하나하나를 로그로 남김 - 평소 플레이 중엔 탭마다
    // 찍히면 콘솔/패널이 너무 시끄러워져서, 맥 없이 아이폰에서 직접 디버깅할 때만 켬.
    // 연속으로 같은 내용이면 audio_log.dart가 알아서 한 줄로 합쳐줌(개수만 증가)
    if (audioDiagnosticsEnabled) {
      final String kind = isPointerUp ? 'pointerup' : 'pointerdown';
      logAudioError(
        '_AudioUnlockGate',
        '$kind 수신(state=${AudioService.audioStateLabel})',
      );
    }
    AudioService.onUserGesture(canAttemptResume: isPointerUp);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerEvent,
      onPointerUp: _handlePointerEvent,
      // 진단 패널은 child 안쪽에 겹쳐서(Stack) 그려짐 - 평소(쿼리 파라미터 없음)엔
      // AudioDiagnosticsOverlay가 child를 그대로 돌려줘서 트리에 아무 영향 없음
      child: AudioDiagnosticsOverlay(child: child),
    );
  }
}
