// lib/core/widgets/dialogue_overlay.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/utils/image_warmup.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart';

class DialogueOverlay extends StatefulWidget {
  // Flame 오버레이로 쓸 때만 넘어옴(프롤로그 경로). 클래스 내부에서 실제로 참조하는 곳은
  // 없어서 nullable로 바꿔도 별도 가드 없이 안전함. 순수 Flutter 위젯으로 쓸 때는 안 넘기면 됨
  final BakeryGame? game;
  // null이면 기존 _prologueData를 그대로 재생. 값이 있으면(예: 챕터4 컷씬) 그 데이터로 재생함
  final List<Map<String, String>>? data;
  // null이면 기존처럼 마지막 탭에서 Navigator.pop(context, true) 호출. 값이 있으면 그 콜백을 대신 호출함
  final VoidCallback? onComplete;

  const DialogueOverlay({super.key, this.game, this.data, this.onComplete});

  @override
  State<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends State<DialogueOverlay> {
  // 현재 진행 중인 프롤로그 인덱스
  int _currentIndex = 0;

  // (신규: 컷씬(widget.data != null) 이미지 프리로딩/정리. 예전엔 kitchen_screen.dart/
  // chaeon_room_screen.dart가 각 컷씬 데이터 전체(최대 47장, 그중 26장이 3500x2032라
  // 장당 28.5MB)를 화면 진입 시점에 미리 다 당겨놔서, 순간 메모리가 900MB대까지 뜰 수
  // 있었음. 지금은 여기서 "지금 보여줄 이미지 + 다음 1장"만 순서대로(await로 하나씩,
  // 동시에 두 장 이상 안 돌림) 당겨두고, 지나간 이미지는 다시 안 쓰면 캐시에서 비움.
  // 프롤로그(widget.data == null)는 이미 main_screen.dart 로딩 화면에서 8장 전부를
  // 미리 디코딩+GPU 워밍업까지 끝내두는 기존 방식 그대로라 여기서는 안 건드림

  // 한 번에 몇 장 앞서 당겨둘지(현재 포함). 1이면 "현재 + 다음 1장" = 항상 최대 2장만
  // 디코딩된 상태로 유지됨. 화면 보면서 조정 예정
  static const int _cutsceneLookaheadCount = 1;

  // 프롤로그는 이미 다 준비돼있어서 게이트가 필요 없음(바로 true). 컷씬은 첫 이미지
  // 프리로딩이 끝나야 true로 바뀜 - 그 전에는 build()가 빈 배경만 보여줘서, 아직 안 뜬
  // 이미지로 Image.asset이 번쩍이는 걸 막음
  bool _isReady = false;

  // didChangeDependencies가 여러 번 불려도 프리로딩이 중복으로 안 걸리게 막는 용도
  bool _hasStartedCutscenePreload = false;

  // 지금까지 당겨놓은 가장 뒤쪽 인덱스(-1이면 아직 하나도 안 당김). 같은 인덱스를
  // 두 번 당기지 않으려고 기준점으로 씀
  int _highestPreloadedIndex = -1;

  // 이미 evict한 asset 경로. 한 번 비운 걸 또 비우려고 매번 전체를 다시 훑지 않게 기록해둠
  final Set<String> _evictedCutsceneAssets = {};

  // 프리로딩 요청을 전부 이 Future 체인에 이어 붙여서, 여러 번 겹쳐 불려도(초기 진입 +
  // 탭마다) 실제 precacheAndWarmUpAsset은 항상 하나씩 순서대로만 돌게 함 -
  // audio_backend_web.dart의 BGM 디코딩 큐랑 동일한 패턴
  Future<void> _cutscenePreloadQueue = Future.value();

  // 이미지 및 대사 매칭 데이터 리스
  final List<Map<String, String>> _prologueData = [
    {"text": "한 마을에는 상처입은 사람들의 감정이 눈꽃처럼 녹아내리고 있었어요", "image": "prolog_1.png"},
    {"text": "사고로 엄마를 떠나보낸 소녀, 채온도 마찬가지였죠.", "image": "prolog_2.png"},
    {"text": "그 아픈 상처는 소녀의 마음에서 감정이라는 온기를 지웠습니다.", "image": "prolog_2.png"},
    {
      "text": "감정이 사라진 소녀에게 남은 것은 추위와 엄마를 향한 그리움 뿐이었죠.",
      "image": "prolog_3.png",
    },
    {"text": "상실의 고통은 소녀를 이루던 색깔마저 빼앗아 갔습니다.", "image": "prolog_3.png"},
    {"text": "그러던 어느 날의 밤, 소녀의 꿈 속에 엄마가 찾아왔습니다.", "image": "prolog_4.png"},
    {"text": "“엄마...”", "image": "prolog_4.png"},
    {
      "text": "엄마를 향해 환하게 웃어주고 싶었던 소녀에게 미소란, 잊은지 오래된 감정이었죠.",
      "image": "prolog_5.png",
    },
    {
      "text": "소녀는 결심했어요. 언젠가 다시, 꿈에서 엄마를 만난다면 가장 예쁜 미소를 선물할 것이라고.",
      "image": "prolog_6.png",
    },
    {
      "text": "미소는 기쁨의 감정 중 하나, 소녀는 감정을 되찾아야했고 그 방법을 찾으려고 결심했어요",
      "image": "prolog_6.png",
    },
    {
      "text": "수소문 끝에 채온은 감정을 굽는다는 빵집의 존재를 알게 되며 그 곳을 찾아나섰어요.",
      "image": "prolog_7.png",
    },
    {
      "text": "한참을 걷던 그때, 골목 끝에서 따뜻한 온기와 함께 달콤한 향기가 밀려왔습니다.",
      "image": "prolog_8.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    // 프롤로그는 애초에 게이트 자체가 필요 없음 - main_screen.dart가 이미 다 준비해둠
    _isReady = widget.data == null;
  }

  // precacheImage/precacheAndWarmUpAsset은 BuildContext를 써야 해서 initState보다
  // didChangeDependencies에서 시작하는 게 맞음(다른 화면들이랑 동일한 패턴)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.data == null || _hasStartedCutscenePreload) return;
    _hasStartedCutscenePreload = true;
    _scheduleCutscenePreloadUpTo(_cutsceneLookaheadCount);
  }

  // 한 장 프리로드가 이 시간 안에 안 끝나면 포기하고 넘어감(네트워크가 완전히 멈춰서
  // precacheImage의 Future 자체가 영원히 안 끝나는 경우 대비) - 실패해도 다음 이미지나
  // 게이트 풀기가 거기서 막혀버리면 안 되니까 상한선을 둠. 화면 보면서 조정 예정
  static const Duration _cutscenePreloadTimeout = Duration(seconds: 5);

  // targetIndex까지(현재 당겨놓은 것 다음부터) 큐에 쭉 이어붙임. _cutscenePreloadQueue에
  // 체이닝하는 거라, 초기 진입 호출이랑 탭마다의 호출이 겹쳐도 실제 precache는 항상
  // 하나씩 순서대로만 돌고, 이미 당겨놓은 인덱스는 건너뜀
  //
  // (수정: .catchError((_) {})를 추가함 - _preloadCutsceneRange 안에서 거의 다 막아두긴
  // 했지만, 혹시 거기서 못 막은 예외가 올라와도 여기서 한 번 더 삼켜서 _cutscenePreloadQueue
  // 자체는 항상 "성공한 Future"로 남게 함. 안 그러면 한 번 실패한 뒤로 체이닝된 .then()들이
  // 전부 실행 안 되고 건너뛰어져서, 이후 모든 프리로드 요청이 멈춰버림)
  void _scheduleCutscenePreloadUpTo(int targetIndex) {
    final List<Map<String, String>>? data = widget.data;
    if (data == null || data.isEmpty) return;
    final int clampedTarget = targetIndex.clamp(0, data.length - 1);
    _cutscenePreloadQueue = _cutscenePreloadQueue
        .then((_) => _preloadCutsceneRange(data, clampedTarget))
        .catchError((_) {});
  }

  Future<void> _preloadCutsceneRange(
    List<Map<String, String>> data,
    int targetIndex,
  ) async {
    for (int i = _highestPreloadedIndex + 1; i <= targetIndex; i++) {
      if (!mounted) return;
      final String asset = 'assets/images/${data[i]["image"]}';
      try {
        // precacheAndWarmUpAsset 자체도 내부적으로 try/catch로 실패(디코딩 에러 등)를
        // 삼키는 함수지만, 그건 "실패로 끝나는" 경우만 막아주는 거라 네트워크가 멈춰서
        // Future가 영원히 안 끝나는 경우까진 못 막음 - 그래서 여기서 timeout을 한 번 더
        // 걸어서 그 경우도 결국 넘어가게 함
        await precacheAndWarmUpAsset(
          asset,
          context,
        ).timeout(_cutscenePreloadTimeout, onTimeout: () {});
      } catch (_) {
        // 이론상 위에서 거의 다 막히지만, 혹시 못 막은 예외가 와도 여기서 한 번 더 삼킴 -
        // 이 이미지 하나가 실패했다고 다음 이미지 프리로드나 게이트 풀기가 멈추면 안 됨
      } finally {
        // 성공/실패/타임아웃 상관없이 항상 여기로 와서 진행함. 실패했으면 이 이미지는
        // 캐시에 안 올라가 있겠지만, 그러면 Image.asset이 그려지는 시점에 직접 디코딩해서
        // 보여줌(그 순간 살짝 로딩이 비칠 수는 있어도, 빈 화면에서 영원히 안 넘어가는 것보단 나음)
        _highestPreloadedIndex = i;
        // 첫 이미지(인덱스 0)는 성공/실패 상관없이 여기서 게이트를 풀어서 화면을 보여줌
        if (i == 0 && !_isReady && mounted) {
          setState(() => _isReady = true);
        }
      }
    }
  }

  // currentIndex보다 앞서 지나간 이미지 중, currentIndex부터 끝까지 다시는 안 나오는
  // 것만 evict함. 같은 이미지를 바로 다음이나 나중에 또 쓰는 경우(예: prolog_2.png가
  // 연속 두 대사에서 쓰이는 것처럼)는 그대로 캐시에 남겨둠
  void _evictPastCutsceneImages(
    List<Map<String, String>> data,
    int currentIndex,
  ) {
    for (int i = 0; i < currentIndex; i++) {
      final String asset = 'assets/images/${data[i]["image"]}';
      if (_evictedCutsceneAssets.contains(asset)) continue;
      final bool usedAgainLater = data
          .skip(currentIndex)
          .any((d) => 'assets/images/${d["image"]}' == asset);
      if (usedAgainLater) continue;
      PaintingBinding.instance.imageCache.evict(AssetImage(asset));
      _evictedCutsceneAssets.add(asset);
    }
  }

  // 컷씬이 완전히 끝날 때(마지막 탭) 부름 - 이 데이터셋의 이미지는 이제 전부 다시 안 쓰이니
  // 남아있는 것 전부 비움
  void _evictAllCutsceneImages(List<Map<String, String>> data) {
    for (final entry in data) {
      final String asset = 'assets/images/${entry["image"]}';
      if (_evictedCutsceneAssets.contains(asset)) continue;
      PaintingBinding.instance.imageCache.evict(AssetImage(asset));
      _evictedCutsceneAssets.add(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // data가 없으면(프롤로그 경로) 기존 _prologueData 그대로 씀
    final List<Map<String, String>> activeData = widget.data ?? _prologueData;

    // 컷씬 경로에서 첫 이미지가 아직 준비 안 됐으면, Image.asset이 번쩍이는 대신 그냥
    // 빈 배경만 보여줌. 한 장만 기다리는 거라 보통 눈에 띌 정도로 오래 걸리진 않음
    if (!_isReady) {
      return Container(color: const Color(0xFF1A1A1A), width: w, height: h);
    }

    final currentData = activeData[_currentIndex];

    return GestureDetector(
      onTap: () {
        // 컷씬이 완전히 끝나는 탭이면(마지막 대사), onComplete/pop 부르기 전에 이
        // 데이터셋 이미지를 전부 비워둠 - 끝난 컷씬 이미지는 다신 안 쓰이니까
        if (widget.data != null && _currentIndex >= activeData.length - 1) {
          _evictAllCutsceneImages(activeData);
        }
        setState(() {
          // 마지막 대사인 경우 오버레이를 닫고 인게임 진입
          if (_currentIndex >= activeData.length - 1) {
            // onComplete가 있으면(챕터4 컷씬 등 재사용 경로) 그걸 호출하고,
            // 없으면 기존처럼 챕터 선택 스크린으로 결과값 true, 게임 화면 닫고 복귀
            if (widget.onComplete != null) {
              widget.onComplete!();
            } else {
              Navigator.pop(context, true);
            }
          } else {
            _currentIndex++;
            // 컷씬 경로면 인덱스가 넘어간 김에 지나간 이미지 정리 + 다음 이미지 당겨오기도 같이 함
            if (widget.data != null) {
              _evictPastCutsceneImages(activeData, _currentIndex);
              _scheduleCutscenePreloadUpTo(
                _currentIndex + _cutsceneLookaheadCount,
              );
            }
          }
        });
      },
      child: Container(
        color: const Color(0xFF1A1A1A), // 인게임 화면을 가리기 위한 배경색
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 스토리 일러스트 레이어. 다른 화면들(빵만들기, 시계 미니게임 등)과 동일하게
            // BoxFit.cover로 화면을 항상 빈틈없이 채움. fitWidth를 쓰면 창을 세로로 늘렸을 때
            // 이미지 원본 비율 때문에 위아래에 빈 공간이 생겼음
            //
            // AnimatedSwitcher로 짧은 크로스페이드를 줌 - 탭할 때마다 컷 전환처럼 번쩍이던 걸
            // 완화하려는 목적. 원래는 widget.data == null(프롤로그 경로)일 때만 이렇게 하고
            // widget.data가 있는 다른 컷씬(챕터4/5 past/dream/엔딩 등)은 그냥 Image.asset을
            // 바로 바꿔 끼워서 탭마다 번쩍거렸는데, 이 위젯을 같이 쓰는 이상 굳이 프롤로그만
            // 다르게 둘 이유가 없어서 전부 같은 크로스페이드를 타게 통일함(프롤로그 쪽 동작은
            // 그대로 유지됨 - data==null이면 전이랑 똑같이 동작함). 프롤로그 이미지는
            // main_screen.dart에서 미리 디코딩+GPU 워밍업까지 끝내놓고, 다른 컷씬 이미지는
            // (수정: 예전엔 각 컷씬을 trigger하는 화면(kitchen_screen.dart,
            // chaeon_room_screen.dart) 쪽에서 데이터 전체를 미리 당겨둬야 했는데, 이제는 이
            // 위젯이 didChangeDependencies/_isReady 게이트로 자기 데이터 기준 현재+다음
            // 1장만 스스로 당겨두고 화면을 보여줘서, trigger하는 화면 쪽에서 더 손 안 대도 됨
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Image.asset(
                  'assets/images/${currentData["image"]}',
                  key: ValueKey(currentData["image"]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // 2층: 하단 대사창 영역
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: rH(80),
                color: Colors.black.withOpacity(0.6), // 대사창 가독성을 위한 반투명 박스
                padding: EdgeInsets.symmetric(
                  horizontal: rW(50),
                  vertical: rH(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 대사 텍스트 출력 구역
                    Expanded(
                      child: Text(
                        currentData["text"]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: rW(18),
                          fontWeight: FontWeight.w400,
                          fontFamily: 'SCDream',
                        ),
                      ),
                    ),
                    // 우측 하단 클릭 인디케이터 삼각형
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: rW(24),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
