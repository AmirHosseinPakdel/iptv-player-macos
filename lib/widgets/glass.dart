import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted-glass panel in the style of recent macOS releases.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: shape,
            color: Colors.white.withValues(alpha: dark ? 0.07 : 0.55),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.12 : 0.7),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Soft colored light behind the glass panels so the blur has something to show.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF0B0F1A), Color(0xFF151128)]
                  : const [Color(0xFFE9EEF9), Color(0xFFF4E9F5)],
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: _Orb(color: const Color(0xFF0A84FF), size: 460, dark: dark),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _Orb(color: const Color(0xFFBF5AF2), size: 520, dark: dark),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.dark});
  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: dark ? 0.35 : 0.30),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
