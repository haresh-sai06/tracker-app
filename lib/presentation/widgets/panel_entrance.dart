import 'package:flutter/material.dart';

/// Fade plus a short downward slide for a list or panel.
const Duration panelEntranceDuration = Duration(milliseconds: 240);

/// Vertical travel of the entrance, in logical pixels. Never more than 8.
const double panelEntranceSlidePixels = 8;

/// Whether the panel entrance should run.
///
/// [disableAnimations] is the value of [MediaQuery.disableAnimationsOf].
/// When it is true the caller must show the child immediately and must not
/// start an animation.
bool shouldPlayPanelEntrance(bool disableAnimations) {
  return !disableAnimations;
}

/// Fades and slides [child] in, unless the platform has disabled motion.
class PanelEntrance extends StatelessWidget {
  const PanelEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!shouldPlayPanelEntrance(MediaQuery.disableAnimationsOf(context))) {
      return child;
    }
    return _PanelEntranceMotion(child: child);
  }
}

class _PanelEntranceMotion extends StatefulWidget {
  const _PanelEntranceMotion({required this.child});

  final Widget child;

  @override
  State<_PanelEntranceMotion> createState() => _PanelEntranceMotionState();
}

class _PanelEntranceMotionState extends State<_PanelEntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _slidePixels;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: panelEntranceDuration,
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = curved;
    _slidePixels = Tween<double>(
      begin: panelEntranceSlidePixels,
      end: 0,
    ).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          key: const Key('panel-entrance-opacity'),
          opacity: _opacity.value,
          child: Transform.translate(
            key: const Key('panel-entrance-slide'),
            offset: Offset(0, _slidePixels.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
