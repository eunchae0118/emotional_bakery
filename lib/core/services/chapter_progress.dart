// lib/core/services/chapter_progress.dart
//
// 챕터 해금 상태를 앱 전역에서 들고 있는 저장소. chapter_select_screen.dart의
// _isChapter1Unlocked처럼 화면 State에 두면 화면이 새로 생성될 때마다 리셋되는데,
// 여기는 static이라 앱이 켜져있는 동안은 값이 계속 유지됨

import 'package:emotional_bakery/core/services/story_state.dart';

class ChapterProgress {
  // 프롤로그 클리어하면 켜짐. chapter_select_screen.dart가 예전엔 이걸 로컬 State
  // 변수(_isChapter1Unlocked)로 들고 있어서 챕터 선택창이 다시 만들어질 때마다(다른 챕터
  // 클리어 후 돌아올 때 등) false로 리셋되는 버그가 있었음 - 다른 챕터들처럼 여기 static으로
  // 옮겨서 고침
  static bool isChapter1Unlocked = false;
  static bool isChapter2Unlocked = false;
  // 챕터2 완전 종료(chapter2_after_second_game.json까지 다 봄)하면 켜짐
  static bool isChapter3Unlocked = false;
  // 챕터3 완전 종료(일기장 퍼즐 시퀀스 끝, chapter3_after_eat.json까지 다 봄)하면 켜짐
  static bool isChapter4Unlocked = false;
  // 챕터4 온도 8~10(챕터5행) 엔딩 컷씬(chapter4_back_to_bakery_data)이 끝나면 켜짐
  static bool isChapter5Unlocked = false;

  // 엔딩(배드/노말/해피/히든) 중 아무거나 하나라도 봤으면 켜짐. 4개 엔딩 지점
  // (chaeon_room_screen.dart의 챕터4 배드/노말엔딩, kitchen_screen.dart의 챕터5 해피/히든엔딩
  // 컷씬 onComplete)에서 true로 세팅함. 켜지면 챕터 선택창에서 재진입이 막히고 "시작하기"로만
  // 다시 시작 가능함(재플레이로 온도/선택 변수 조작 못 하게 막는 용도)
  static bool hasSeenEnding = false;

  // "시작하기"로 처음부터 다시 시작할 때 부르는 전체 초기화. 해금 상태/엔딩 플래그 다 끄고
  // 온도/선택 변수도 기본값으로 되돌림. isAutoAdvanceEnabled는 진행 상황이 아니라 UI
  // 설정값이라 여기서 안 건드림
  static void resetAllProgress() {
    isChapter1Unlocked = false;
    isChapter2Unlocked = false;
    isChapter3Unlocked = false;
    isChapter4Unlocked = false;
    isChapter5Unlocked = false;
    hasSeenEnding = false;
    StoryState.currentTemperature = 3;
    StoryState.vars = {};
  }
}
