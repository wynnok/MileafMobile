import 'package:flutter/material.dart';

import '../design/components/page_bar.dart';

import 'map_consent.dart';
import 'map_panel.dart';
import 'map_platform.dart';
import 'map_scene.dart';

class DriveMapPage extends StatelessWidget {
  const DriveMapPage({
    super.key,
    required this.scene,
    required this.consent,
    this.platform,
  });
  final MapScene scene;
  final MapConsentController consent;
  final MapPlatform? platform;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(context, title: const Text('行程地图')),
    body: MapPanel(
      scene: scene,
      consent: consent,
      platform: platform,
      height: double.infinity,
      interactive: true,
      showControls: true,
    ),
  );
}
