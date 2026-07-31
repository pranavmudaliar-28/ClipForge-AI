import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Twintra-matched editor palette + shared building blocks.
///
/// Scoped to the editor screens so the rest of the app keeps its own light/dark
/// design system. Colours were sampled directly from the Figma UI kit
/// (deep black surfaces, soft-cyan idle icons, bright-cyan active states).
class Ed {
  Ed._();

  static const Color bg = Color(0xFF000000); // page background
  static const Color panel = Color(0xFF121315); // tool panel surface
  static const Color bar = Color(0xFF16171B); // top bar / bottom toolbar
  static const Color barAlt = Color(0xFF252A30); // raised chips / tab track
  static const Color accent = Color(0xFF08D0F2); // bright cyan — active states
  static const Color icon = Color(0xFFA8D9F1); // soft cyan — idle icons/labels
  static const Color addBlue = Color(0xFF2E65F1); // "+" add button
  static const Color muted = Color(0xFF7D848C); // inactive tab text
  static const Color hair = Color(0x14FFFFFF); // hairline separators
  static const Color amber1 = Color(0xFFFFB918); // volume track start
  static const Color amber2 = Color(0xFFFE7206); // volume track end

  static const String fontTitle = 'SF Pro Display';

  static const TextStyle title = TextStyle(
    color: icon,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const TextStyle label = TextStyle(
    color: icon,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle value = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
}

/// Presents a Twintra tool panel as a bottom sheet that keeps the live preview
/// visible above it (transparent barrier, flat top edge, panel-coloured).
Future<T?> edShowPanel<T>(BuildContext context, Widget panel) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Ed.panel,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => panel,
  );
}

/// The standard tool-panel scaffold: a header row (close · reset · title · check)
/// over the panel body. Matches every tool sheet in the Twintra kit.
class EdPanel extends StatelessWidget {
  const EdPanel({
    super.key,
    required this.title,
    required this.child,
    this.onReset,
    this.onConfirm,
  });

  final String title;
  final Widget child;
  final VoidCallback? onReset;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Ed.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            const Divider(height: 1, thickness: 1, color: Ed.hair),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    void close() {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
    }

    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: Text(title, style: Ed.title)),
          Row(
            children: [
              _hIcon(Icons.close_rounded, close),
              Container(width: 1, height: 18, color: Ed.hair),
              _hIcon(Icons.refresh_rounded, onReset == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onReset!.call();
                    }),
              const Spacer(),
              _hIcon(Icons.check_rounded, () {
                HapticFeedback.selectionClick();
                onConfirm?.call();
                Navigator.of(context).pop();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hIcon(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: onTap == null ? Ed.muted : Ed.icon),
      splashRadius: 20,
    );
  }
}

/// A horizontally-scrolling row of text category tabs (Movies · Trending · …).
class EdTabs extends StatelessWidget {
  const EdTabs({super.key, required this.tabs, required this.index, required this.onTap});
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (_, i) {
          final active = i == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(i);
            },
            child: Center(
              child: Text(
                tabs[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Ed.accent : Ed.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A CapCut/Twintra-style tick ruler that doubles as a precise slider. Ticks
/// span [min]..[max]; labels sit under the given [labels]; a bright cyan
/// indicator marks the current value, with the formatted value floating above.
class EdTickRuler extends StatefulWidget {
  const EdTickRuler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.labels,
    required this.onChanged,
    required this.onChangeEnd,
    this.valueFmt,
    this.labelFmt,
    this.ticks = 40,
  });

  final double value;
  final double min;
  final double max;
  final List<double> labels;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final String Function(double)? valueFmt;
  final String Function(double)? labelFmt;
  final int ticks;

  @override
  State<EdTickRuler> createState() => _EdTickRulerState();
}

class _EdTickRulerState extends State<EdTickRuler> {
  late double _v = widget.value;

  @override
  void didUpdateWidget(covariant EdTickRuler old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _v = widget.value;
  }

  double _frac() => ((_v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  void _setFromDx(double dx, double w) {
    final frac = (dx / w).clamp(0.0, 1.0);
    final nv = widget.min + frac * (widget.max - widget.min);
    if (nv != _v) {
      setState(() => _v = nv);
      HapticFeedback.selectionClick();
      widget.onChanged(nv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vf = widget.valueFmt ?? (v) => v.toStringAsFixed(1);
    final lf = widget.labelFmt ?? (v) => v.toStringAsFixed(0);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final x = (_frac() * w).clamp(0.0, w);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating value label above the indicator.
          SizedBox(
            height: 24,
            width: w,
            child: Stack(children: [
              Positioned(
                left: (x - 30).clamp(0.0, w - 60),
                child: SizedBox(width: 60, child: Center(child: Text(vf(_v), style: Ed.value))),
              ),
            ]),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _setFromDx(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _setFromDx(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => widget.onChangeEnd(_v),
            onTapUp: (_) => widget.onChangeEnd(_v),
            child: SizedBox(
              height: 40,
              width: w,
              child: CustomPaint(
                painter: _RulerPainter(
                  frac: _frac(),
                  ticks: widget.ticks,
                ),
              ),
            ),
          ),
          // Label row under major ticks.
          SizedBox(
            height: 16,
            width: w,
            child: Stack(
              children: widget.labels.map((lv) {
                final lx = (((lv - widget.min) / (widget.max - widget.min)) * w).clamp(0.0, w);
                return Positioned(
                  left: (lx - 20).clamp(0.0, w - 40),
                  child: SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(lf(lv), style: const TextStyle(color: Ed.muted, fontSize: 11)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.frac, required this.ticks});
  final double frac;
  final int ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final tick = Paint()
      ..color = const Color(0xFF3A4048)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final cy = size.height / 2;
    for (var i = 0; i <= ticks; i++) {
      final x = size.width * i / ticks;
      final major = i % 5 == 0;
      final h = major ? 16.0 : 9.0;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), tick);
    }
    // Bright indicator.
    final ix = (size.width * frac).clamp(0.0, size.width);
    final ind = Paint()
      ..color = Ed.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ix, cy - 13), Offset(ix, cy + 13), ind);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => old.frac != frac || old.ticks != ticks;
}

/// A labelled slider row styled for the dark editor panels.
class EdSliderRow extends StatelessWidget {
  const EdSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.trackGradient,
    this.valueFmt,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Gradient? trackGradient;
  final String Function(double)? valueFmt;

  @override
  Widget build(BuildContext context) {
    final fmt = valueFmt ?? (v) => v.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 84, child: Text(label, style: const TextStyle(color: Ed.icon, fontSize: 13))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: Ed.accent,
              inactiveTrackColor: Ed.barAlt,
              thumbColor: Colors.white,
              overlayColor: Ed.accent.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackShape: trackGradient == null ? null : _GradientTrackShape(trackGradient!),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(fmt(value), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// Paints a gradient active track (used by the amber Volume slider).
class _GradientTrackShape extends RoundedRectSliderTrackShape {
  const _GradientTrackShape(this.gradient);
  final Gradient gradient;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);
    // Inactive full track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = sliderTheme.inactiveTrackColor ?? Ed.barAlt,
    );
    // Active gradient up to the thumb.
    final active = Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(active, radius),
      Paint()..shader = gradient.createShader(rect),
    );
  }
}
