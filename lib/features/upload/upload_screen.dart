import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/media_file.dart';
import '../../providers/projects_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _busy = false;

  Future<void> _pick(MediaSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String? path;
      var filename = 'clip.mp4';
      switch (source) {
        case MediaSource.gallery:
        case MediaSource.camera:
          final file = await ImagePicker().pickVideo(
            source: source == MediaSource.camera ? ImageSource.camera : ImageSource.gallery,
          );
          path = file?.path;
          if (file != null) filename = file.name;
        case MediaSource.files:
          final result = await FilePicker.platform.pickFiles(type: FileType.video);
          path = result?.files.single.path;
          if (result != null) filename = result.files.single.name;
        default:
          _soon();
          return;
      }
      if (path == null) return;
      final project = ref.read(projectsProvider.notifier).createDraft(title: _title(filename), sourcePath: path);
      if (mounted) context.pushReplacement(AppRoutes.processingFor(project.id));
    } catch (e) {
      if (mounted) showAppToast(context, 'Could not open source: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _soon() => showAppToast(context, 'Cloud imports arrive in a later release');

  String _title(String filename) {
    final base = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
    return base.isEmpty ? 'New project' : base;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('New project')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.screen),
          children: [
            _DropZone(busy: _busy, onTap: () => _pick(MediaSource.gallery)),
            Gap.h24,
            Text('Import from', style: context.text.titleMedium),
            Gap.h12,
            _tile(c, Icons.photo_library_rounded, 'Gallery', 'Pick a video from your device', () => _pick(MediaSource.gallery)),
            _tile(c, Icons.videocam_rounded, 'Camera', 'Record something new', () => _pick(MediaSource.camera)),
            _tile(c, Icons.folder_rounded, 'Files', 'Browse device storage', () => _pick(MediaSource.files)),
            Divider(height: Gap.xxl, color: c.border),
            _tile(c, Icons.add_to_drive_rounded, 'Google Drive', 'Coming soon', _soon, enabled: false),
            _tile(c, Icons.cloud_outlined, 'Dropbox', 'Coming soon', _soon, enabled: false),
            _tile(c, Icons.cloud_queue_rounded, 'OneDrive', 'Coming soon', _soon, enabled: false),
          ],
        ),
      ),
    );
  }

  Widget _tile(dynamic c, IconData icon, String label, String subtitle, VoidCallback onTap, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Radii.sm)),
          child: Icon(icon, color: c.textPrimary),
        ),
        title: Text(label, style: context.text.titleSmall),
        subtitle: Text(subtitle, style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textTertiary),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 184,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          gradient: LinearGradient(colors: [
            c.primary.withValues(alpha: 0.16),
            c.accent.withValues(alpha: 0.10),
          ]),
          border: Border.all(color: c.primary.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: busy
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(Radii.md)),
                    child: const Icon(Icons.upload_rounded, color: Colors.white, size: 30),
                  ),
                  Gap.h12,
                  Text('Tap to upload a video', style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text('MP4, MOV up to 10 min',
                      style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
                ]),
        ),
      ),
    );
  }
}
