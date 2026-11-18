import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mileaf/src/design/tokens.dart';

/// The families a render harness may register the stand-in CJK face under.
///
/// These are exactly the fallbacks the product declares for itself, so a
/// render never invents a family the app does not use, and never aliases a
/// CJK face to `Inter`.
const renderFallbackFamilies = MileafType.fallback;

/// Fonts for an opt-in render harness: the shipped `Inter` weights plus a
/// **separately declared** CJK fallback.
///
/// `Inter` comes from `assets/fonts/` — the same three files `pubspec.yaml`
/// bundles — so Regular/Medium/SemiBold keep their real weights. The CJK face
/// is only registered under [renderFallbackFamilies]; the harness therefore
/// exercises the same "Inter first, CJK fallback second" chain the app uses,
/// instead of pretending a substitute font is Inter.
///
/// [cjkFontPath] is a local font file used for Chinese glyphs in test
/// renders. It proves nothing about a device's own fallback.
Future<void> loadRenderFonts({required String cjkFontPath}) async {
  final inter = FontLoader(MileafType.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await inter.load();

  final bytes = ByteData.sublistView(File(cjkFontPath).readAsBytesSync());
  for (final family in renderFallbackFamilies) {
    await (FontLoader(family)..addFont(Future.value(bytes))).load();
  }

  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
