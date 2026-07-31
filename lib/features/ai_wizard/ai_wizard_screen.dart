import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/utils/formatters.dart';
import '../../providers/projects_provider.dart';

class AiWizardScreen extends ConsumerStatefulWidget {
  const AiWizardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<AiWizardScreen> createState() => _AiWizardScreenState();
}

class _AiWizardScreenState extends ConsumerState<AiWizardScreen> {
  final _features = <String, bool>{
    'Remove silences': true,
    'Auto captions': true,
    'Smart zoom on faces': true,
    'Beat-synced cuts': false,
    'Cinematic color grade': true,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final project = ref.watch(projectsProvider.notifier).byId(widget.projectId);
    if (project == null) return const Scaffold(body: Center(child: Text('Project not found')));
    final t = project.timeline;
    final hasSpeech = project.transcript?.segments.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('AI edit ready')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Gap.screen),
              children: [
                Text('Your first cut is ready ✨', style: context.text.headlineSmall),
                Gap.h8,
                Text(
                  hasSpeech
                      ? 'Captions were generated from real speech-to-text. Tune the AI moves below, then perfect it on the timeline.'
                      : 'No speech detected (or the backend was offline). You can still edit everything on the timeline.',
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                Gap.h24,
                Row(children: [
                  _Stat(value: '${t.clips.length}', label: 'Scenes'),
                  Gap.w12,
                  _Stat(value: '${t.captions.length}', label: 'Captions'),
                  Gap.w12,
                  _Stat(value: Formatters.duration(t.durationMs), label: 'Duration'),
                ]),
                Gap.h24,
                Text('AI adjustments', style: context.text.titleMedium),
                Gap.h12,
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
                  child: Column(
                    children: _features.keys.map((k) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text(k, style: context.text.bodyLarge)),
                          Switch(value: _features[k]!, onChanged: (v) => setState(() => _features[k] = v)),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.screen),
            child: AppButton(
              label: 'Open in editor',
              icon: Icons.tune_rounded,
              onPressed: () => context.pushReplacement(AppRoutes.editorFor(widget.projectId)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(children: [
          Text(value, style: context.text.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
        ]),
      ),
    );
  }
}
