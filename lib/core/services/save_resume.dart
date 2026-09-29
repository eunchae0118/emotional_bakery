// lib/core/services/save_resume.dart
//
// choice_screen.dart의 "이어하기"랑 chapter_select_screen.dart의 "진행 중인 챕터
// 재진입"이 공유하는 저장 지점 복귀 로직. 체크포인트 하나당 어느 화면으로 어떻게
// 이어야 하는지가 완전히 똑같아서, 예전엔 choice_screen.dart 안에 private으로만
// 있었던 걸 여기로 빼서 두 화면이 같이 씀 - 하나만 고치고 다른 쪽을 깜빡하는 실수 방지

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/save_manager.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart'
    show ReentryChapter;
import 'package:emotional_bakery/features/chapter1/game_play_screen.dart';
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';
import 'package:emotional_bakery/features/chapter3/chaeon_room_screen.dart';

// 체크포인트 하나당 이어할 화면을 하나 골라서 그 화면 위젯을 만들어줌. save_checkpoints.dart의
// 30개 값(kitchen_screen.dart 20개 + chaeon_room_screen.dart 5개 + game_play_screen.dart 5개)
// 전부를 다루는 switch라 하나라도 빠지면 컴파일 에러로 바로 알 수 있음(default 없이 둠).
//
// chapter3Door 하나만 좀 특이함 - game_play_screen.dart의 _detectCurrentCheckpoint가
// 챕터3 재진입이랑 챕터4 재진입을 구분 안 하고 똑같이 chapter3Door로 저장하기 때문에,
// 체크포인트 이름만으론 어느 챕터로 가던 중이었는지 알 수가 없음. 대신 저장된 해금
// 상태(data.isChapter4Unlocked)로 유추함 - 챕터4가 이미 해금돼 있으면 챕터3는 이미
// 끝낸 상태라는 뜻이라 챕터4로 재진입하던 중이었을 거고, 아니면 챕터3 재진입 중이었을 것
Widget screenForCheckpoint(SaveCheckpoint checkpoint, SaveData data) {
  switch (checkpoint) {
    // --- kitchen_screen.dart ---
    case SaveCheckpoint.chapter2Ready:
    case SaveCheckpoint.chapter2IngredientQuiz:
    case SaveCheckpoint.chapter2AfterQuiz:
    case SaveCheckpoint.chapter2MakingBread:
    case SaveCheckpoint.chapter2AfterFirstGame:
    case SaveCheckpoint.chapter2AfterSecondGame:
      return KitchenScreen(
        mode: KitchenScreenMode.chapter2Start,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter1KitchenArrival:
      return KitchenScreen(
        mode: KitchenScreenMode.chapter1End,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter3ChaeonRoomAfter:
    case SaveCheckpoint.chapter3BeforeGame:
    case SaveCheckpoint.chapter3AfterFirstGame:
    case SaveCheckpoint.chapter3AfterEat:
      return KitchenScreen(
        mode: KitchenScreenMode.chapter3Start,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter4BeforeCutscene:
    case SaveCheckpoint.chapter4AfterPast:
    case SaveCheckpoint.chapter4MakingBread:
    case SaveCheckpoint.chapter4AfterLetter:
    case SaveCheckpoint.chapter4AfterMaking:
      return KitchenScreen(
        mode: KitchenScreenMode.chapter4Start,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter5Bear:
    case SaveCheckpoint.chapter5Eat:
    case SaveCheckpoint.chapter5AfterEat:
    case SaveCheckpoint.chapter5Hidden:
      return KitchenScreen(
        mode: KitchenScreenMode.chapter5Start,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );

    // --- chaeon_room_screen.dart ---
    case SaveCheckpoint.chapter3ChaeonRoom:
      return ChaeonRoomScreen(
        mode: ChaeonRoomMode.chapter3,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter4StartRoom:
      return ChaeonRoomScreen(
        mode: ChaeonRoomMode.chapter4,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter4RoomChoice:
    case SaveCheckpoint.chapter4TempLow:
    case SaveCheckpoint.chapter4TempHigh:
      return ChaeonRoomScreen(
        mode: ChaeonRoomMode.chapter4,
        enterFromDoor: true,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );

    // --- game_play_screen.dart ---
    case SaveCheckpoint.chapter1Table:
    case SaveCheckpoint.chapter1FirstMeet:
    case SaveCheckpoint.chapter1FirstMeetMid:
    case SaveCheckpoint.chapter1FirstBread:
      return GamePlayScreen(
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter3Door:
      return GamePlayScreen(
        skipChapter1Events: true,
        reentryChapter: data.isChapter4Unlocked
            ? ReentryChapter.chapter4
            : ReentryChapter.chapter3,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
    case SaveCheckpoint.chapter5Start:
      return GamePlayScreen(
        skipChapter1Events: true,
        reentryChapter: ReentryChapter.chapter5,
        initialTemperature: data.temperature,
        resumeCheckpoint: checkpoint,
        resumeChoiceHistory: data.choicesSinceCheckpoint,
      );
  }
}

// SaveData를 StoryState/ChapterProgress에 그대로 복원함. 저장할 때 읽어갔던 값들을
// 그대로 되돌려놓는 것 - choice_screen.dart의 "이어하기"/chapter_select_screen.dart의
// "진행 중인 챕터 재진입"이 공통으로 필요로 함
void restoreStoryStateFromSave(SaveData data) {
  StoryState.currentTemperature = data.temperature;
  StoryState.vars = data.vars;
  ChapterProgress.isChapter1Unlocked = data.isChapter1Unlocked;
  ChapterProgress.isChapter2Unlocked = data.isChapter2Unlocked;
  ChapterProgress.isChapter3Unlocked = data.isChapter3Unlocked;
  ChapterProgress.isChapter4Unlocked = data.isChapter4Unlocked;
  ChapterProgress.isChapter5Unlocked = data.isChapter5Unlocked;
  ChapterProgress.hasSeenEnding = data.hasSeenEnding;
}

// data.checkpoint(문자열)를 SaveCheckpoint enum 값으로 찾아줌. 저장 파일이 깨졌거나
// 옛날 포맷이면 못 찾아서 null - 호출부가 각자 사정에 맞게 처리함(안내 띄우기/그냥
// 조용히 다른 동작으로 대체하기 등)
SaveCheckpoint? resolveSaveCheckpoint(SaveData data) {
  for (final value in SaveCheckpoint.values) {
    if (value.name == data.checkpoint) return value;
  }
  return null;
}
