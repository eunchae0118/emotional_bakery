// lib/core/widgets/dialogue_overlay.dart

import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // data가 없으면(프롤로그 경로) 기존 _prologueData 그대로 씀
    final List<Map<String, String>> activeData = widget.data ?? _prologueData;
    final currentData = activeData[_currentIndex];

    return GestureDetector(
      onTap: () {
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
            Positioned.fill(
              child: Image.asset(
                'assets/images/${currentData["image"]}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
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
