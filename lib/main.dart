import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/athlete_provider.dart';
import 'services/database_service.dart';
import 'views/dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseService = DatabaseService();
  await databaseService.init();

  runApp(TrackerFieldApp(databaseService: databaseService));
}

class TrackerFieldApp extends StatelessWidget {
  const TrackerFieldApp({super.key, required this.databaseService});

  final DatabaseService databaseService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider(
          create: (_) => AthleteProvider(databaseService),
        ),
      ],
      child: MaterialApp(
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        home: const DashboardView(),
      ),
    );
  }
}
