/// Route paths + names, kept in one place so screens don't hard-code strings.
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';

  // Bottom-nav branches
  static const home = '/home';
  static const templates = '/templates';
  static const ai = '/ai';
  static const projects = '/projects';
  static const profile = '/profile';

  // Pushed flows (carry a project id)
  static const upload = '/upload';
  static const processing = '/processing';
  static const wizard = '/wizard';
  static const editor = '/editor';
  static const export = '/export';

  static String processingFor(String id) => '$processing/$id';
  static String wizardFor(String id) => '$wizard/$id';
  static String editorFor(String id) => '$editor/$id';
  static String exportFor(String id) => '$export/$id';

  const AppRoutes._();
}
