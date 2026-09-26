// lib/core/services/ios_viewport_patch_stub.dart

// 웹이 아닌 빌드(안드로이드/iOS 네이티브/데스크톱)용 구현. viewport meta 태그 자체가
// 웹에만 있는 개념이라 여기선 그냥 아무것도 안 함. ios_viewport_patch.dart의 조건부
// export로 dart.library.io가 있을 때만 쓰임

void patchIosViewportMeta() {}
