/// Small formatting helpers used across the UI.
abstract final class Formatters {
  /// `123456` ms -> `2:03`. Hours are included only when needed.
  static String duration(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '$m:${two(s)}';
  }

  /// `01:23.4` timecode for the editor ruler (seconds with one decimal).
  static String timecode(int milliseconds) {
    final m = milliseconds ~/ 60000;
    final s = (milliseconds % 60000) / 1000;
    return '${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }

  /// Relative "time ago" for project lists.
  static String timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  static String fileSize(int bytes) {
    if (bytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  const Formatters._();
}
