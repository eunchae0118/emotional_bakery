// lib/features/menu/chapter_select_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/constants/audio_ids.dart';
import 'package:emotional_bakery/core/services/audio_service.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/save_resume.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/utils/image_warmup.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart'
    show ReentryChapter;
import 'package:emotional_bakery/features/chapter1/game_play_screen.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';
import 'package:emotional_bakery/features/chapter3/chaeon_room_screen.dart';
import 'package:emotional_bakery/features/menu/choice_screen.dart'
    show kChoiceScreenRouteSettings;
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';

// "챕터가 잠겨있습니다" 배지가 뜨는 top 위치(874x402 기준, rH로 스케일됨). 원래
// kitchen_screen.dart/game_play_screen.dart랑 동일하게 80을 썼는데, 카드 썸네일
// 바로 위에 붙어서 너무 가까워 보여서 더 위로 올림 - 화면 보면서 조정 예정
const double _lockedChapterNoticeTopRef = 45;

// 한 화면에 한 번에 보여줄 챕터 카드 수(가로 폭 기준). 아이패드처럼 세로가 긴 화면에서
// 카드가 sh(220)까지 꽉 차게 커지면 한 번에 카드가 1장만 보여서 답답해지길래, 가로 폭
// 상한(cardWidthCap)을 역산할 때 쓰는 목표값으로 뺐음. 숫자만 바꾸면 한 화면에 보이는
// 카드 수가 바로 조정됨
const double kChapterVisibleCardCount = 1.5;

class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  // 스크롤 위치 감지용 컨트롤러
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  // 잠긴 챕터 탭했을 때 잠깐 뜨는 안내 문구. kitchen_screen.dart의 저장 확인 배지
  // (_saveConfirmationText/_saveConfirmationTimer)랑 동일한 패턴. null이면 안 보임
  String? _lockedChapterNoticeText;
  Timer? _lockedChapterNoticeTimer;

  @override
  void dispose() {
    _lockedChapterNoticeTimer?.cancel();
    super.dispose();
  }

  // 잠긴 챕터 썸네일 탭했을 때 부름. buildSaveConfirmationBadge를 그대로 재사용해서
  // "저장되었습니다"랑 동일한 디자인/지속시간(2초)으로 "챕터가 잠겨있습니다"를 띄움
  void _showLockedChapterNotice() {
    setState(() => _lockedChapterNoticeText = '챕터가 잠겨있습니다');
    _lockedChapterNoticeTimer?.cancel();
    _lockedChapterNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _lockedChapterNoticeText = null);
    });
  }

  // "현재 진행 중인 챕터" 카드를 탭했을 때 부름(여기 도달했다는 건 위 잠금 체크를
  // 통과했다는 뜻이라 chapterNumber == highestUnlocked && !hasSeenEnding가 항상 성립함).
  // 세이브 파일이 있으면 choice_screen.dart의 "이어하기"랑 완전히 동일한 방식
  // (save_resume.dart의 screenForCheckpoint)으로 그 체크포인트로 바로 이동해서, 챕터를
  // 처음부터 다시 시작하다가 온도/선택 변수가 실제 세이브랑 달라지는 문제를 막음.
  // 세이브가 아예 없으면(이번 세션에 저장을 한 번도 안 하고 진행만 한 경우 등)
  // fallbackScreen으로 기존처럼 챕터 맨 처음부터 시작함
  Future<void> _enterCurrentChapter(Widget fallbackScreen) async {
    final SaveData? data = await SaveManager.load();
    if (mounted && data != null) {
      restoreStoryStateFromSave(data);
      final SaveCheckpoint? checkpoint = resolveSaveCheckpoint(data);
      if (checkpoint != null) {
        Navigator.push(
          context,
          fadeThroughBlackRoute(screenForCheckpoint(checkpoint, data)),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(context, fadeThroughBlackRoute(fallbackScreen));
  }

  // 뒤로가기 버튼이 부름. 이 화면으로 들어오는 경로가 두 가지라 둘 다 처리해야 함:
  // (1) ChoiceScreen에서 일반적으로 push해 들어온 경우(아래에 'choice' 라우트가 그대로 있음)
  // (2) 챕터 종료 후 goToChapterSelectClearingStack(pushAndRemoveUntil)으로 들어온
  // 경우(스택이 이미 'choice' 라우트 + 이 화면만 남도록 정리돼 있음). 두 경우 다 스택 안에
  // 'choice' 이름 라우트가 반드시 있어서(choice_screen.dart 상단 주석 참고, ChoiceScreen을
  // push하는 곳은 전부 kChoiceScreenRouteSettings를 넘김) popUntil로 거기까지 돌아가면 됨.
  // 혹시 못 찾는 예외 상황(방어적 안전장치)엔 그냥 한 번 pop만 함
  void _goBackToMainMenu(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    bool foundChoiceRoute = false;
    navigator.popUntil((route) {
      if (route.settings.name == kChoiceScreenRouteSettings.name) {
        foundChoiceRoute = true;
        return true;
      }
      // 맨 아래 라우트까지 왔는데도 못 찾았으면 더 못 가니까 여기서 멈춤
      return route.isFirst;
    });
    if (!foundChoiceRoute && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    // 메인 메뉴/엔딩보기/빵집이랑 같은 곡. 이미 main_theme이 재생 중이면(메인 메뉴에서
    // 넘어온 평소 경로) AudioService가 알아서 아무것도 안 함
    AudioService.playBgm(AudioIds.mainTheme);
    // BakeryGame(Flame)이 쓰는 배경/채온이 스프라이트를 미리 데워둠. Flame.images는 앱
    // 전역에서 공유되는 static 캐시라, 여기서 한 번만 로드해두면 이후 챕터1/3/4/5 중
    // 어느 경로로 GamePlayScreen에 처음 들어가든 로딩 중 검은 화면이 안 보임
    // 배경은 CPU 디코딩만 하면 첫 페인트 때 GPU 업로드가 몰려서 프레임드랍이 생기니까 업로드까지 해둠
    loadAndWarmUpFlameImage(kBakeryBgFlameImage);
    Flame.images.load('chaeon_idle_right.gif');
    // 스크롤 발생 시 하단 바 위치 계산
    _scrollController.addListener(() {
      setState(() {
        if (_scrollController.hasClients) {
          _scrollProgress =
              _scrollController.offset /
              _scrollController.position.maxScrollExtent;
        }
      });
    });
  }

  // didChangeDependencies가 여러 번 불려도 워밍업이 중복으로 안 걸리게 막는 용도
  bool _hasStartedBgWarmUp = false;

  // 챕터 카드/세이브 이어하기로 바로 들어갈 수 있는 dpad 화면들 배경(골목길, 채온이 방)을
  // 미리 디코딩 + GPU 업로드까지 데워둠. 빵집 배경(Flame)은 위 initState에서 처리함.
  // precacheImage가 BuildContext를 써야 해서 initState가 아니라 여기서 부름
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedBgWarmUp) return;
    _hasStartedBgWarmUp = true;
    precacheAndWarmUpAsset(kTutorialBgAsset, context);
    precacheAndWarmUpAsset(kRoomBgAsset, context);
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    // 챕터 리스트 영역(카드/글자/간격/패딩/스크롤바) 전용 높이 기준 단일 스케일. 가로(rW)
    // 세로(rH)를 따로 섞어 쓰면, 아이패드처럼 세로가 유독 긴 화면에서 리스트 영역이 화면
    // 높이 대비 작아 보이는 문제가 있었음 - 이 영역 전체를 세로 하나로 통일해서 고침
    double sh(double px) => (px / 402) * h;
    // 뒤로가기 버튼 전용 단일 스케일. ending_gallery_screen.dart 뒤로가기 버튼이랑 완전히
    // 같은 식을 써서, 같은 기기에서 두 화면 버튼이 항상 같은 크기로 보이게 함
    final double uScale = math.min(w / 874, h / 402);
    double u(double px) => px * uScale;

    // 가장 최근에 해금된 챕터 번호. 재플레이 잠금 판단 기준으로 씀 - 이 번호보다 작은 챕터는
    // 이미 지나간 챕터고, 이 번호랑 같아도 엔딩까지 봤으면(hasSeenEnding) 더는 재진입 못 하게 함
    int highestUnlocked = 0;
    if (ChapterProgress.isChapter1Unlocked) highestUnlocked = 1;
    if (ChapterProgress.isChapter2Unlocked) highestUnlocked = 2;
    if (ChapterProgress.isChapter3Unlocked) highestUnlocked = 3;
    if (ChapterProgress.isChapter4Unlocked) highestUnlocked = 4;
    if (ChapterProgress.isChapter5Unlocked) highestUnlocked = 5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경 레이어
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/main_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 챕터 리스트 (가로 스크롤)
          Positioned(
            top: sh(40),
            bottom: sh(60),
            left: 0,
            right: 0,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // 끝에서 튕기는 스크롤 효과
              padding: EdgeInsets.symmetric(horizontal: sh(80)), // 양옆 여백
              children: [
                _buildChapterCard(
                  "Prolog",
                  "색을 잃은 아이",
                  "ch_prolog.png",
                  true,
                  sh,
                  w,
                  // 프롤로그는 재플레이 잠금 대상(챕터 1~5) 밖이라 번호 없음
                  null,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 1",
                  "신비한 빵집",
                  "ch1.png",
                  ChapterProgress.isChapter1Unlocked, // 프롤로그 클리어하면 전역으로 해금됨
                  sh,
                  w,
                  1,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 2",
                  "감정의 빵",
                  "ch2.png",
                  ChapterProgress.isChapter2Unlocked, // 챕터1 종료하면 전역으로 해금됨
                  sh,
                  w,
                  2,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 3",
                  "잃는 것과 얻는 것",
                  "ch3.png",
                  ChapterProgress.isChapter3Unlocked, // 챕터2 종료하면 전역으로 해금됨
                  sh,
                  w,
                  3,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 4",
                  "슬픔을 마주할 용기",
                  "ch4.png",
                  ChapterProgress.isChapter4Unlocked, // 챕터3 종료하면 전역으로 해금됨
                  sh,
                  w,
                  4,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 5",
                  "진짜 감정을 마주할 시간",
                  "ch5.png",
                  ChapterProgress.isChapter5Unlocked, // 챕터4 챕터5행 엔딩 보면 전역으로 해금됨
                  sh,
                  w,
                  5,
                  highestUnlocked,
                ),
              ],
            ),
          ),

          // 개발용 임시 버튼 모음. 챕터1~5 화면을 매번 순서대로 안 거치고 바로 테스트하려고
          // 세로로 쌓아둔 지름길 버튼들. 전부 임시 개발용 코드라 나중에 통째로 지울 것
          Positioned(
            right: sh(10),
            bottom: sh(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 챕터1도 잠금이나 프롤로그/튜토리얼 안 거치고 바로 GamePlayScreen으로 진입.
                // 챕터2 버튼처럼 잠금 체크 없이 바로 들어감. 임시 개발용 코드
                GestureDetector(
                  onTap: () {
                    // DEV 버튼은 매번 같은 상태에서 테스트해야 재현이 되니까, 이전 플레이에서
                    // 남은 온도값을 여기서 기본값(3)으로 리셋하고 들어감
                    StoryState.currentTemperature = 3;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const GamePlayScreen(isPrologue: false),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터1 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: sh(10),
                    ),
                  ),
                ),
                SizedBox(height: sh(4)),
                // 개발용 임시 버튼: 챕터2 테스트하려고 프롤로그부터 챕터1 전체를 매번 다시 플레이하기
                // 번거로워서 만든 지름길. 화면 구석에 눈에 안 띄게 작게 배치. 나중에 지울 코드
                GestureDetector(
                  onTap: () {
                    // 위 챕터1 버튼이랑 동일한 이유로 리셋하고 들어감
                    StoryState.currentTemperature = 3;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KitchenScreen(
                          mode: KitchenScreenMode.chapter2Start,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터2 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: sh(10),
                    ),
                  ),
                ),
                SizedBox(height: sh(4)),
                // 챕터4/5는 화면 자체가 아직 없어서 이동하면 에러남. 탭하면 화면 전환 없이
                // 스낵바로 미구현 안내만 잠깐 띄우고 끝냄. 임시 개발용 코드
                // 챕터3은 채온이 방 화면부터 바로 시작. 다른 DEV 버튼들이랑 동일하게 잠금 체크 없음
                GestureDetector(
                  onTap: () {
                    // 위 챕터1/2 버튼이랑 동일한 이유로 리셋하고 들어감
                    StoryState.currentTemperature = 3;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChaeonRoomScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터3 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: sh(10),
                    ),
                  ),
                ),
                SizedBox(height: sh(4)),
                // 챕터4도 챕터3이랑 동일하게 채온이 방 화면부터 시작. mode만 chapter4로 넘겨줌
                GestureDetector(
                  onTap: () {
                    // 위 챕터1/2/3 버튼이랑 동일한 이유로 리셋하고 들어감
                    StoryState.currentTemperature = 3;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChaeonRoomScreen(
                          mode: ChaeonRoomMode.chapter4,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터4 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: sh(10),
                    ),
                  ),
                ),
                SizedBox(height: sh(4)),
                // 챕터5는 골목길/방 없이 빵집(GamePlayScreen)에서 바로 시작. skipChapter1Events도
                // 같이 true로 넘겨야 챕터1 가이드 대사/릴리안 계단 등장 트리거가 안 새어나감
                // (tutorial_screen.dart가 챕터3/4 진입할 때 derive해주는 값이랑 동일).
                // 다른 DEV 버튼들이랑 동일하게 fadeThroughBlackRoute 없이 바로 push함
                // (로딩 지연은 initState의 Flame.images 프리캐싱으로 대응)
                GestureDetector(
                  onTap: () {
                    // 위 챕터1/2/3/4 버튼이랑 동일한 이유로 리셋하고 들어감
                    StoryState.currentTemperature = 3;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GamePlayScreen(
                          skipChapter1Events: true,
                          reentryChapter: ReentryChapter.chapter5,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터5 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: sh(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 스크롤 진행 바
          Positioned(
            bottom: sh(30),
            left: sh(100),
            right: sh(100),
            child: Stack(
              children: [
                // 바닥 배경 줄
                Container(
                  height: sh(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 현재 위치 표시 줄 (움직이는 바)
                FractionallySizedBox(
                  widthFactor: 0.3,
                  child: Transform.translate(
                    offset: Offset((sh(874 - 200) * 0.7) * _scrollProgress, 0),
                    child: Container(
                      height: sh(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5C18B), // 베이지색 포인트 컬러
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 잠긴 챕터 안내 배지. kitchen_screen.dart의 저장 완료 배지랑 동일한 위치/스타일
          // (buildSaveConfirmationBadge 재사용) - _showLockedChapterNotice가 2초 뒤 스스로 지움
          if (_lockedChapterNoticeText != null)
            Positioned(
              top: sh(_lockedChapterNoticeTopRef),
              left: 0,
              right: 0,
              child: Center(
                child: widgets.buildSaveConfirmationBadge(
                  _lockedChapterNoticeText!,
                  rW: sh,
                  rH: sh,
                ),
              ),
            ),

          // 뒤로가기 버튼(메인 메뉴로). ending_gallery_screen.dart 뒤로가기 버튼이랑 완전히
          // 같은 식(54*u, 위치 10*u)을 써서, 같은 기기에서 두 화면 버튼이 항상 같은 크기로
          // 보이게 함. u는 가로세로 중 작은 쪽 기준이라 항상 정사각형 유지됨 - 예전엔
          // rW(54)/rH(54)로 가로세로를 따로 계산해서 아이패드에서 버튼이 세로로 길쭉하게
          // 찌그러졌었음
          Positioned(
            left: u(10),
            top: u(10),
            child: GestureDetector(
              onTap: () => _goBackToMainMenu(context),
              child: Image.asset(
                'assets/images/main_back_btn.png',
                width: u(54),
                height: u(54),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 챕터 카드 위젯
  Widget _buildChapterCard(
    String title,
    String subTitle,
    String imgName,
    bool isUnlocked,
    // 카드/글자/간격 전부 이 하나(세로 기준 sh)로 계산함 - 예전엔 rW/rH를 섞어 써서
    // 카드 크기가 화면 "폭"에만 비례했는데, 그러면 아이패드처럼 세로가 유독 긴 화면에서
    // 카드가 화면 높이 대비 작아 보이는 문제가 있었음(화면 꽉 안 차 보임)
    double Function(double) sh,
    // 가로 폭 상한(cardWidthCap) 계산용. 화면 "세로"는 sh로 다 처리되는데 "한 번에 몇 장
    // 보이는지"는 화면 가로 폭이 기준이라 여기서 따로 받아야 함
    double w,
    // 재플레이 잠금 판단용 챕터 번호(1~5). 프롤로그는 이 잠금 대상이 아니라 null로 넘어옴
    int? chapterNumber,
    int highestUnlocked,
  ) {
    // 리스트 패딩/카드 간격(둘 다 sh 기준, build()의 Positioned/padding이랑 같은 값을 그대로
    // 씀). 가로 폭(w)에서 양쪽 패딩을 뺀 공간 안에 "카드+간격"이 kChapterVisibleCardCount번
    // 들어가게 카드 한 변의 상한(cardWidthCap)을 역산함 - 아이패드처럼 세로가 길어서
    // sh(220)이 커져도, 가로 폭이 좁으면 이 상한이 먼저 걸려서 카드가 더 안 커짐
    const double listPaddingRef = 80;
    const double cardGapRef = 40;
    final double cardWidthCap =
        (w - sh(listPaddingRef) * 2) / kChapterVisibleCardCount -
        sh(cardGapRef);

    return Padding(
      padding: EdgeInsets.only(right: sh(cardGapRef)),
      // 카드 한 변(thumbnailSize)이 "세로 기준 크기(sh(220))"보다 커지면 카드 세로 공간(제목+
      // 부제목+여백 다음에 남는 자리)을 넘어서 BOTTOM OVERFLOWED가 날 수 있음. LayoutBuilder로
      // 가로 스크롤 리스트가 이 카드한테 실제로 준 세로 공간을 직접 읽어서(sh로 따로
      // 추정하지 않음 - Positioned(top/bottom) 값이 나중에 바뀌어도 이 계산은 안 틀어짐),
      // 정사각형 한 변을 "세로 기준 크기(sh(220))"랑 "그 세로 공간에서 제목/부제목/여백을
      // 뺀 나머지" 중 더 작은 값으로 정함(실무상 둘 다 세로 기준이라 거의 항상 sh(220)이 더
      // 작아서 이쪽이 상한선 역할을 하고, max 쪽은 정말 세로 공간이 모자랄 때만 걸리는 안전장치)
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 제목(sh(20) SCDream Heavy)/부제목(sh(16) SCDream Medium)의 실제 렌더 줄 높이는
          // 폰트마다 달라서 정확히 재는 대신 넉넉하게(폰트 크기의 1.3배) 잡음 - 실제보다 더
          // 확보해두는 셈이라 썸네일이 아주 살짝 작아질 수는 있어도 오버플로우가 나는
          // 쪽으로는 절대 안 틀어짐. 기존 SizedBox(sh(15)) 여백 + 여유 마진(sh(10))도 같이 뺌
          final double reservedHeight =
              sh(20) * 1.3 + sh(16) * 1.3 + sh(15) + sh(10);
          final double thumbnailSize = math.min(
            math.min(
              sh(220),
              math.max(0.0, constraints.maxHeight - reservedHeight),
            ),
            cardWidthCap,
          );

          // 카드가 cardWidthCap 때문에 sh(220)보다 작아지면, 글자 크기/여백도 같은 비율로
          // 줄여야 폰에서 보던 "카드 대비 글자 크기" 느낌이 그대로 유지됨. sh(220) 기준
          // 원래 크기 대비 지금 카드가 몇 배인지를 cardScale로 구해서 폰트/여백에 곱해줌 -
          // 폰처럼 cardWidthCap이 안 걸리는 경우엔 thumbnailSize가 그대로 sh(220)이라
          // cardScale이 1이 돼서 기존이랑 완전히 동일함
          final double uncappedThumbnailSize = sh(220);
          final double cardScale = uncappedThumbnailSize > 0
              ? (thumbnailSize / uncappedThumbnailSize).clamp(0.0, 1.0)
              : 1.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // 카드가 작아지면 리스트 영역 세로 공간이 남는데, 기본 정렬(start)로는 그 여백이
            // 전부 아래쪽에만 쌓여서 카드 블록이 위로 붙어보임 - center로 바꿔서 남는 여백을
            // 위아래로 나눠 가지게 함
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 제목/부제목을 썸네일 폭(thumbnailSize) 기준으로 가운데 정렬하려고
              // SizedBox로 폭을 썸네일이랑 맞추고 textAlign.center를 줌
              SizedBox(
                width: thumbnailSize,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sh(20) * cardScale,
                    // SCDream8.otf가 weight 800(Heavy) - pubspec.yaml에 등록된 숫자
                    // 굵기 매핑 그대로(다른 화면들이 SCDream5=w500 쓰는 것과 동일한 방식)
                    fontWeight: FontWeight.w800,
                    fontFamily: 'SCDream',
                  ),
                ),
              ),
              SizedBox(
                width: thumbnailSize,
                child: Text(
                  subTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: sh(16) * cardScale,
                    // SCDream5.otf가 weight 500(Medium)
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SCDream',
                  ),
                ),
              ),
              SizedBox(height: sh(15) * cardScale),
              GestureDetector(
                onTap: () async {
                  if (isUnlocked) {
                    // 이미 지나간 챕터(번호가 highestUnlocked보다 작음)거나, 마지막으로 도달한
                    // 챕터인데 엔딩까지 이미 봤으면 재진입 막음 - 재플레이로 온도/선택 변수
                    // 조작하는 걸 막으려는 거임. 프롤로그는 chapterNumber가 null이라 대상 아님
                    if (chapterNumber != null &&
                        (chapterNumber < highestUnlocked ||
                            (chapterNumber == highestUnlocked &&
                                ChapterProgress.hasSeenEnding))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('이미 완료한 챕터예요. 다시 플레이하려면 처음부터 시작해주세요.'),
                        ),
                      );
                      return;
                    }
                    if (title == "Prolog") {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GamePlayScreen(isPrologue: true),
                        ),
                      );

                      // 프롤로그 화면이 pop으로 돌아온 시점 - 새로 push해 들어온 게 아니라
                      // 이 화면(같은 인스턴스) 그대로 돌아온 거라 initState가 다시 안 불려서,
                      // pro_theme에서 안 돌아오고 계속 흐르던 문제가 있었음. 여기서 직접
                      // main_theme을 다시 요청해주면 됨 - 이미 main_theme이면 AudioService가
                      // 알아서 무시함
                      AudioService.playBgm(AudioIds.mainTheme);

                      if (result == true) {
                        // 다른 챕터들이랑 동일하게 ChapterProgress(static)에 저장해야 챕터 선택창이
                        // 다시 생성돼도(다른 챕터 클리어 후 돌아올 때 등) 안 풀림. setState는 지금
                        // 이 화면(같은 인스턴스)에서 바로 카드 잠금이 풀린 걸 반영하려고 여전히 필요함
                        setState(() {
                          ChapterProgress.isChapter1Unlocked = true;
                        });
                        print("챕터 1 잠금장치가 해제되었습니다!");
                      }
                    } else if (title == "Chapter 1") {
                      // "현재 진행 중인 챕터"면 처음부터 다시 시작하는 대신 마지막 저장
                      // 지점으로 이어감(세이브 없으면 fallback으로 원래대로 튜토리얼부터)
                      await _enterCurrentChapter(const TutorialScreen());
                    } else if (title == "Chapter 2") {
                      // 챕터2는 빵집/튜토리얼 없이 바로 주방 화면(챕터2 시작 모드)에서 시작
                      await _enterCurrentChapter(
                        const KitchenScreen(
                          mode: KitchenScreenMode.chapter2Start,
                        ),
                      );
                    } else if (title == "Chapter 3") {
                      // 챕터3도 챕터2랑 동일하게 중간 화면 없이 바로 시작. DEV 바로가기 버튼이랑
                      // 동일한 진입점(채온이 방 화면)으로 연결함
                      await _enterCurrentChapter(const ChaeonRoomScreen());
                    } else if (title == "Chapter 4") {
                      // 챕터4도 챕터3이랑 동일하게 채온이 방 화면부터 시작. mode만 chapter4로 넘겨줌
                      await _enterCurrentChapter(
                        const ChaeonRoomScreen(mode: ChaeonRoomMode.chapter4),
                      );
                    } else if (title == "Chapter 5") {
                      // 챕터5는 골목길/방 없이 빵집(GamePlayScreen)에서 바로 시작. DEV: 챕터5
                      // 바로가기 버튼이랑 동일한 진입점 + 파라미터로 연결함
                      await _enterCurrentChapter(
                        const GamePlayScreen(
                          skipChapter1Events: true,
                          reentryChapter: ReentryChapter.chapter5,
                        ),
                      );
                    }
                  } else {
                    _showLockedChapterNotice();
                  }
                },
                child: Container(
                  // 위 LayoutBuilder에서 구한 thumbnailSize를 가로/세로에 똑같이 써서 항상
                  // 정사각형으로 유지함(가로 기준 rW(220)이랑 세로 여유 공간 중 더 작은 값)
                  width: thumbnailSize,
                  height: thumbnailSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    image: DecorationImage(
                      image: AssetImage('assets/images/$imgName'),
                      fit: BoxFit.cover,
                      // 잠겨있으면 흑백, 풀렸으면 컬러 처리
                      colorFilter: isUnlocked
                          ? null
                          : const ColorFilter.matrix([
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
