import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/project_repository.dart';
import '../data/models/project.dart';
import 'app_providers.dart';

/// Holds the list of projects (newest first) and mediates all writes so the UI
/// stays in sync with Hive.
class ProjectsNotifier extends StateNotifier<List<Project>> {
  ProjectsNotifier(this._repo) : super(_repo.all());

  final ProjectRepository _repo;

  Project createDraft({required String title, String? sourcePath, int durationMs = 0}) {
    final now = DateTime.now();
    final project = Project(
      id: 'p_${now.microsecondsSinceEpoch}',
      title: title,
      createdAt: now,
      updatedAt: now,
      status: ProjectStatus.draft,
      sourcePath: sourcePath,
      durationMs: durationMs,
    );
    _repo.save(project);
    state = _repo.all();
    return project;
  }

  Future<void> upsert(Project project) async {
    await _repo.save(project.copyWith(updatedAt: DateTime.now()));
    state = _repo.all();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.all();
  }

  Project? byId(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return _repo.byId(id);
  }
}

final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) => ProjectsNotifier(ref.watch(projectRepositoryProvider)),
);
