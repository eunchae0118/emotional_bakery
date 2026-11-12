// lib/features/chapter5/chapter5_ending_happy_data.dart

// 챕터5 해피엔딩(chapter2_ready.json의 choice_001에서 "좋아하진 않아요"를 골랐을 때) 컷씬
// 대사+이미지 목록. dialogue_overlay.dart의 DialogueOverlay가 data 파라미터로 이걸 받아서
// 프롤로그(_prologueData)랑 동일한 방식으로 재생함.
// 이미지 파일명은 기획상 "ending_happy_*"가 맞지만, 실제 에셋 파일이 "endig_happy_*"로
// 오타난 채 존재해서(assets/images/ 확인함) 그 철자에 맞춰 씀
const List<Map<String, String>> chapter5EndingHappyData = [
  {"text": "채온은 천천히 감정을 되찾아갔어요.", "image": "endig_happy_1.png"},
  {
    "text": "슬픔이 올라올 때도 있었고, 감당하기 힘든 날도 있었지만 채온은 도망치지 않았어요.",
    "image": "endig_happy_2.png",
  },
  {
    "text": "슬픔을 겪는 법을, 그리고 그것을 받아드리는 법을 조금씩 배워나갔어요.",
    "image": "endig_happy_3.png",
  },
  {"text": "점차 채온의 세상은 색을 되찾아갔어요.", "image": "endig_happy_4.png"},
  {"text": "그러던 어느 날 밤, 꿈에서 엄마를 다시 만나게 되었어요.", "image": "endig_happy_5.png"},
  {"text": "채온은 엄마를 향해 걸어갔어요. 그리고 환하게 웃어 보였어요.", "image": "endig_happy_6.png"},
  {"text": "눈물이 흘렀지만, 슬픈 눈물이 아니었어요.", "image": "endig_happy_7.png"},
  {"text": "채온은 비로소 모든 감정을 되찾게 되었어요.", "image": "endig_happy_7.png"},
];
