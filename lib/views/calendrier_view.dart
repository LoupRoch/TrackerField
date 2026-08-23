import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/athlete.dart';
import '../models/competition.dart';
import '../models/seance.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../widgets/competition_dialog.dart';
import 'modeles_seance_view.dart';
import 'seance_edit_view.dart';

enum _EventKind { effectuee, planifiee, competition }

class _DayEvent {
  const _DayEvent.effectuee(this.seance)
      : kind = _EventKind.effectuee,
        competition = null;

  const _DayEvent.planifiee(this.seance)
      : kind = _EventKind.planifiee,
        competition = null;

  const _DayEvent.competition(this.competition)
      : kind = _EventKind.competition,
        seance = null;

  final _EventKind kind;
  final Seance? seance;
  final Competition? competition;
}

class CalendrierView extends StatefulWidget {
  const CalendrierView({super.key});

  @override
  State<CalendrierView> createState() => CalendrierViewState();
}

class CalendrierViewState extends State<CalendrierView> {
  List<Seance> _effectuees = [];
  List<Seance> _planifiees = [];
  List<Competition> _competitions = [];
  var _loading = true;
  var _localeReady = false;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  static const _colorEffectuee = Color(0xFF2E7D32);
  static const _colorPlanifiee = Color(0xFFEF6C00);
  static const _colorCompetition = Color(0xFF6A1B9A);

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

  Future<void> reload() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    if (!mounted) return;
    setState(() {
      _effectuees = db.getSeances();
      _planifiees = db.getPlanifiees();
      _competitions = db.getCompetitions();
      _loading = false;
    });
  }

  DateTime _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<_DayEvent> _eventsForDay(DateTime day) {
    final key = _dayKey(day);
    final events = <_DayEvent>[];

    for (final seance in _effectuees) {
      final d = seance.date;
      if (d.year == key.year && d.month == key.month && d.day == key.day) {
        events.add(_DayEvent.effectuee(seance));
      }
    }
    for (final seance in _planifiees) {
      final d = seance.datePrevue;
      if (d == null) continue;
      if (d.year == key.year && d.month == key.month && d.day == key.day) {
        events.add(_DayEvent.planifiee(seance));
      }
    }
    for (final competition in _competitions) {
      if (competition.coversDay(key)) {
        events.add(_DayEvent.competition(competition));
      }
    }
    return events;
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
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

  Future<void> _openModeles() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ModelesSeanceView(),
      ),
    );
    await reload();
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_available, color: _colorPlanifiee),
              title: const Text('Planifier une séance'),
              onTap: () => Navigator.pop(context, 'planifier'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: _colorCompetition),
              title: const Text('Ajouter une compétition'),
              onTap: () => Navigator.pop(context, 'competition'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'planifier') {
      await _planifierModele();
    } else {
      await _addOrEditCompetition();
    }
  }

  Future<void> _planifierModele() async {
    final db = context.read<DatabaseService>();
    final templates = db.getTemplates();
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun modèle disponible. Crée-en un via le bouton Modèles.',
          ),
        ),
      );
      return;
    }

    final selected = await showDialog<Seance>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Planifier un modèle'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(template.titre),
                subtitle: Text('${template.blocs.length} bloc(s)'),
                onTap: () => Navigator.pop(context, template),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    final day = _dayKey(_selectedDay);
    final planifiee = Seance(
      titre: selected.titre,
      date: day,
      athleteIds: const [],
      blocs: selected.blocs.map((b) => b.copy(asNew: true)).toList(),
      isTemplate: false,
      estPlanifiee: true,
      datePrevue: day,
    );

    await db.addSeance(planifiee);
    await reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '« ${selected.titre} » planifiée le ${DateFormat('dd/MM/yyyy').format(day)}.',
        ),
      ),
    );
  }

  Future<void> _addOrEditCompetition({Competition? existing}) async {
    final result = await showCompetitionDialog(
      context,
      initial: existing,
      defaultDay: _selectedDay,
    );
    if (result == null || !mounted) return;
    final db = context.read<DatabaseService>();
    if (existing == null) {
      await db.addCompetition(result);
    } else {
      await db.updateCompetition(result);
    }
    await reload();
  }

  Future<void> _deletePlanifiee(Seance seance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la planification'),
        content: Text('Retirer « ${seance.titre} » de ce jour ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DatabaseService>().deleteSeance(seance.id);
    await reload();
  }

  Future<void> _deleteCompetition(Competition competition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la compétition'),
        content: Text('Supprimer « ${competition.titre} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DatabaseService>().deleteCompetition(competition.id);
    await reload();
  }

  Future<void> _openSeance(Seance seance) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeanceEditView(seanceId: seance.id),
      ),
    );
    await reload();
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final athletesById = {
      for (final a in context.watch<AthleteProvider>().athletes) a.id: a,
    };
    final selectedEvents = _eventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          TextButton.icon(
            onPressed: _openModeles,
            icon: const Icon(Icons.folder_copy_outlined),
            label: const Text('Modèles'),
          ),
          IconButton(
            tooltip: 'Exporter Excel',
            onPressed: _exportData,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: !_localeReady || _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ExpansionTile(
                    title: const Text('Afficher le calendrier'),
                    initiallyExpanded: true,
                    children: [
                      TableCalendar<_DayEvent>(
                        locale: 'fr_FR',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _eventsForDay,
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
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
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
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return null;
                            final kinds = events.map((e) => e.kind).toSet();
                            return Positioned(
                              bottom: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (kinds.contains(_EventKind.effectuee))
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: _colorEffectuee,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (kinds.contains(_EventKind.planifiee))
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: _colorPlanifiee,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (kinds.contains(_EventKind.competition))
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: _colorCompetition,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _legendDot(_colorEffectuee, 'Effectuée'),
                            _legendDot(_colorPlanifiee, 'Planifiée'),
                            _legendDot(_colorCompetition, 'Compétition'),
                          ],
                        ),
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
                  child: selectedEvents.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun événement ce jour-là.\nUtilise « Ajouter » pour planifier ou créer une compétition.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: selectedEvents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final event = selectedEvents[index];
                            return switch (event.kind) {
                              _EventKind.effectuee => _buildEffectueeTile(
                                  event.seance!,
                                  athletesById,
                                ),
                              _EventKind.planifiee =>
                                _buildPlanifieeTile(event.seance!),
                              _EventKind.competition =>
                                _buildCompetitionTile(
                                  event.competition!,
                                  athletesById,
                                ),
                            };
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEffectueeTile(
    Seance seance,
    Map<String, Athlete> athletesById,
  ) {
    final athleteNames = seance.athleteIds
        .map((id) => athletesById[id]?.nom ?? id)
        .join(', ');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFC8E6C9),
          child: Icon(Icons.check_circle, color: _colorEffectuee),
        ),
        title: Text(
          seance.titre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Séance effectuée · ${seance.blocs.length} bloc(s)'
          '${athleteNames.isEmpty ? '' : ' · $athleteNames'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openSeance(seance),
      ),
    );
  }

  Widget _buildPlanifieeTile(Seance seance) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE0B2),
          child: Icon(Icons.schedule, color: _colorPlanifiee),
        ),
        title: Text(
          seance.titre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${seance.blocs.length} bloc(s) prévus'),
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _deletePlanifiee(seance),
        ),
      ),
    );
  }

  Widget _buildCompetitionTile(
    Competition competition,
    Map<String, Athlete> athletesById,
  ) {
    final athleteNames = competition.athleteIds
        .map((id) => athletesById[id]?.nom ?? id)
        .join(', ');
    final range = competition.dateDebut.year == competition.dateFin.year &&
            competition.dateDebut.month == competition.dateFin.month &&
            competition.dateDebut.day == competition.dateFin.day
        ? DateFormat('dd/MM/yyyy').format(competition.dateDebut)
        : '${DateFormat('dd/MM').format(competition.dateDebut)} → ${DateFormat('dd/MM/yyyy').format(competition.dateFin)}';
    final lieu =
        competition.lieu.isEmpty ? '' : ' · ${competition.lieu}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE1BEE7),
          child: Icon(Icons.emoji_events, color: _colorCompetition),
        ),
        title: Text(
          competition.titre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Compétition · $range$lieu'
          '${athleteNames.isEmpty ? '' : '\n$athleteNames'}',
        ),
        isThreeLine: athleteNames.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _addOrEditCompetition(existing: competition),
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _deleteCompetition(competition),
            ),
          ],
        ),
      ),
    );
  }
}
