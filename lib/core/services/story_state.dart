// lib/core/services/story_state.dart
//
// 선택지 고를 때 저장되는 재료 변수들을 앱 전역에서 들고 있는 저장소.
// chapter_progress.dart랑 같은 패턴으로 static 클래스로 구현해서, 화면이 새로
// 생성돼도 값이 리셋 안 되고 앱이 켜져있는 동안 계속 유지됨

class StoryState {
  static Map<String, dynamic> vars = {};

  // 감정 온도 전역 저장소. 예전엔 SceneDialogueController(initialTemperature)를 위젯
  // 생성자로만 넘겨받았는데, 챕터 종료 -> ChapterSelectScreen -> 다음 챕터 진입 흐름을
  // 거칠 때마다 값이 안 넘어가고 항상 기본값(3)으로 리셋되던 문제가 있었음. vars랑 같은
  // 패턴으로 전역 static에 두고, scene_dialogue_controller.dart에서 temperature가 바뀔
  // 때마다 여기에 동기화해서 화면이 몇 번을 갈아끼워져도 값이 안 끊기게 함
  static int currentTemperature = 3;

  // 공용 메뉴 오버레이의 AUTO 토글 상태. currentTemperature랑 같은 패턴으로 전역에 둬서,
  // 화면이 바뀌어도(챕터 경계 넘어갈 때 등) 값이 안 풀리게 함
  static bool isAutoAdvanceEnabled = false;

  // chapter2_ingredient_quiz.json의 q1(eat/sleep/play) + q2(game/movie/exercise) +
  // q3(red/yellow/blue) 답변 조합으로 정해지는 마법 재료 이름.
  // line_ingredient_reveal의 {{ingredient}} 자리에 들어감
  static const Map<String, String> _ingredientByAnswer = {
    'eat_game_red': '붉은 태양의 결정',
    'eat_game_yellow': '노란 태양의 결정',
    'eat_game_blue': '푸른 태양의 결정',
    'eat_movie_red': '붉은 태양의 눈물',
    'eat_movie_yellow': '노란 태양의 눈물',
    'eat_movie_blue': '푸른 태양의 눈물',
    'eat_exercise_red': '붉은 태양의 가루',
    'eat_exercise_yellow': '노란 태양의 가루',
    'eat_exercise_blue': '푸른 태양의 가루',

    'sleep_game_red': '붉은 별의 결정',
    'sleep_game_yellow': '노란 별의 결정',
    'sleep_game_blue': '푸른 별의 결정',
    'sleep_movie_red': '붉은 별의 눈물',
    'sleep_movie_yellow': '노란 별의 눈물',
    'sleep_movie_blue': '푸른 별의 눈물',
    'sleep_exercise_red': '붉은 별의 가루',
    'sleep_exercise_yellow': '노란 별의 가루',
    'sleep_exercise_blue': '푸른 별의 가루',

    'play_game_red': '붉은 고래의 결정',
    'play_game_yellow': '노란 고래의 결정',
    'play_game_blue': '푸른 고래의 결정',
    'play_movie_red': '붉은 고래의 눈물',
    'play_movie_yellow': '노란 고래의 눈물',
    'play_movie_blue': '푸른 고래의 눈물',
    'play_exercise_red': '붉은 고래의 가루',
    'play_exercise_yellow': '노란 고래의 가루',
    'play_exercise_blue': '푸른 고래의 가루',
  };

  // q1/q2/q3 답변이 다 모였으면 그 조합에 해당하는 재료 이름을 반환, 아니면 null
  static String? resolveIngredientName() {
    final q1 = vars['q1'];
    final q2 = vars['q2'];
    final q3 = vars['q3'];
    if (q1 == null || q2 == null || q3 == null) return null;
    return _ingredientByAnswer['${q1}_${q2}_$q3'];
  }

  // 재료 이름과 같은 q1/q2/q3 조합으로 정해지는 재료 이미지 경로.
  // 재료 획득 팝업에서 보여줄 이미지를 찾을 때 씀
  static const Map<String, String> _ingredientImageByAnswer = {
    'eat_game_red': 'assets/images/ingredient_red_crystal.png',
    'eat_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'eat_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'eat_movie_red': 'assets/images/ingredient_red_tear.png',
    'eat_movie_yellow': 'assets/images/ingredient_yellow_tear.png',
    'eat_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'eat_exercise_red': 'assets/images/ingredient_red_powder.png',
    'eat_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'eat_exercise_blue': 'assets/images/ingredient_blue_powder.png',

    'sleep_game_red': 'assets/images/ingredient_red_crystal.png',
    'sleep_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'sleep_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'sleep_movie_red': 'assets/images/ingredient_red_tear.png',
    'sleep_movie_yellow': 'assets/images/ingredient_yellow_tear.png',
    'sleep_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'sleep_exercise_red': 'assets/images/ingredient_red_powder.png',
    'sleep_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'sleep_exercise_blue': 'assets/images/ingredient_blue_powder.png',

    'play_game_red': 'assets/images/ingredient_red_crystal.png',
    'play_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'play_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'play_movie_red': 'assets/images/ingredient_red_tear.png',
    'play_movie_yellow': 'assets/images/ingredient_yellow_tear.png',
    'play_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'play_exercise_red': 'assets/images/ingredient_red_powder.png',
    'play_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'play_exercise_blue': 'assets/images/ingredient_blue_powder.png',
  };

  // 챕터2 재료 퀴즈를 안 거치고(q1/q2/q3가 안 채워진 채) 챕터3에 바로 들어온 경우처럼
  // vars가 비어있을 때 쓰는 임시 안전장치. 챕터5까지 다 끝나면 제대로 된 저장 시스템으로
  // 교체 예정. eat_game_red 조합(27가지 중 첫 번째로 정의된 조합)을 그대로 대표값으로 씀
  static const String _fallbackIngredientImage =
      'assets/images/ingredient_red_crystal.png';
  static const String _fallbackCompletedDoughImage =
      'assets/images/dough_crystal_red.png';

  // q1/q2/q3 답변이 다 모였으면 그 조합에 해당하는 재료 이미지 경로를 반환, 아니면 null
  static String? resolveIngredientImage() {
    final q1 = vars['q1'];
    final q2 = vars['q2'];
    final q3 = vars['q3'];
    // q1/q2/q3가 하나라도 비었거나, 조합 자체가 매핑에 없는 경우(있을 수 없지만 방어적으로)
    // 둘 다 fallback으로 감. 정상적으로 퀴즈를 거친 경우엔 이 분기 자체를 안 탐
    if (q1 == null || q2 == null || q3 == null) {
      return _fallbackIngredientImage;
    }
    return _ingredientImageByAnswer['${q1}_${q2}_$q3'] ??
        _fallbackIngredientImage;
  }

  // 재료 이미지 경로 -> 그 재료를 넣어 완성한 반죽 이미지 경로.
  // 빵만들기 미니게임에서 재료를 다 넣으면 배경을 이 이미지로 바꿀 때 씀
  static const Map<String, String> _doughImageByIngredientImage = {
    'assets/images/ingredient_blue_crystal.png':
        'assets/images/dough_crystal_blue.png',
    'assets/images/ingredient_blue_powder.png':
        'assets/images/dough_powder_blue.png',
    'assets/images/ingredient_blue_tear.png':
        'assets/images/dough_tear_blue.png',
    'assets/images/ingredient_red_crystal.png':
        'assets/images/dough_crystal_red.png',
    'assets/images/ingredient_red_powder.png':
        'assets/images/dough_powder_red.png',
    'assets/images/ingredient_red_tear.png':
        'assets/images/dough_tear_red.png',
    'assets/images/ingredient_yellow_tear.png':
        'assets/images/dough_tear_yellow.png',
    'assets/images/ingredient_yellow_crystal.png':
        'assets/images/dough_crystal_yellow.png',
    'assets/images/ingredient_yellow_powder.png':
        'assets/images/dough_powder_yellow.png',
  };

  // q1/q2/q3 답변이 다 모였으면 그 재료로 완성한 반죽 이미지 경로를 반환, 아니면 null
  static String? resolveCompletedDoughImage() {
    final ingredientImage = resolveIngredientImage();
    // resolveIngredientImage()가 이미 fallback을 갖고 있어서 사실 null이 될 일은 없지만,
    // 혹시 모를 매핑 누락에도 대비해서 여기도 fallback을 한 번 더 걸어둠
    if (ingredientImage == null) return _fallbackCompletedDoughImage;
    return _doughImageByIngredientImage[ingredientImage] ??
        _fallbackCompletedDoughImage;
  }

  // 챕터5까지 오면 감정 온도는 항상 8~10으로 확인돼서, 챕터5 엔딩 분기는 온도가 아니라
  // chapter2_ready.json의 choice_001(빵을 좋아하는지) 답변(likesBread)만으로 결정됨
  static Chapter5EndingType resolveChapter5EndingType() {
    // "좋아하진 않아요"(likesBread=no)를 고른 경우만 해피엔딩. 그 외(좋아하긴 하는데...=
    // 히든엔딩, 또는 챕터5로 바로 진입해서 값 자체가 없는 경우)는 전부 hidden으로 묶어서
    // 처리함 - 히든엔딩은 아직 안 만들어서 호출부에서 hidden이면 기존 임시 종료 화면으로 감
    return vars['likesBread'] == 'no'
        ? Chapter5EndingType.happy
        : Chapter5EndingType.hidden;
  }
}

// 챕터5 엔딩 종류. resolveChapter5EndingType() 참고
enum Chapter5EndingType { happy, hidden }
