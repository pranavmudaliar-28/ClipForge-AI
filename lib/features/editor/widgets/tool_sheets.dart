import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/canvas_preset.dart';
import '../../../data/models/edit_settings.dart';
import '../../../providers/editor_provider.dart';
import '../editor_theme.dart';

/// All editor tool panels, styled to match the Twintra UI kit (deep-black panel,
/// close · reset · title · check header, cyan controls). Every control performs
/// a REAL edit via [EditorController]; visual ones update the live preview.

Color _hex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));

// ── Canvas ────────────────────────────────────────────────────────────────
Future<void> showCanvasSheet(BuildContext context, String currentId, ValueChanged<String> onSelect) {
  return edShowPanel(
    context,
    EdPanel(
      title: 'Canvas',
      child: SizedBox(
        height: 280,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
          itemCount: CanvasPreset.all.length,
          itemBuilder: (_, i) {
            final p = CanvasPreset.all[i];
            final sel = p.id == currentId;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(p.id);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Ed.barAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Ed.accent : Colors.white10, width: sel ? 1.8 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(p.icon, color: sel ? Ed.accent : Ed.icon, size: 22),
                  const SizedBox(height: 8),
                  Text(p.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sel ? Ed.accent : Ed.icon, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(p.ratioLabel, style: const TextStyle(color: Ed.muted, fontSize: 10)),
                ]),
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ── Speed ───────────────────────────────────────────────────────────────────
Future<void> showSpeedSheet(BuildContext context, double current, ValueChanged<double> onSelect) {
  return edShowPanel(
    context,
    EdPanel(
      title: 'Speed',
      onReset: () => onSelect(1.0),
      child: EdTickRuler(
        value: current,
        min: 0.1,
        max: 4.0,
        labels: const [0.1, 1, 2, 3, 4],
        valueFmt: (v) => '${v.toStringAsFixed(1)}x',
        labelFmt: (v) => v == 0.1 ? '0.1x' : '${v.toInt()}x',
        onChanged: (_) {},
        onChangeEnd: onSelect,
      ),
    ),
  );
}

// ── Filter presets ────────────────────────────────────────────────────────────
Future<void> showFilterSheet(BuildContext context, EditorController ctrl) {
  const order = FilterPreset.values;
  String label(FilterPreset f) => switch (f) {
        FilterPreset.none => 'None',
        FilterPreset.cinematic => 'Cinema',
        FilterPreset.vintage => 'Vintage',
        FilterPreset.warm => 'Warm',
        FilterPreset.cool => 'Cool',
        FilterPreset.bw => 'B&W',
        FilterPreset.vivid => 'Vivid',
        FilterPreset.fade => 'Fade',
      };
  Gradient grad(FilterPreset f) => switch (f) {
        FilterPreset.none => const LinearGradient(colors: [Color(0xFF3A3F45), Color(0xFF23272B)]),
        FilterPreset.cinematic => const LinearGradient(colors: [Color(0xFF16404D), Color(0xFF0B1E33)]),
        FilterPreset.vintage => const LinearGradient(colors: [Color(0xFFB07B3E), Color(0xFF5C3A1E)]),
        FilterPreset.warm => const LinearGradient(colors: [Color(0xFFFF9D42), Color(0xFFD23E2E)]),
        FilterPreset.cool => const LinearGradient(colors: [Color(0xFF37C6F0), Color(0xFF2A5AD6)]),
        FilterPreset.bw => const LinearGradient(colors: [Color(0xFFE6E6E6), Color(0xFF2A2A2A)]),
        FilterPreset.vivid => const LinearGradient(colors: [Color(0xFFFF3DA6), Color(0xFF17D3F0)]),
        FilterPreset.fade => const LinearGradient(colors: [Color(0xFFBFB6A8), Color(0xFF7C766B)]),
      };
  return edShowPanel(
    context,
    EdPanel(
      title: 'Filter',
      onReset: () => ctrl.setFilter(FilterPreset.none),
      child: StatefulBuilder(builder: (context, setLocal) {
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: order.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final f = order[i];
              final sel = ctrl.settings.filter == f;
              return _PresetThumb(
                label: label(f),
                gradient: grad(f),
                selected: sel,
                onTap: () {
                  ctrl.setFilter(f);
                  setLocal(() {});
                },
              );
            },
          ),
        );
      }),
    ),
  );
}

// ── Adjust (colour) ───────────────────────────────────────────────────────────
Future<void> showAdjustSheet(BuildContext context, EditorController ctrl) {
  final adj = <_Adj>[
    _Adj('Brightness', Icons.brightness_6_outlined, -0.5, 0.5, const [-0.5, 0, 0.5],
        (c) => c.brightness, (c, v) => c.copyWith(brightness: v), (v) => (v * 200).round()),
    _Adj('Contrast', Icons.contrast_rounded, 0.5, 1.5, const [0.5, 1, 1.5],
        (c) => c.contrast, (c, v) => c.copyWith(contrast: v), (v) => ((v - 1) * 100).round()),
    _Adj('Saturation', Icons.water_drop_outlined, 0, 2, const [0, 1, 2],
        (c) => c.saturation, (c, v) => c.copyWith(saturation: v), (v) => ((v - 1) * 100).round()),
    _Adj('Temp', Icons.thermostat_rounded, -1, 1, const [-1, 0, 1],
        (c) => c.temperature, (c, v) => c.copyWith(temperature: v), (v) => (v * 100).round()),
    _Adj('Sharpen', Icons.details_rounded, 0, 1, const [0, 0.5, 1],
        (c) => c.sharpen, (c, v) => c.copyWith(sharpen: v), (v) => (v * 100).round()),
  ];
  int sel = 0;
  return edShowPanel(
    context,
    EdPanel(
      title: 'Adjust',
      onReset: () => ctrl.setColor(const ColorAdjust()),
      child: StatefulBuilder(builder: (context, setLocal) {
        final a = adj[sel];
        return Column(mainAxisSize: MainAxisSize.min, children: [
          EdTickRuler(
            key: ValueKey(sel),
            value: a.get(ctrl.settings.color),
            min: a.min,
            max: a.max,
            labels: a.labels,
            valueFmt: (v) => a.disp(v).toString(),
            labelFmt: (v) => a.disp(v).toString(),
            onChanged: (v) => ctrl.setColor(a.set(ctrl.settings.color, v), record: false),
            onChangeEnd: (v) => ctrl.setColor(a.set(ctrl.settings.color, v)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: adj.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _AdjChip(
                icon: adj[i].icon,
                label: adj[i].name,
                selected: i == sel,
                onTap: () => setLocal(() => sel = i),
              ),
            ),
          ),
        ]);
      }),
    ),
  );
}

// ── Effects ─────────────────────────────────────────────────────────────────
Future<void> showEffectsSheet(BuildContext context, EditorController ctrl) {
  return edShowPanel(
    context,
    EdPanel(
      title: 'Effects',
      onReset: () => ctrl.setEffects(const Effects()),
      child: StatefulBuilder(builder: (context, setLocal) {
        var e = ctrl.settings.effects;
        void live(Effects n) {
          e = n;
          ctrl.setEffects(n, record: false);
          setLocal(() {});
        }

        return Column(mainAxisSize: MainAxisSize.min, children: [
          EdSliderRow(
              label: 'Blur',
              value: e.blur,
              min: 0,
              max: 1,
              valueFmt: (v) => '${(v * 100).round()}%',
              onChanged: (v) => live(e.copyWith(blur: v)),
              onChangeEnd: (_) => ctrl.setEffects(e)),
          EdSliderRow(
              label: 'Vignette',
              value: e.vignette,
              min: 0,
              max: 1,
              valueFmt: (v) => '${(v * 100).round()}%',
              onChanged: (v) => live(e.copyWith(vignette: v)),
              onChangeEnd: (_) => ctrl.setEffects(e)),
          EdSliderRow(
              label: 'Grain',
              value: e.grain,
              min: 0,
              max: 1,
              valueFmt: (v) => '${(v * 100).round()}%',
              onChanged: (v) => live(e.copyWith(grain: v)),
              onChangeEnd: (_) => ctrl.setEffects(e)),
        ]);
      }),
    ),
  );
}

// ── Text overlays ─────────────────────────────────────────────────────────────
/// Opens the text panel. Pass [editing] to edit an existing overlay in place
/// (pre-fills the fields and calls [EditorController.updateText] on confirm);
/// omit it to add a new overlay.
Future<void> showTextSheet(BuildContext context, EditorController ctrl, {TextOverlay? editing}) {
  final controller = TextEditingController(text: editing?.text ?? '');
  const colors = ['#FFFFFF', '#000000', '#08D0F2', '#7C5CFF', '#FFD60A', '#FF453A', '#30D158'];
  double size = editing?.sizePt ?? 34;
  double yNorm = editing?.yNorm ?? 0.5;
  String colorHex = editing?.colorHex ?? '#FFFFFF';
  return edShowPanel(
    context,
    EdPanel(
      title: editing == null ? 'Text' : 'Edit text',
      onConfirm: () {
        final txt = controller.text.trim();
        if (txt.isEmpty) return;
        if (editing != null) {
          // Preserve id + xNorm; update the edited fields.
          ctrl.updateText(editing.copyWith(text: txt, yNorm: yNorm, sizePt: size, colorHex: colorHex));
        } else {
          ctrl.addText(TextOverlay(
            id: 't_${DateTime.now().microsecondsSinceEpoch}',
            text: txt,
            yNorm: yNorm,
            sizePt: size,
            colorHex: colorHex,
          ));
        }
      },
      child: StatefulBuilder(builder: (context, setLocal) {
        final texts = ctrl.settings.texts;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            cursorColor: Ed.accent,
            decoration: InputDecoration(
              hintText: 'Enter text…',
              hintStyle: const TextStyle(color: Ed.muted),
              filled: true,
              fillColor: Ed.barAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Position', style: TextStyle(color: Ed.icon, fontSize: 13)),
            const SizedBox(width: 12),
            _pill('Top', yNorm < 0.34, () => setLocal(() => yNorm = 0.15)),
            const SizedBox(width: 8),
            _pill('Middle', yNorm >= 0.34 && yNorm <= 0.66, () => setLocal(() => yNorm = 0.5)),
            const SizedBox(width: 8),
            _pill('Bottom', yNorm > 0.66, () => setLocal(() => yNorm = 0.85)),
          ]),
          const SizedBox(height: 8),
          EdSliderRow(
              label: 'Size',
              value: size,
              min: 16,
              max: 80,
              valueFmt: (v) => v.round().toString(),
              onChanged: (v) => setLocal(() => size = v),
              onChangeEnd: (_) {}),
          const SizedBox(height: 4),
          Row(children: [
            const Text('Colour', style: TextStyle(color: Ed.icon, fontSize: 13)),
            const SizedBox(width: 12),
            ...colors.map((hex) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ColorDot(hex: hex, selected: colorHex == hex, onTap: () => setLocal(() => colorHex = hex)),
                )),
          ]),
          if (texts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Added', style: TextStyle(color: Ed.muted, fontSize: 12)),
            ...texts.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(t.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                    onPressed: () {
                      ctrl.removeText(t.id);
                      setLocal(() {});
                    },
                  ),
                )),
          ],
        ]);
      }),
    ),
  );
}

// ── Volume / audio ─────────────────────────────────────────────────────────────
Future<void> showAudioSheet(BuildContext context, EditorController ctrl) {
  return edShowPanel(
    context,
    EdPanel(
      title: 'Volume',
      onReset: () => ctrl.setAudio(const AudioSettings()),
      child: StatefulBuilder(builder: (context, setLocal) {
        var a = ctrl.settings.audio;
        void update(AudioSettings n, {bool record = true}) {
          a = n;
          ctrl.setAudio(n, record: record);
          setLocal(() {});
        }

        return Column(mainAxisSize: MainAxisSize.min, children: [
          EdSliderRow(
            label: 'Volume',
            value: a.volume,
            min: 0,
            max: 2,
            valueFmt: (v) => '${(v * 100).round()}%',
            trackGradient: const LinearGradient(colors: [Ed.amber1, Ed.amber2]),
            onChanged: (v) => update(a.copyWith(volume: v), record: false),
            onChangeEnd: (v) => ctrl.setAudio(a, record: true),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _bigPill('Fade In', a.fadeInMs > 0,
                  () => update(a.copyWith(fadeInMs: a.fadeInMs > 0 ? 0 : 1000))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigPill('Fade Out', a.fadeOutMs > 0,
                  () => update(a.copyWith(fadeOutMs: a.fadeOutMs > 0 ? 0 : 1000))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigPill(a.musicPath == null ? 'Add Music' : 'Music ✓', a.musicPath != null, () async {
                if (a.musicPath != null) {
                  update(a.copyWith(musicPath: null));
                  return;
                }
                final r = await FilePicker.platform.pickFiles(type: FileType.audio);
                final p = r?.files.single.path;
                if (p != null) update(a.copyWith(musicPath: p));
              }),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _pill('Noise removal', a.denoise, () => update(a.copyWith(denoise: !a.denoise))),
            const SizedBox(width: 8),
            _pill('Voice enhance', a.voiceEnhance, () => update(a.copyWith(voiceEnhance: !a.voiceEnhance))),
          ]),
          if (a.musicPath != null) ...[
            const SizedBox(height: 8),
            EdSliderRow(
              label: 'Music vol',
              value: a.musicVolume,
              min: 0,
              max: 1.5,
              valueFmt: (v) => '${(v * 100).round()}%',
              onChanged: (v) => update(a.copyWith(musicVolume: v), record: false),
              onChangeEnd: (v) => ctrl.setAudio(a, record: true),
            ),
          ],
        ]);
      }),
    ),
  );
}

// ── Transitions ─────────────────────────────────────────────────────────────
Future<void> showTransitionSheet(BuildContext context, EditorController ctrl) {
  const order = TransitionType.values;
  String label(TransitionType t) => switch (t) {
        TransitionType.none => 'None',
        TransitionType.fade => 'Fade',
        TransitionType.dissolve => 'Dissolve',
        TransitionType.wipeLeft => 'Wipe',
        TransitionType.slideUp => 'Slide',
        TransitionType.circleOpen => 'Circle',
        TransitionType.zoom => 'Zoom',
      };
  Gradient grad(TransitionType t) => LinearGradient(
        colors: [
          [const Color(0xFF3A3F45), const Color(0xFFFF3DA6), const Color(0xFF17D3F0), const Color(0xFFFFC24B),
              const Color(0xFF7C5CFF), const Color(0xFF30D158), const Color(0xFFFF6B6B)][t.index % 7],
          const Color(0xFF15171B),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  return edShowPanel(
    context,
    EdPanel(
      title: 'Transition',
      onReset: () => ctrl.setTransition(TransitionType.none),
      child: StatefulBuilder(builder: (context, setLocal) {
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: order.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final t = order[i];
                return _PresetThumb(
                  label: label(t),
                  gradient: grad(t),
                  selected: ctrl.settings.transition == t,
                  onTap: () {
                    ctrl.setTransition(t);
                    setLocal(() {});
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          EdSliderRow(
            label: 'Duration',
            value: ctrl.settings.transitionMs / 1000,
            min: 0.1,
            max: 2.0,
            valueFmt: (v) => '${v.toStringAsFixed(1)}s',
            onChanged: (_) {},
            onChangeEnd: (v) => ctrl.setTransition(ctrl.settings.transition, ms: (v * 1000).round()),
          ),
        ]);
      }),
    ),
  );
}

// ── Cutout (chroma-key) ─────────────────────────────────────────────────────
Future<void> showCutoutSheet(BuildContext context, EditorController ctrl) {
  const keys = ['#00FF00', '#0000FF', '#FF0000', '#FFFFFF', '#000000'];
  return edShowPanel(
    context,
    EdPanel(
      title: 'Cutout',
      onReset: () => ctrl.setCutout(const Cutout()),
      child: StatefulBuilder(builder: (context, setLocal) {
        var cut = ctrl.settings.cutout;
        void update(Cutout n, {bool record = true}) {
          cut = n;
          ctrl.setCutout(n, record: record);
          setLocal(() {});
        }

        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Removes a solid background colour (e.g. green screen).',
              style: TextStyle(color: Ed.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            _pill(cut.enabled ? 'Enabled' : 'Disabled', cut.enabled, () => update(cut.copyWith(enabled: !cut.enabled))),
            const Spacer(),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Key colour', style: TextStyle(color: Ed.icon, fontSize: 13)),
            const SizedBox(width: 12),
            ...keys.map((hex) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ColorDot(hex: hex, selected: cut.keyColorHex == hex, onTap: () => update(cut.copyWith(keyColorHex: hex))),
                )),
          ]),
          const SizedBox(height: 8),
          EdSliderRow(
            label: 'Similarity',
            value: cut.similarity,
            min: 0.05,
            max: 0.6,
            valueFmt: (v) => '${(v * 100).round()}%',
            onChanged: (v) => update(cut.copyWith(similarity: v), record: false),
            onChangeEnd: (v) => ctrl.setCutout(cut, record: true),
          ),
        ]);
      }),
    ),
  );
}

// ── Captions ─────────────────────────────────────────────────────────────────
Future<void> showCaptionsSheet(BuildContext context, EditorController ctrl) {
  final caps = ctrl.timeline.captions;
  return edShowPanel(
    context,
    EdPanel(
      title: 'Captions',
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: caps.isEmpty
            ? const Center(
                child: Text('No speech detected. Captions come from AI speech-to-text.',
                    textAlign: TextAlign.center, style: TextStyle(color: Ed.muted, fontSize: 13)))
            : ListView.builder(
                itemCount: caps.length,
                itemBuilder: (_, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Text('${i + 1}', style: const TextStyle(color: Ed.muted, fontSize: 12)),
                  title: Text(caps[i].text, style: const TextStyle(color: Colors.white)),
                ),
              ),
      ),
    ),
  );
}

// ── shared widgets ────────────────────────────────────────────────────────────

/// A small pill toggle (position/toggle chips).
Widget _pill(String label, bool selected, VoidCallback onTap) {
  return GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Ed.accent : Ed.barAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: selected ? Colors.black : Ed.icon, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

/// A larger equal-width pill button (Fade In / Fade Out / Music).
Widget _bigPill(String label, bool selected, VoidCallback onTap) {
  return GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Ed.accent : Ed.barAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(color: selected ? Colors.black : Ed.icon, fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}

class _PresetThumb extends StatelessWidget {
  const _PresetThumb({required this.label, required this.gradient, required this.selected, required this.onTap});
  final String label;
  final Gradient gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            width: 72,
            height: 66,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? Ed.accent : Colors.transparent, width: 2),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: selected ? Ed.accent : Ed.icon, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _AdjChip extends StatelessWidget {
  const _AdjChip({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? Ed.accent : Ed.barAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: selected ? Colors.black : Ed.icon, size: 22),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: selected ? Ed.accent : Ed.muted, fontSize: 10)),
      ]),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex, required this.selected, required this.onTap});
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _hex(hex),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Ed.accent : Colors.white24, width: selected ? 2.4 : 1),
        ),
      ),
    );
  }
}

/// An adjustment descriptor for the Adjust panel (name/icon/range/mapping).
class _Adj {
  const _Adj(this.name, this.icon, this.min, this.max, this.labels, this.get, this.set, this.disp);
  final String name;
  final IconData icon;
  final double min, max;
  final List<double> labels;
  final double Function(ColorAdjust) get;
  final ColorAdjust Function(ColorAdjust, double) set;
  final int Function(double) disp;
}
