import 'package:hive/hive.dart';

import '../models/project.dart';

/// CRUD over the Hive `projects` box. Each project is stored as a JSON map
/// keyed by its id.
class ProjectRepository {
  ProjectRepository(this._box);

  final Box _box;

  List<Project> all() {
    final items = _box.values
        .map((raw) => Project.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Project? byId(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Project.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(Project project) => _box.put(project.id, project.toJson());

  Future<void> delete(String id) => _box.delete(id);
}
