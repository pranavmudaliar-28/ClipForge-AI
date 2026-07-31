import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_boxes.dart';

/// Minimal signed-in user. In Phase 1 auth is mocked/local; the Firebase/Auth0
/// implementation slots in behind this same shape later.
class AuthUser {
  const AuthUser({required this.email, required this.name});

  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> j) =>
      AuthUser(email: j['email'] as String? ?? '', name: j['name'] as String? ?? '');

  Map<String, dynamic> toJson() => {'email': email, 'name': name};
}

/// Local, credential-free auth: any email "signs in" and persists.
class AuthNotifier extends StateNotifier<AuthUser?> {
  AuthNotifier() : super(_load());

  static AuthUser? _load() {
    final raw = HiveBoxes.settingsBox.get(HiveBoxes.authUser);
    if (raw == null) return null;
    return AuthUser.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> signIn({required String email, String? name}) async {
    final derived = (name == null || name.trim().isEmpty)
        ? _nameFromEmail(email)
        : name.trim();
    final user = AuthUser(email: email.trim(), name: derived);
    await HiveBoxes.settingsBox.put(HiveBoxes.authUser, user.toJson());
    state = user;
  }

  Future<void> signOut() async {
    await HiveBoxes.settingsBox.delete(HiveBoxes.authUser);
    state = null;
  }

  static String _nameFromEmail(String email) {
    final handle = email.contains('@') ? email.split('@').first : email;
    if (handle.isEmpty) return 'Creator';
    return handle[0].toUpperCase() + handle.substring(1);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthUser?>((ref) => AuthNotifier());
