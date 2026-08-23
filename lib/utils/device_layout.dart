import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tablette / téléphone : seuil Material (shortestSide).
const double kPhoneShortestSide = 600;

bool isPhoneLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < kPhoneShortestSide;
}

bool isPhoneDevice() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return true;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.shortestSide < kPhoneShortestSide;
}

Future<void> lockPhoneToPortrait() async {
  if (!isPhoneDevice()) return;
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

Future<void> unlockOrientationsForFullscreenVideo() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> restoreAppOrientations() async {
  if (isPhoneDevice()) {
    await lockPhoneToPortrait();
  } else {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
