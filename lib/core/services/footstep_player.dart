// lib/core/services/footstep_player.dart
//
// 캐릭터가 걸을 때 발소리(footstep_a.wav/footstep_b.wav)를 번갈아 재생해주는 공용 헬퍼.
// bakery_game.dart(챕터1 빵집, Flame 컴포넌트)/kitchen_screen.dart/chaeon_room_screen.dart/
// tutorial_screen.dart(Timer.periodic 기반 Flutter 좌표) 전부 캐릭터를 움직이는 방식이
// 서로 다른데, 공통점은 "어딘가에 현재 x좌표 하나가 있다"는 것뿐이라, 그 x좌표를 읽어오는
// 콜백 하나만 받아서 "저번에 체크했을 때랑 좌표가 실제로 달라졌는지"를 직접 비교하는
// 방식으로 구현함. 이렇게 하면 각 화면의 이동/충돌 처리(벽 clamp 등)를 전혀 안 건드리고도,
// "입력은 눌려있지만 벽에 막혀서 실제로는 안 움직이는" 경우나 "대사 중이라 이동이 잠긴"
// 경우를 자동으로 걸러낼 수 있음(좌표가 그대로면 "이동 안 함"으로 판단되니까) - 대사 자동
// 걸음(계단 내려가기 등)으로 좌표가 바뀌는 경우에도 똑같이 걸음 소리가 나는데, 실제로
// 걷는 중이니까 의도된 동작임
//
// (수정: 처음엔 600ms마다 좌표를 비교하는 방식이었는데, 그 주기 자체가 너무 길어서 두 가지
// 문제가 있었음 - (1) 화면 진입/체크포인트 복원으로 좌표가 한 번에 바뀌는 순간이 그 600ms
// 창 안에 끼면 걸음으로 오인됐고(특히 game_play_screen.dart는 start() 호출 시점에
// _game.chaeon이 아직 null이라 0.0을 기준으로 잡았다가, Flame onLoad가 끝나고 실제
// 스폰 위치로 한 번에 "점프"하는 걸 큰 걸음으로 침), (2) "마지막 비교 시점부터 지금까지
// 움직였었는지"만 보니까 방향키를 뗀 뒤에도 최대 600ms 늦게 한 번 더 울렸음. 그래서
// 짧은 주기(kFootstepPollIntervalRef, 이동 틱이랑 비슷한 40ms)로 "지금 이 순간 움직이고
// 있는지"를 먼저 판정하고, 그 판정이 연속으로 이어진 시간을 따로 누적해서 kFootstepIntervalRef
// (걸음 간격)만큼 쌓이면 걸음을 재생하는 2단계 구조로 바꿈. 멈추면 누적을 그 즉시 0으로
// 되돌리고, 순간이동(체크포인트 복원 등)은 판정 자체에서 걸러내고, 화면이 막 열린 직후엔
// 아예 판정을 쉬는 웜업 구간을 둬서 처음 생겼던 두 문제를 둘 다 해결함

import 'dart:async';
import 'dart:math';

import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';

// 좌표를 들여다보는 주기. 각 화면의 실제 이동 틱(40ms, kChaeonKitchenSpeed 기준 틱당
// 9px)이랑 비슷하게 맞춰서, "지금 이 순간 움직이고 있는지"를 그때그때 바로 알 수 있게 함.
// 너무 짧게 잡으면 의미 없이 자주 깨어날 뿐이고, 너무 길게 잡으면 다시 예전처럼 "멈춘 뒤에도
// 한참 뒤에 걸음이 남"는 문제가 재발함 - 화면 보면서 조정 예정
const Duration kFootstepPollIntervalRef = Duration(milliseconds: 40);

// 걸음 간격. chaeon_20/50/80_normal_walk.gif, chaeon_apron_20/80.gif를 직접 바이트
// 단위로 분석해보니 전부 12프레임 x 0.1초 = 1.2초짜리 걷기 사이클이었음(프레임 딜레이가
// 전부 균일하게 10센티초). 한 사이클에 발이 좌/우 두 번 닿는다고 보면 그 절반인 0.6초가
// 한 걸음 간격이 됨. chaeon_walk_right.gif만 13프레임(1.3초)로 살짝 다른데 차이가
// 미미해서(0.05초) 그냥 같은 값을 공유해서 씀 - 화면 보면서 조정 예정
//
// (수정: 역할이 조금 바뀜 - 예전엔 이 간격 자체로 좌표를 비교했는데, 지금은 "연속으로
// 이동 중"으로 판정된 시간이 이 값만큼 쌓일 때마다 한 걸음을 냄. 값 자체는 안 바뀜)
const Duration kFootstepIntervalRef = Duration(milliseconds: 600);

// 계단 오르기 전용 걸음 간격. 평지보다 한 걸음에 더 오래 걸려서(계단 한 칸씩 디딤) 따로
// 둠 - 화면 보면서 조정 예정
const Duration kFootstepStairsUpIntervalRef = Duration(milliseconds: 420);

// 계단 내려가기 전용 걸음 간격 - 화면 보면서 조정 예정
const Duration kFootstepStairsDownIntervalRef = Duration(milliseconds: 380);

// 발소리 재생 속도(피치)를 이 비율만큼 랜덤으로 흔듦(±2%) - scene_dialogue_controller.dart의
// 블립 피치 흔들기(_blipPitchJitterRatio)랑 동일한 패턴. 웹 백엔드만 실제로 반영함
// (AudioService.supportsSfxPlaybackRate 참고)
const double kFootstepPitchJitterRatio = 0.02;

// 발소리 전용 음량 배수(sfxVolume 기준 레벨에 곱해서 적용). 대사 블립(playBlip)은 이런
// 배수가 따로 없이 sfxVolume 레벨을 그대로 쓰는 셈(=1.0배)이라, 발소리는 그보다 살짝
// 작게 들리게 하려고 곱함. 처음엔 0.7이었는데 너무 작게 들려서 0.85로 올림(사용자 볼륨
// 단계가 최대(5단계=1.0)여도 1.0*0.85=0.85라 1.0을 안 넘음) - 화면 보면서 조정 예정
const double kFootstepVolumeMultiplier = 0.85;

// 이 값보다 적게 움직였으면 "제자리"로 치고 그 틱은 "이동 중"이 아니라고 판정함 -
// 부동소수점 오차로 인한 거짓 양성을 막는 최소 임계값. 실제 이동 틱 하나(40ms에 9px,
// kChaeonKitchenSpeed 기준)보다 훨씬 작은 값이라 정상적인 이동은 전부 잡아내고,
// 멈춰있을 때의 미세한 흔들림만 걸러냄
const double kFootstepMinDeltaRef = 0.5;

// 한 폴링 주기 사이에 이 값보다 더 많이 움직였으면 정상적인 걸음이 아니라 순간이동
// (체크포인트 복원, 챕터5/재진입 스폰 위치 조정 등)으로 보고 그 틱은 통째로 무시함(이동
// 중이었는지 아니었는지 상태는 그대로 유지함 - 순간이동 한 번 때문에 걷던 흐름이 끊기거나
// 멈춰있던 게 갑자기 걷는 걸로 바뀌면 안 되니까). 이동 속도(225px/초, kChaeonKitchenSpeed)
// 기준으로 한 폴링 주기(kFootstepPollIntervalRef)에 정상적으로 움직일 수 있는 거리의
// 3배(225*0.04*3=27px) - 화면 보면서 조정 예정
const double kFootstepTeleportThresholdRef = 27.0;

// 화면이 막 열린 직후 이 시간 동안은 좌표가 얼마나 바뀌든 전부 무시함(판정 자체를 쉼) -
// 챕터 진입, 화면 전환 직후, 체크포인트/스폰 위치 재배치 때 좌표가 한 번에 바뀌는 걸
// 걸음으로 오인하는 걸 막는 웜업 구간. 이 구간이 끝나는 시점에 _lastX는 이미 그 사이
// 가장 최근 좌표로 갱신돼 있어서, 웜업이 끝난 뒤부터는 그 시점부터의 진짜 변화만 봄 -
// 화면 보면서 조정 예정
const Duration kFootstepWarmupRef = Duration(milliseconds: 400);

// 지금 어떤 바닥을 걷고 있는지. flat이 기본값이라 setSurface를 한 번도 안 부르면
// 기존 동작(평지 발소리) 그대로임 - 새로 추가한 기능이 기존 호출부에 영향을 안 줌
enum FootstepSurface { flat, stairsUp, stairsDown }

class FootstepPlayer {
  FootstepPlayer({required this.currentX});

  // 지금 캐릭터의 x좌표를 읽어오는 콜백. 화면마다 다른 필드(_chaeonX, _playerX,
  // game.chaeon?.position.x 등)를 그대로 넘겨주면 됨 - 이 클래스는 그 값이 "자기가
  // 마지막으로 봤던 값"과 다른지만 비교함
  final double Function() currentX;

  Timer? _timer;
  double? _lastX;
  bool _nextIsLeft = true;
  final Random _random = Random();

  // 기본값 flat - 평지/계단 오르기/계단 내려가기 구분. setSurface()로 언제든 바꿀 수
  // 있고, 바꿔도 타이머나 누적값을 안 건드려서 소리가 끊기거나 겹치지 않고 다음 걸음부터
  // 바로 새 바닥 소리로 이어짐
  FootstepSurface _surface = FootstepSurface.flat;

  // 걸을 때마다(계단 포함) 구간이 바뀔 수 있는 화면(예: 릴리안이 계단을 오른 다음 평지를
  // 걷는 연출)에서 currentX 콜백 쪽이 매 틱 호출함. _tick()이 진행 중인 걸음 판정이나
  // 타이머를 전혀 안 건드리니까, 전환이 매끄럽게 이어짐
  void setSurface(FootstepSurface surface) {
    _surface = surface;
  }

  // true면 currentX가 멈춰있어도(좌표 변화 없어도) 무조건 "이동 중"으로 취급함 - 계단
  // 이동 애니메이션이 끝나고 좌표가 멈춘 뒤에도, 화면이 검게 덮이는 동안은 계단 발소리가
  // 계속 이어지게 하려는 용도. setSurface랑 마찬가지로 타이머/누적값은 안 건드리니까
  // 끄고 켜도 걸음 리듬이 안 끊김. 끄면(false) 그 다음 틱부터 다시 좌표 변화로만 판단함
  void setForceWalking(bool forceWalking) {
    _forceWalking = forceWalking;
  }

  bool _forceWalking = false;

  // 지금 surface에 맞는 (왼발, 오른발, 걸음 간격)을 돌려줌
  (String, String, Duration) _soundSetForSurface() {
    switch (_surface) {
      case FootstepSurface.flat:
        return (AudioIds.footstepA, AudioIds.footstepB, kFootstepIntervalRef);
      case FootstepSurface.stairsUp:
        return (
          AudioIds.footstepStairsUpA,
          AudioIds.footstepStairsUpB,
          kFootstepStairsUpIntervalRef,
        );
      case FootstepSurface.stairsDown:
        return (
          AudioIds.footstepStairsDownA,
          AudioIds.footstepStairsDownB,
          kFootstepStairsDownIntervalRef,
        );
    }
  }

  // "연속으로 이동 중"으로 판정된 시간의 누적값(ms). kFootstepIntervalRef를 넘을 때마다
  // 한 걸음을 재생하고 그만큼만 빼줌(완전히 0으로 안 돌리고 초과분을 남겨서 다음 걸음
  // 타이밍이 밀리지 않게 함). 멈추거나 순간이동이 아닌 게 확인되는 즉시 0으로 리셋됨
  int _movingDurationMs = 0;

  // 바로 직전 틱이 "이동 중"으로 판정됐는지. false -> true로 막 바뀐 틱에서만 첫 걸음을
  // 0.6초 기다리지 않고 즉시 냄(짧게 눌렀다 떼는 경우에도 최소 한 번은 나게 하려는 목적)
  bool _wasMoving = false;

  // start() 호출 시점부터 지난 시간(ms). 웜업 구간이 끝났는지 판단하는 데만 씀
  int _elapsedSinceStartMs = 0;

  // 화면 initState에서 한 번 불러서 시작함. 이미 시작돼 있으면 먼저 멈추고 다시 시작함
  void start() {
    stop();
    _lastX = currentX();
    _movingDurationMs = 0;
    _wasMoving = false;
    _elapsedSinceStartMs = 0;
    _forceWalking = false; // 재시작할 땐 항상 꺼진 상태로 시작함
    _timer = Timer.periodic(kFootstepPollIntervalRef, (_) => _tick());
  }

  void _tick() {
    final int pollMs = kFootstepPollIntervalRef.inMilliseconds;
    _elapsedSinceStartMs += pollMs;

    final double x = currentX();
    final double? last = _lastX;
    _lastX = x;
    if (last == null) return;

    // 웜업 구간 - 위 kFootstepWarmupRef 주석 참고. _lastX는 이미 위에서 갱신했으니
    // 웜업이 끝나는 바로 다음 틱부터는 그 시점부터의 변화만 보게 됨
    if (_elapsedSinceStartMs <= kFootstepWarmupRef.inMilliseconds) return;

    final double delta = (x - last).abs();

    // 순간이동 - 이 틱은 통째로 무시하고 이동 중/정지 상태를 그대로 유지함
    if (delta > kFootstepTeleportThresholdRef) return;

    // forceWalking 중엔 좌표 변화(delta)를 아예 안 보고 무조건 이동 중으로 침
    final bool isMovingNow = _forceWalking || delta >= kFootstepMinDeltaRef;

    if (!isMovingNow) {
      // 멈춘 순간 바로 누적을 0으로 - 그 뒤로는 다시 움직이기 시작해야만 소리가 남
      _movingDurationMs = 0;
      _wasMoving = false;
      return;
    }

    if (!_wasMoving) {
      // 막 움직이기 시작한 틱 - 0.6초를 기다리지 않고 바로 한 걸음 냄
      _wasMoving = true;
      _movingDurationMs = 0;
      _playOneStep();
      return;
    }

    // 걸음 간격도 지금 surface 기준으로 매번 다시 읽음 - 구간 중간에 setSurface로
    // 간격이 바뀌어도(평지<->계단) 다음 누적 비교부터 바로 새 간격을 따름
    final Duration interval = _soundSetForSurface().$3;
    _movingDurationMs += pollMs;
    if (_movingDurationMs >= interval.inMilliseconds) {
      _movingDurationMs -= interval.inMilliseconds;
      _playOneStep();
    }
  }

  void _playOneStep() {
    final (String sfxA, String sfxB, _) = _soundSetForSurface();
    final String sfxId = _nextIsLeft ? sfxA : sfxB;
    _nextIsLeft = !_nextIsLeft;
    final double playbackRate = AudioService.supportsSfxPlaybackRate
        ? 1.0 + (_random.nextDouble() * 2 - 1) * kFootstepPitchJitterRatio
        : 1.0;
    // 재생 자체가 실패해도(디코딩 실패, iOS에서 context가 suspended인 채 등) 여기서 안 잡고
    // 그냥 흘려보냄 - 발소리는 연출일 뿐이라 실패해도 이동이 막히면 안 됨. playSfx 쪽에서
    // 이미 try/catch로 조용히 삼키게 돼있음(scene_dialogue_controller.dart의 블립 재생
    // 주석이랑 동일한 이유)
    unawaited(
      AudioService.playSfx(
        sfxId,
        playbackRate: playbackRate,
        volumeMultiplier: kFootstepVolumeMultiplier,
      ),
    );
  }

  // 화면 dispose에서 반드시 불러줘야 함 - 안 그러면 타이머가 화면이 사라진 뒤에도 계속 돎
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
