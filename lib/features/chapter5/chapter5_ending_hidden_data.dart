// lib/features/chapter5/chapter5_ending_hidden_data.dart

// 챕터5 히든엔딩(chapter2_ready.json의 choice_001에서 "좋아하긴 하는데..."를 골랐을 때) 컷씬
// 대사+이미지 목록. chapter5_ending_happy_data.dart랑 동일한 형식으로 DialogueOverlay에
// data 파라미터로 넘겨서 재생함.
// 참고: 여기 이미지 파일명은 기획 철자 그대로 "ending_hidden_*"임. 해피엔딩 쪽
// "endig_happy_*"는 실제 에셋이 오타난 채 존재해서 거기 맞춘 거고, 히든엔딩 에셋은
// assets/images/ 확인해보니 오타 없이 "ending_hidden_*"로 존재함
const List<Map<String, String>> chapter5EndingHiddenData = [
  {
    "text": "릴리와 빵을 만든 채온은 가벼운 인사를 전하고 빵집을 나왔어요.",
    "image": "ending_hidden_1.png",
  },
  {"text": "그날 밤, 꿈에서 엄마를 다시 만나게 되었어요.", "image": "ending_hidden_2.png"},
  {
    "text": "채온은 엄마를 향해 걸어갔어요. 그리고 환하게 웃어 보였어요.",
    "image": "ending_hidden_3.png",
  },
  {"text": "\"엄마를 위해 내가 빵을 구웠어요!\"", "image": "ending_hidden_3.png"},
  {"text": "엄마는 채온을 보며 웃어보였어요.", "image": "ending_hidden_4.png"},
  {
    "text": "채온은 엄마와 함께 빵을 나눠먹으며 릴리와 있었던 일에 대해 이야기했어요.",
    "image": "ending_hidden_4.png",
  },
  {"text": "꿈에서 깬 채온은 비로소 모든 감정을 되찾게 되었어요.", "image": "ending_hidden_5.png"},
  {"text": "그리고 제빵사라는 꿈을 찾아 빵을 굽기 시작했어요.", "image": "ending_hidden_6.png"},
  {"text": "사랑의 빵을.", "image": "ending_hidden_6.png"},
];
