// lib/core/utils/image_warmup.dart
// 큰 배경 이미지를 화면에 처음 그리기 전에 미리 디코딩 + GPU 텍스처 업로드까지 끝내두는 공용 유틸.
// 원래 main_screen.dart의 프롤로그 이미지 프리로딩에만 있던 걸 골목길/빵집/채온이 방
// 배경에도 쓰려고 여기로 옮김

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/widgets.dart';

// dpad 이동 화면들의 큰 배경 이미지. 이 화면들로 넘어가기 전(이전 화면) + 넘어간 직후(암전
// 구간, 대상 화면 자신) 양쪽에서 워밍업을 거는데, 경로 문자열이 어긋나면 캐시 키가 달라져서
// 워밍업이 헛돌기 때문에 한 곳에서 관리함
// 골목길(tutorial_screen.dart) 배경, 4000x1352
const String kTutorialBgAsset = 'assets/images/tutorial_bg_full.png';
// 채온이 방(chaeon_room_screen.dart) 배경, 3496x1824
const String kRoomBgAsset = 'assets/images/room_bg.png';
// 빵집(bakery_game.dart, Flame) 배경, 4000x868. Flame 규칙대로 assets/images/ 기준 상대 경로
const String kBakeryBgFlameImage = 'bakery_bg_main.png';

// precacheImage로 이미 캐시된 이미지를 다시 resolve해서 ui.Image를 얻고, 1x1짜리
// 오프스크린 캔버스에 한 번 그려서 GPU 텍스처 업로드를 강제로 미리 발생시킴.
// createLocalImageConfiguration(context)를 그대로 써서 precacheImage가 썼던 것과
// 같은 캐시 키로 resolve되게 함 - 그래야 새로 디코딩 안 하고 이미 캐시된 이미지를
// 그대로 받아옴. 목적지 캔버스가 1x1이어도 canvas.drawImage가 원본 이미지를 텍스처로
// 샘플링하는 건 똑같아서, 실제 크기로 그리는 것보다 훨씬 싸게 업로드만 미리 끝낼 수 있음
Future<void> warmUpGpuTexture(
  ImageProvider provider,
  BuildContext context,
) async {
  final ImageStream stream = provider.resolve(
    createLocalImageConfiguration(context),
  );
  final Completer<ui.Image> completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      stream.removeListener(listener);
      completer.complete(info.image);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);

  // 여기서 얻은 image는 ImageCache가 들고 있는 거라 dispose하면 안 됨
  await warmUpUiImage(await completer.future);
}

// 이미 디코딩된 ui.Image를 1x1 오프스크린 캔버스에 한 번 그려서 GPU 업로드만 미리 끝냄.
// 넘겨받은 image는 호출한 쪽(ImageCache/Flame.images) 소유라 여기서 dispose 안 하고,
// 새로 그린 Picture/rasterized 쪽만 다 쓰고 정리함
Future<void> warmUpUiImage(ui.Image image) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(image, Offset.zero, Paint());
  final ui.Picture picture = recorder.endRecording();
  final ui.Image rasterized = await picture.toImage(1, 1);
  rasterized.dispose();
  picture.dispose();
}

// Image.asset으로 그리는 배경용. precacheImage(CPU 디코딩) 후 warmUpGpuTexture(GPU 업로드)까지
// 한 번에 돌림. 화면 전환 암전 구간 동안 끝나도록 대상 화면의 didChangeDependencies에서
// await 없이 바로 부르는 용도라, 실패해도 그냥 무시함(그 경우 원래처럼 첫 페인트 때 로드됨)
Future<void> precacheAndWarmUpAsset(
  String assetPath,
  BuildContext context,
) async {
  try {
    final ImageProvider provider = AssetImage(assetPath);
    await precacheImage(provider, context);
    if (!context.mounted) return;
    await warmUpGpuTexture(provider, context);
  } catch (_) {}
}

// Flame(BakeryGame)이 loadSprite로 쓰는 배경용. Flame.images.load()는 CPU 디코딩만 하니까
// 받은 ui.Image로 GPU 업로드까지 이어서 해둠. Game.images 기본값이 전역 Flame.images라
// 여기서 로드한 것과 BakeryGame.onLoad()의 loadSprite가 같은 캐시를 씀
// fileName은 Flame 규칙대로 assets/images/ 아래 상대 경로
Future<void> loadAndWarmUpFlameImage(String fileName) async {
  try {
    await warmUpUiImage(await Flame.images.load(fileName));
  } catch (_) {}
}
