import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:trackerfield/services/athlete_provider.dart';
import 'package:trackerfield/views/athletes_view.dart';

void main() {
  testWidgets('AthletesView affiche l\'état vide', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AthleteProvider.withAthletes([]),
        child: const MaterialApp(home: AthletesView()),
      ),
    );

    expect(find.byType(AthletesView), findsOneWidget);
    expect(find.textContaining('Aucun athlète'), findsOneWidget);
  });
}
