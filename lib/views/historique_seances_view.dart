import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/seance.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import 'seance_edit_view.dart';

class HistoriqueSeancesView extends StatefulWidget {
  const HistoriqueSeancesView({super.key});

  @override
  State<HistoriqueSeancesView> createState() => HistoriqueSeancesViewState();
}

class HistoriqueSeancesViewState extends State<HistoriqueSeancesView> {
  List<Seance> _seances = [];
  Map<DateTime, List<Seance>> _seancesByDay = {};
  var _loading = true;
  var _localeReady = false;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initLocaleAndData();
  }

  Future<void> _initLocaleAndData() async {
    await initializeDateFormatting('fr_FR');
    if (!mounted) return;
    setState(() => _localeReady = true);
    await reload();
  }

  Future<void> reload() => _loadSeances();

  DateTime _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _loadSeances() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    if (!mounted) return;

    final seances = db.getSeances();
    final byDay = <DateTime, List<Seance>>{};
    for (final seance in seances) {
      final key = _dayKey(seance.date);
      byDay.putIfAbsent(key, () => []).add(seance);
    }

    setState(() {
      _seances = seances;
      _seancesByDay = byDay;
      _loading = false;
    });
  }

  List<Seance> _seancesForDay(DateTime day) =>
      _seancesByDay[_dayKey(day)] ?? const [];

  String _formatDate(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  }

  Future<void> _openSeance(Seance seance) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeanceEditView(seanceId: seance.id),
      ),
    );
    await _loadSeances();
  }

  Future<void> _exportData() async {
    try {
      await ExportService(context.read<DatabaseService>()).exporterDonnees();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final athletesById = {
      for (final a in context.watch<AthleteProvider>().athletes) a.id: a,
    };
    final selectedSeances = _seancesForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des séances'),
        actions: [
          IconButton(
            tooltip: 'Exporter Excel',
            onPressed: _exportData,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loadSeances,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_localeReady || _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ExpansionTile(
                    title: const Text('Afficher le calendrier'),
                    initiallyExpanded: false,
                    children: [
                      TableCalendar<Seance>(
                        locale: 'fr_FR',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _seancesForDay,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Mois',
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                        ),
                        calendarStyle: CalendarStyle(
                          markersMaxCount: 3,
                          markerDecoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatDate(_selectedDay),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: selectedSeances.isEmpty
                      ? Center(
                          child: Text(
                            _seances.isEmpty
                                ? 'Aucune séance sauvegardée.\nTermine une séance depuis Entraînement.'
                                : 'Aucune séance ce jour-là.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: selectedSeances.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final seance = selectedSeances[index];
                            final athleteNames = seance.athleteIds
                                .map((id) => athletesById[id]?.nom ?? id)
                                .join(', ');

                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  child: Text('${seance.blocs.length}'),
                                ),
                                title: Text(
                                  seance.titre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${seance.blocs.length} bloc(s)'
                                  '${athleteNames.isEmpty ? '' : ' · $athleteNames'}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openSeance(seance),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
