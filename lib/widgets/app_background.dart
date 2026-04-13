import 'dart:ui';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
        ),
        // Overlay with Blur (neutral charcoal in dark mode to avoid harsh black patches)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A).withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
