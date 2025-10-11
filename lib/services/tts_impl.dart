// Conditional export: use web implementation when running on web, otherwise use IO implementation
export 'tts_impl_io.dart' if (dart.library.html) 'tts_impl_web.dart';
