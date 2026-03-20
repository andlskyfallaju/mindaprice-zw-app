import 'package:flutter/material.dart';

class AppGradient extends StatelessWidget {
  const AppGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFBC02D), // Gold/Yellow (from the reference image)
            Color(0xFF0B5D1E), // Deep Green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// Reusable decoration for other widgets if needed
  static BoxDecoration get decoration => const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFBC02D),
            Color(0xFF0B5D1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
}
