import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.showText = true,
    this.onDark = false,
  });

  final double size;
  final bool showText;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleColor = onDark ? Colors.white : colors.onSurface;
    final subtitleColor = onDark ? Colors.white70 : colors.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.3),
            border: onDark ? Border.all(color: Colors.white54, width: 2) : null,
          ),
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'Fandom Verse',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'Pocket Edition · Fandom Trivia on the Go',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: subtitleColor),
          ),
        ],
      ],
    );
  }
}
