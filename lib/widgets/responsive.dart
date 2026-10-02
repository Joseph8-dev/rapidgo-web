import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class Breakpoints {
  Breakpoints._();

  static const double compact = 640;
  static const double expanded = 1100;
  static const double split = 960;

  static const double content = 1240;
  static const double readable = 760;

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compact;
  static bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= expanded;

  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < compact) return 16;
    if (w < expanded) return 28;
    return 40;
  }
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Breakpoints.content});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class ReadableSafeArea extends StatelessWidget {
  const ReadableSafeArea({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.readable,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ContentWidth(maxWidth: maxWidth, child: child));
  }
}

class ReadableBar extends StatelessWidget {
  const ReadableBar({super.key, required this.child, this.maxWidth = Breakpoints.readable});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, bool hovered) builder;
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = widget.enabled && _hovered;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        offset: hovered ? const Offset(0, -0.015) : Offset.zero,
        child: widget.builder(context, hovered),
      ),
    );
  }
}
