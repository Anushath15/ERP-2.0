import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/money.dart';
import 'motion.dart';
import 'tokens.dart';

// All effects here follow lib/design/motion.dart: they play AFTER the action has already happened, last 90-250 ms, use only
// opacity / translate / scale / colour (no blur, no shadows animated), and do nothing when the level does not allow them.

/// Fades and slides a child in once when it first appears (Full: effect level).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.dx = 0, this.dy = 12, this.ms = 220, this.flash = false, this.enabled = true});
  final Widget child;
  final double dx, dy;
  final int ms;
  final bool flash; // a brief highlight behind the child
  final bool enabled;
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final m = context.motion;
    final d = m.fx(widget.ms);
    if (!widget.enabled || d == Duration.zero) return;
    _c = AnimationController(vsync: this, duration: d)..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || c.isCompleted) return widget.child;
    final curved = CurvedAnimation(parent: c, curve: Motion.out);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (ctx, child) {
        final t = curved.value;
        final flash = widget.flash ? ctx.c.primary.withValues(alpha: 0.28 * (1 - t)) : Colors.transparent;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(widget.dx * (1 - t), widget.dy * (1 - t)), child: ColoredBox(color: flash, child: child)),
        );
      },
    );
  }
}

/// Scales a child down slightly while pressed (Gentle and Full). Does not take part in hit testing.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});
  final Widget child;
  final double scale;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    if (!m.transitions) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(scale: _down ? widget.scale : 1.0, duration: m.t(90), curve: Motion.out, child: widget.child),
    );
  }
}

/// Lifts a card a few pixels when the mouse is over it (Full only; desktop and web).
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child});
  final Widget child;
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _over = false;
  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    if (!m.effects) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: AnimatedSlide(offset: _over ? const Offset(0, -0.025) : Offset.zero, duration: m.fx(140), curve: Motion.out, child: widget.child),
    );
  }
}

/// Plays one small pulse (scale up then back) each time [token] changes (Full only).
class PulseOnChange extends StatefulWidget {
  const PulseOnChange({super.key, required this.token, required this.child});
  final Object? token;
  final Widget child;
  @override
  State<PulseOnChange> createState() => _PulseOnChangeState();
}

class _PulseOnChangeState extends State<PulseOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

  @override
  void didUpdateWidget(PulseOnChange old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token && context.motion.effects) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (ctx, child) => Transform.scale(scale: 1 + 0.14 * math.sin(_c.value * math.pi), child: child),
      );
}

/// A money amount that counts to its new value in under 200 ms (Full only). The real value is always current in the state;
/// this only changes how the number appears on screen.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({super.key, required this.paise, required this.style, this.prefix = '₹ ', this.textKey});
  final int paise;
  final TextStyle? style;
  final String prefix;
  final Key? textKey;
  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: paise, end: paise),
      duration: m.fx(180),
      curve: Motion.out,
      builder: (ctx, v, _) => Text('$prefix${formatPaise(v)}', key: textKey, maxLines: 1, style: style),
    );
  }
}

/// A calm error shake (one short shake). Call `key.currentState?.shake()`.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child});
  final Widget child;
  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  void shake() {
    if (context.motion.effects) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (ctx, child) => Transform.translate(offset: Offset(math.sin(_c.value * math.pi * 4) * 7 * (1 - _c.value), 0), child: child),
      );
}

/// A tiny looping pulse, only used for the sync icon WHILE syncing (not when Off).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && context.motion.transitions;
    if (run && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!run && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween<double>(begin: 1, end: 0.45).animate(_c), child: widget.child);
}

/// Shows [skeleton] ONLY when [loading] lasts longer than 150 ms; fast loads never flash a placeholder (Full only; otherwise a quiet spinner).
class DelayedLoader extends StatefulWidget {
  const DelayedLoader({super.key, required this.loading, required this.child, required this.skeleton});
  final bool loading;
  final Widget child, skeleton;
  @override
  State<DelayedLoader> createState() => _DelayedLoaderState();
}

class _DelayedLoaderState extends State<DelayedLoader> {
  bool _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(DelayedLoader old) {
    super.didUpdateWidget(old);
    if (old.loading != widget.loading) {
      _show = false;
      _arm();
    }
  }

  void _arm() {
    _t?.cancel();
    if (widget.loading) _t = Timer(const Duration(milliseconds: 150), () => mounted ? setState(() => _show = true) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) return widget.child;
    if (!_show) return const SizedBox.expand();
    return context.motion.effects ? widget.skeleton : const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)));
  }
}

/// Grey placeholder blocks with a soft moving highlight.
class SkeletonBlocks extends StatefulWidget {
  const SkeletonBlocks({super.key, this.rows = 4, this.rowHeight = 56});
  final int rows;
  final double rowHeight;
  @override
  State<SkeletonBlocks> createState() => _SkeletonBlocksState();
}

class _SkeletonBlocksState extends State<SkeletonBlocks> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.c.surfaceAlt;
    final hi = context.c.border.withValues(alpha: 0.5);
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(colors: [base, hi, base], stops: const [0.2, 0.5, 0.8], begin: Alignment(-1.5 + 3 * _c.value, 0), end: Alignment(-0.5 + 3 * _c.value, 0)).createShader(r),
        child: Column(children: [
          for (var i = 0; i < widget.rows; i++)
            Container(height: widget.rowHeight, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(Radii.m))),
        ]),
      ),
    );
  }
}

/// A check mark that pops in after a successful Save (Full only). Never blocks input: it ignores pointers.
void showSuccessCheck(BuildContext context) {
  final m = context.motion;
  if (!m.effects) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final color = context.c.success;
  final on = context.c.onSuccess;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => IgnorePointer(child: Center(child: _CheckPop(color: color, onColor: on, onDone: () => entry.remove()))));
  overlay.insert(entry);
}

class _CheckPop extends StatefulWidget {
  const _CheckPop({required this.color, required this.onColor, required this.onDone});
  final Color color, onColor;
  final VoidCallback onDone;
  @override
  State<_CheckPop> createState() => _CheckPopState();
}

class _CheckPopState extends State<_CheckPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (ctx, _) {
          final t = _c.value;
          final scale = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
          final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(width: 96, height: 96, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color), child: Icon(Icons.check_rounded, size: 64, color: widget.onColor)),
            ),
          );
        },
      );
}
