// lib/features/menu/chapter_select_screen.dart

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart'
    show ReentryChapter;
import 'package:emotional_bakery/features/chapter1/game_play_screen.dart';
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';
import 'package:emotional_bakery/features/chapter3/chaeon_room_screen.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';

class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  // 스크롤 위치 감지용 컨트롤러
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // BakeryGame(Flame)이 쓰는 배경/채온이 스프라이트를 미리 데워둠. Flame.images는 앱
    // 전역에서 공유되는 static 캐시라, 여기서 한 번만 로드해두면 이후 챕터1/3/4/5 중
    // 어느 경로로 GamePlayScreen에 처음 들어가든 로딩 중 검은 화면이 안 보임
    Flame.images.load('bakery_bg_main.png');
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

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

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
            top: rH(40),
            bottom: rH(60),
            left: 0,
            right: 0,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // 끝에서 튕기는 스크롤 효과
              padding: EdgeInsets.symmetric(horizontal: rW(80)), // 양옆 여백
              children: [
                _buildChapterCard(
                  "Prolog",
                  "감정을 잃은 사람들",
                  "ch_prolog.png",
                  true,
                  rW,
                  rH,
                  // 프롤로그는 재플레이 잠금 대상(챕터 1~5) 밖이라 번호 없음
                  null,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 1",
                  "색을 잃은 아이",
                  "ch1.png",
                  ChapterProgress.isChapter1Unlocked, // 프롤로그 클리어하면 전역으로 해금됨
                  rW,
                  rH,
                  1,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 2",
                  "닫아버린 마음",
                  "ch2.png",
                  ChapterProgress.isChapter2Unlocked, // 챕터1 종료하면 전역으로 해금됨
                  rW,
                  rH,
                  2,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 3",
                  "멈춰선 마을",
                  "ch3.png",
                  ChapterProgress.isChapter3Unlocked, // 챕터2 종료하면 전역으로 해금됨
                  rW,
                  rH,
                  3,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 4",
                  "준비 중인 이야기",
                  "ch4.png",
                  ChapterProgress.isChapter4Unlocked, // 챕터3 종료하면 전역으로 해금됨
                  rW,
                  rH,
                  4,
                  highestUnlocked,
                ),
                _buildChapterCard(
                  "Chapter 5",
                  "준비 중인 이야기",
                  "ch5.png",
                  ChapterProgress.isChapter5Unlocked, // 챕터4 챕터5행 엔딩 보면 전역으로 해금됨
                  rW,
                  rH,
                  5,
                  highestUnlocked,
                ),
              ],
            ),
          ),

          // 개발용 임시 버튼 모음. 챕터1~5 화면을 매번 순서대로 안 거치고 바로 테스트하려고
          // 세로로 쌓아둔 지름길 버튼들. 전부 임시 개발용 코드라 나중에 통째로 지울 것
          Positioned(
            right: rW(10),
            bottom: rH(10),
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
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
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
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
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
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
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
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
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
                      fontSize: rW(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 스크롤 진행 바
          Positioned(
            bottom: rH(30),
            left: rW(100),
            right: rW(100),
            child: Stack(
              children: [
                // 바닥 배경 줄
                Container(
                  height: rH(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 현재 위치 표시 줄 (움직이는 바)
                FractionallySizedBox(
                  widthFactor: 0.3,
                  child: Transform.translate(
                    offset: Offset((rW(874 - 200) * 0.7) * _scrollProgress, 0),
                    child: Container(
                      height: rH(6),
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
    Function rW,
    Function rH,
    // 재플레이 잠금 판단용 챕터 번호(1~5). 프롤로그는 이 잠금 대상이 아니라 null로 넘어옴
    int? chapterNumber,
    int highestUnlocked,
  ) {
    return Padding(
      padding: EdgeInsets.only(right: rW(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: rW(24),
              fontWeight: FontWeight.bold,
              fontFamily: 'NanumGothic',
            ),
          ),
          Text(
            subTitle,
            style: TextStyle(color: Colors.white70, fontSize: rW(14)),
          ),
          SizedBox(height: rH(15)),
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
                      content: Text(
                        '이미 완료한 챕터예요. 다시 플레이하려면 처음부터 시작해주세요.',
                      ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TutorialScreen(),
                    ),
                  );
                } else if (title == "Chapter 2") {
                  // 챕터2는 빵집/튜토리얼 없이 바로 주방 화면(챕터2 시작 모드)에서 시작
                  Navigator.push(
                    context,
                    fadeThroughBlackRoute(
                      const KitchenScreen(
                        mode: KitchenScreenMode.chapter2Start,
                      ),
                    ),
                  );
                } else if (title == "Chapter 3") {
                  // 챕터3도 챕터2랑 동일하게 중간 화면 없이 바로 시작. DEV 바로가기 버튼이랑
                  // 동일한 진입점(채온이 방 화면)으로 연결함
                  Navigator.push(
                    context,
                    fadeThroughBlackRoute(const ChaeonRoomScreen()),
                  );
                } else if (title == "Chapter 4") {
                  // 챕터4도 챕터3이랑 동일하게 채온이 방 화면부터 시작. mode만 chapter4로 넘겨줌
                  Navigator.push(
                    context,
                    fadeThroughBlackRoute(
                      const ChaeonRoomScreen(mode: ChaeonRoomMode.chapter4),
                    ),
                  );
                } else if (title == "Chapter 5") {
                  // 챕터5는 골목길/방 없이 빵집(GamePlayScreen)에서 바로 시작. DEV: 챕터5
                  // 바로가기 버튼이랑 동일한 진입점 + 파라미터로 연결함
                  Navigator.push(
                    context,
                    fadeThroughBlackRoute(
                      const GamePlayScreen(
                        skipChapter1Events: true,
                        reentryChapter: ReentryChapter.chapter5,
                      ),
                    ),
                  );
                }
              } else {
                print("잠겨있음!");
              }
            },
            child: Container(
              width: rW(220),
              height: rH(220),
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
      ),
    );
  }
}
