import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackerfield/services/athlete_provider.dart';
import 'package:trackerfield/services/database_service.dart';
import 'package:trackerfield/services/demo_data_service.dart';
import 'package:trackerfield/services/settings_provider.dart';
import 'package:trackerfield/views/athlete_detail_view.dart';
import 'package:trackerfield/views/athletes_view.dart';
import 'package:trackerfield/views/calendrier_view.dart';
import 'package:trackerfield/views/dashboard_view.dart';
import 'package:trackerfield/views/live_session_view.dart';
import 'package:trackerfield/views/modeles_seance_view.dart';
import 'package:trackerfield/views/seance_edit_view.dart';

/// Taille tablette paysage pour les captures de présentation.
const presentationSize = Size(1280, 800);

Future<void> saveScreenshot(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String outputPath,
) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

Widget buildPresentationApp({
  required GlobalKey boundaryKey,
  required DatabaseService db,
  required SettingsProvider settings,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      Provider<DatabaseService>.value(value: db),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider(
        create: (_) => AthleteProvider(db),
      ),
    ],
    child: RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: settings.seedColor),
          useMaterial3: true,
        ),
        home: home,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory outputDir;
  late DatabaseService db;
  late SettingsProvider settings;
  late String firstAthleteId;
  late String richSeanceId;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trackerfield_pres_');
    outputDir = Directory('docs/presentation');
    await outputDir.create(recursive: true);

    db = DatabaseService();
    await db.init(path: tempDir.path);
    await DemoDataService(db).seed();

    firstAthleteId = db.getAthletes().first.id;
    richSeanceId = db
        .getSeances()
        .firstWhere((s) => s.titre.contains('Fractionné'))
        .id;

    settings = SettingsProvider();
    await settings.load();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> capture(
    WidgetTester tester,
    Widget home,
    String fileName,
  ) async {
    final boundaryKey = GlobalKey();
    tester.view.physicalSize = presentationSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildPresentationApp(
        boundaryKey: boundaryKey,
        db: db,
        settings: settings,
        home: home,
      ),
    );
    await saveScreenshot(
      tester,
      boundaryKey,
      '${outputDir.path}/$fileName',
    );
  }

  testWidgets('génère les captures de présentation', (tester) async {
    await capture(tester, const AthletesView(), '01_liste_athletes.png');

    await capture(
      tester,
      AthleteDetailView(athleteId: firstAthleteId),
      '02_fiche_athlete.png',
    );

    await capture(
      tester,
      const LiveSessionView(),
      '03_seance_live.png',
    );

    await capture(
      tester,
      const CalendrierView(),
      '04_calendrier.png',
    );

    await capture(
      tester,
      SeanceEditView(seanceId: richSeanceId),
      '05_detail_seance.png',
    );

    await capture(
      tester,
      const ModelesSeanceView(),
      '06_modeles_seance.png',
    );

    await capture(
      tester,
      const DashboardView(),
      '07_dashboard_navigation.png',
    );

    expect(File('${outputDir.path}/01_liste_athletes.png').existsSync(),
        isTrue);
  });
}
