import 'package:flutter/material.dart';

import '../utils/device_layout.dart';
import '../widgets/session_panel.dart';

class LiveSessionView extends StatefulWidget {
  const LiveSessionView({super.key});

  @override
  State<LiveSessionView> createState() => _LiveSessionViewState();
}

class _LiveSessionViewState extends State<LiveSessionView> {
  var _parallelSessions = false;

  /// Conserve l'état du panneau principal au passage en split-screen.
  final _panelAKey = GlobalKey<SessionPanelState>();
  final _panelBKey = GlobalKey<SessionPanelState>();

  void _enableParallelSessions() {
    setState(() => _parallelSessions = true);
  }

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    final showParallelAction = !phone && !_parallelSessions;
    final panelA = _panelAKey.currentState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séance en direct'),
        actions: [
          if (!_parallelSessions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                tooltip: 'Sauvegarder la séance',
                onPressed: panelA?.isSaving == true ? null : panelA?.saveSeance,
                icon: panelA?.isSaving == true
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
              ),
            ),
          if (showParallelAction)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _enableParallelSessions,
                icon: const Icon(Icons.view_column),
                label: const Text('Ajouter une séance en parallèle'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: !phone && _parallelSessions
            ? _buildSplitView()
            : _buildSingleView(),
      ),
    );
  }

  Widget _buildPanelA({required String label, bool showEmbeddedSave = true}) {
    return SessionPanel(
      key: _panelAKey,
      panelLabel: label,
      showEmbeddedSaveButton: showEmbeddedSave,
      onChanged: showEmbeddedSave ? null : () => setState(() {}),
    );
  }

  Widget _buildSingleView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPanelA(label: 'Séance', showEmbeddedSave: false),
        ),
      ),
    );
  }

  Widget _buildSplitView() {
    return Row(
      children: [
        Expanded(
          child: _buildPanelA(label: 'Séance A'),
        ),
        const VerticalDivider(width: 2, thickness: 2),
        Expanded(
          child: SessionPanel(
            key: _panelBKey,
            panelLabel: 'Séance B',
          ),
        ),
      ],
    );
  }
}
