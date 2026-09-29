// lib/core/services/save_manager.dart
//
// 저장/불러오기 데이터 계층. StoryState/ChapterProgress의 현재 값을 SaveData 하나로
// 묶어서 shared_preferences에 JSON 문자열 하나로 저장/복원함.
//
// 이번 단계는 그릇(모델 + 읽기/쓰기)만 만드는 거라, 이 클래스를 실제로 부르는 곳(저장 버튼,
// 화면 진입 시 복원 로직)은 아직 없음 - 나중 단계에서 연결함

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/save_checkpoints.dart';
import 'package:emotional_bakery/core/services/story_state.dart';

// 저장 데이터 한 벌을 담는 모델. 필드 하나하나가 SharedPreferences 키가 되는 게 아니라,
// 이 클래스 전체를 toJson()으로 한 번에 직렬화해서 문자열 하나로 저장함(SaveManager 참고)
class SaveData {
  const SaveData({
    required this.checkpoint,
    required this.temperature,
    required this.vars,
    required this.isChapter1Unlocked,
    required this.isChapter2Unlocked,
    required this.isChapter3Unlocked,
    required this.isChapter4Unlocked,
    required this.isChapter5Unlocked,
    required this.hasSeenEnding,
    this.choicesSinceCheckpoint = const [],
  });

  // save_checkpoints.dart의 SaveCheckpoint를 문자열로 저장한 값(SaveCheckpoint.name)
  final String checkpoint;
  final int temperature;
  // StoryState.vars 그대로. Map이라 SharedPreferences에 직접 못 넣어서, SaveData
  // 전체를 jsonEncode할 때 이 필드도 같이 문자열 안에 중첩된 객체로 들어감
  final Map<String, dynamic> vars;
  final bool isChapter1Unlocked;
  final bool isChapter2Unlocked;
  final bool isChapter3Unlocked;
  final bool isChapter4Unlocked;
  final bool isChapter5Unlocked;
  final bool hasSeenEnding;
  // 이 체크포인트에 도달한 뒤부터 저장한 순간까지 고른 선택지 기록. 이어하기 시 이 순서대로
  // 자동 재생해서, 체크포인트~저장 시점 사이 선택지를 유저가 다시 고르지 못하게 막는 데 씀
  // (scene_dialogue_controller.dart의 choiceHistory 참고)
  final List<RecordedChoice> choicesSinceCheckpoint;

  Map<String, dynamic> toJson() => {
    'checkpoint': checkpoint,
    'temperature': temperature,
    'vars': vars,
    'isChapter1Unlocked': isChapter1Unlocked,
    'isChapter2Unlocked': isChapter2Unlocked,
    'isChapter3Unlocked': isChapter3Unlocked,
    'isChapter4Unlocked': isChapter4Unlocked,
    'isChapter5Unlocked': isChapter5Unlocked,
    'hasSeenEnding': hasSeenEnding,
    'choicesSinceCheckpoint': choicesSinceCheckpoint
        .map((c) => c.toJson())
        .toList(),
  };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
    checkpoint: json['checkpoint'] as String,
    temperature: json['temperature'] as int,
    vars: Map<String, dynamic>.from(json['vars'] as Map),
    isChapter1Unlocked: json['isChapter1Unlocked'] as bool,
    isChapter2Unlocked: json['isChapter2Unlocked'] as bool,
    isChapter3Unlocked: json['isChapter3Unlocked'] as bool,
    isChapter4Unlocked: json['isChapter4Unlocked'] as bool,
    isChapter5Unlocked: json['isChapter5Unlocked'] as bool,
    hasSeenEnding: json['hasSeenEnding'] as bool,
    // 이 필드 추가 전에 저장된 옛날 세이브엔 키 자체가 없을 수 있어서 없으면 빈 리스트로 처리
    choicesSinceCheckpoint:
        (json['choicesSinceCheckpoint'] as List<dynamic>?)
            ?.map((e) => RecordedChoice.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class SaveManager {
  // shared_preferences 안에서 저장 데이터를 찾는 키. 나중에 저장 포맷이 바뀌면 버전만 올려서
  // 예전 세이브랑 안 섞이게 하려고 버전을 키 이름에 박아둠
  static const String _saveKey = 'save_data_v1';

  // 지금 StoryState/ChapterProgress 값을 그대로 긁어서 SaveData로 묶고, 통째로
  // jsonEncode해서 하나의 문자열로 저장함. checkpoint만 호출부에서 넘겨받음 - 어느
  // 체크포인트에서 저장하는 건지는 저장을 부르는 화면이 제일 잘 알고 있어서.
  // choicesSinceCheckpoint도 마찬가지로 호출부(SceneDialogueController.choiceHistory)가
  // 제일 잘 알고 있어서 넘겨받음 - 없는 화면(프롤로그 등)은 기본값(빈 리스트) 그대로 둠
  static Future<void> save(
    SaveCheckpoint checkpoint, {
    List<RecordedChoice> choicesSinceCheckpoint = const [],
  }) async {
    final SaveData data = SaveData(
      checkpoint: checkpoint.name,
      temperature: StoryState.currentTemperature,
      vars: StoryState.vars,
      isChapter1Unlocked: ChapterProgress.isChapter1Unlocked,
      isChapter2Unlocked: ChapterProgress.isChapter2Unlocked,
      isChapter3Unlocked: ChapterProgress.isChapter3Unlocked,
      isChapter4Unlocked: ChapterProgress.isChapter4Unlocked,
      isChapter5Unlocked: ChapterProgress.isChapter5Unlocked,
      hasSeenEnding: ChapterProgress.hasSeenEnding,
      choicesSinceCheckpoint: choicesSinceCheckpoint,
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(data.toJson()));
  }

  // 저장된 값을 읽어서 SaveData로 복원. 저장된 게 없으면 null
  static Future<SaveData?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return SaveData.fromJson(json);
  }

  // 저장된 데이터가 있는지만 확인. "이어하기" 버튼을 활성화할지 판단할 때 씀
  static Future<bool> hasSave() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }
}
