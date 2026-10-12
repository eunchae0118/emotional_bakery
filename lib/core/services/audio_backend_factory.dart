// lib/core/services/audio_backend_factory.dart

// AudioService가 쓰는 공용 진입점. app_exit.dart/ios_viewport_patch.dart랑 똑같은 패턴으로
// 조건부 export를 씀 - dart.library.io가 있으면(안드로이드/iOS 네이티브/데스크톱, 즉 웹이
// 아닌 빌드) 기존 audioplayers 기반 audio_backend_players.dart를, 없으면(웹) Web Audio API
// 기반 audio_backend_web.dart를 씀. 두 파일 다 AudioBackend createAudioBackend() 함수를
// 똑같은 이름으로 내보내니까, 이 파일을 통해서만 가져다 쓰면 플랫폼 분기를 신경 안 써도 됨
export 'audio_backend_web.dart' if (dart.library.io) 'audio_backend_players.dart';
