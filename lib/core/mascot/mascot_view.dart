import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'mascot_state.dart';

/// Renders the mascot for a given [MascotState] with a state-specific idle
/// animation (gentle bob + blink, celebration bounce, sad sway, sleeping
/// breath + Zzz). Set [animated] to false (or enable the platform
/// "disable animations" accessibility setting) for a static image — golden
/// tests rely on this.
class MascotView extends StatefulWidget {
  const MascotView({
    super.key,
    this.state = MascotState.normal,
    this.size = 120,
    this.animated = true,
  });

  final MascotState state;
  final double size;
  final bool animated;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> {
  static final _rng = Random();
  Timer? _blinkTimer;
  bool _eyesClosed = false;

  bool get _blinks => widget.animated && widget.state == MascotState.normal;

  @override
  void initState() {
    super.initState();
    if (_blinks) _scheduleBlink();
  }

  @override
  void didUpdateWidget(MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state ||
        widget.animated != oldWidget.animated) {
      _blinkTimer?.cancel();
      _eyesClosed = false;
      if (_blinks) _scheduleBlink();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload the blink frame so the first blink doesn't flicker.
    if (_blinks) precacheImage(const AssetImage(mascotClosedEyesAsset), context);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2600 + _rng.nextInt(2400)),
      () async {
        if (!mounted) return;
        setState(() => _eyesClosed = true);
        _blinkTimer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          setState(() => _eyesClosed = false);
          _scheduleBlink();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final animate =
        widget.animated && !MediaQuery.disableAnimationsOf(context);
    final asset = _eyesClosed ? mascotClosedEyesAsset : widget.state.asset;
    Widget image = Image.asset(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'Mürekkep',
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    if (animate) {
      image = switch (widget.state) {
        // Gentle idle bob.
        MascotState.normal => image
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -4, duration: 1400.ms, curve: Curves.easeInOut),
        // Energetic celebration bounce with a slight wiggle.
        MascotState.celebrating => image
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.06, duration: 420.ms, curve: Curves.easeInOut)
            .rotate(begin: -0.015, end: 0.015, duration: 840.ms, curve: Curves.easeInOut),
        // Slow, consoling sway.
        MascotState.sad => image
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.02, end: 0.02, duration: 2200.ms, curve: Curves.easeInOut)
            .moveY(begin: 0, end: 3, duration: 2200.ms, curve: Curves.easeInOut),
        // Calm breathing; Zzz added below.
        MascotState.sleeping => image
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.025, duration: 1800.ms, curve: Curves.easeInOut),
      };
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.state == MascotState.sleeping && animate
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: image),
                Positioned(
                  top: -widget.size * 0.02,
                  right: widget.size * 0.02,
                  child: _Zzz(size: widget.size),
                ),
              ],
            )
          : image,
    );
  }
}

/// Three staggered "z"s floating up next to the sleeping mascot.
class _Zzz extends StatelessWidget {
  const _Zzz({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size * 0.14,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2C3A4B),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 2; i >= 0; i--)
          Text('z', style: style)
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(delay: (i * 600).ms, duration: 500.ms)
              .moveY(begin: 4, end: -6, delay: (i * 600).ms, duration: 1300.ms)
              .fadeOut(delay: ((i * 600) + 900).ms, duration: 400.ms),
      ],
    );
  }
}
