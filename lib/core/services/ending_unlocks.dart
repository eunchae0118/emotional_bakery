// lib/core/services/ending_unlocks.dart
//
// "엔딩보기" 갤러리용 엔딩 해금 상태. ChapterProgress.hasSeenEnding(챕터 재진입 막는 용도로 쓰는
// "엔딩 하나라도 봤는지" 전역 플래그 - "시작하기"로 새 게임 시작할 때 resetAllProgress()가
// 초기화함)이랑은 완전히 별개임. 여긴 기존 세이브 슬롯(save_data_v1)이랑 다른 키
// (ending_unlocks_v1)로 shared_preferences에 독립 저장해서, 새 게임을 몇 번을 다시 시작해도
// 한 번 해금한 엔딩은 계속 해금된 채로 쌓이게 함

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum EndingType { happy, normal, bad, hidden }

class EndingUnlocks {
  static const String _key = 'ending_unlocks_v1';

  static bool hasUnlockedHappy = false;
  static bool hasUnlockedNormal = false;
  static bool hasUnlockedBad = false;
  static bool hasUnlockedHidden = false;

  // load()를 이미 한 번 했는지. 여러 화면이 각자 load()를 불러도 두 번째부턴 그냥 무시해서,
  // unlock()으로 이미 메모리에 반영된 최신 값을 옛날 저장값으로 덮어쓰는 걸 막음
  static bool _isLoaded = false;

  // 앱 시작 시(main.dart) 한 번 불러서 위 static 값들을 채워둠. 다른 화면("엔딩보기" 등)에서
  // "이 엔딩 해금됐나?" 확인하기 전에도 안전하게 다시 호출 가능 - 이미 로드했으면 바로 리턴함
  static Future<void> load() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    hasUnlockedHappy = json['hasUnlockedHappy'] as bool? ?? false;
    hasUnlockedNormal = json['hasUnlockedNormal'] as bool? ?? false;
    hasUnlockedBad = json['hasUnlockedBad'] as bool? ?? false;
    hasUnlockedHidden = json['hasUnlockedHidden'] as bool? ?? false;
  }

  // 해당 엔딩에 실제로 도달한 시점(각 엔딩 컷씬의 onComplete)에서 호출. 이미 해금돼 있으면
  // 조용히 무시해서 불필요한 저장을 피함
  static Future<void> unlock(EndingType type) async {
    switch (type) {
      case EndingType.happy:
        if (hasUnlockedHappy) return;
        hasUnlockedHappy = true;
        break;
      case EndingType.normal:
        if (hasUnlockedNormal) return;
        hasUnlockedNormal = true;
        break;
      case EndingType.bad:
        if (hasUnlockedBad) return;
        hasUnlockedBad = true;
        break;
      case EndingType.hidden:
        if (hasUnlockedHidden) return;
        hasUnlockedHidden = true;
        break;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson()));
  }

  // 특정 엔딩이 해금됐는지. load()를 먼저 호출해둔 상태여야 정확한 값을 보장함
  static bool isUnlocked(EndingType type) {
    switch (type) {
      case EndingType.happy:
        return hasUnlockedHappy;
      case EndingType.normal:
        return hasUnlockedNormal;
      case EndingType.bad:
        return hasUnlockedBad;
      case EndingType.hidden:
        return hasUnlockedHidden;
    }
  }

  static Map<String, dynamic> _toJson() => {
    'hasUnlockedHappy': hasUnlockedHappy,
    'hasUnlockedNormal': hasUnlockedNormal,
    'hasUnlockedBad': hasUnlockedBad,
    'hasUnlockedHidden': hasUnlockedHidden,
  };
}
