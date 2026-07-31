import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/project.dart';
import '../../providers/projects_provider.dart';
import '../../core/router/app_routes.dart';
import 'widgets/project_card.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  Future<void> _menu(BuildContext context, WidgetRef ref, Project p) async {
    final c = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_rounded, color: c.textPrimary),
                title: const Text('Open in editor'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.editorFor(p.id));
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: c.error),
                title: Text('Delete', style: TextStyle(color: c.error)),
                onTap: () {
                  ref.read(projectsProvider.notifier).remove(p.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.upload),
        backgroundColor: c.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: projects.isEmpty
            ? EmptyState(
                icon: Icons.video_library_outlined,
                title: 'No projects yet',
                message: 'Upload a video and let AI create your first edit.',
                actionLabel: 'New project',
                onAction: () => context.push(AppRoutes.upload),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.md, Gap.screen, 96),
                children: [
                  Text('Your projects', style: context.text.headlineMedium),
                  Gap.h16,
                  ...projects.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: ProjectCard(
                          project: p,
                          onTap: () => context.push(AppRoutes.editorFor(p.id)),
                          onMenu: () => _menu(context, ref, p),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
