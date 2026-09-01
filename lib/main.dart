import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/athlete_provider.dart';
import 'services/database_service.dart';
import 'services/settings_provider.dart';
import 'utils/device_layout.dart';
import 'views/dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPhoneToPortrait();

  final databaseService = DatabaseService();
  await databaseService.init();

  final settings = SettingsProvider();
  await settings.load();

  runApp(
    TrackerFieldApp(
      databaseService: databaseService,
      settings: settings,
    ),
  );
}

class TrackerFieldApp extends StatelessWidget {
  const TrackerFieldApp({
    super.key,
    required this.databaseService,
    required this.settings,
  });

  final DatabaseService databaseService;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) => AthleteProvider(databaseService),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'TrackerField',
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr', 'FR'),
            supportedLocales: const [Locale('fr', 'FR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: settings.themeMode,
            home: const DashboardView(),
          );
        },
      ),
    );
  }
}
