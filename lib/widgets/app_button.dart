import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool outlined;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null || isLoading;
    final VoidCallback? tapHandler = isLoading ? null : onPressed;

    final Color contentColor;
    if (!enabled) {
      contentColor = colors.outline;
    } else if (outlined) {
      contentColor = AppColors.pink;
    } else {
      contentColor = Colors.white;
    }

    final Widget content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: contentColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: contentColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: contentColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          );

    final Widget tapArea = InkWell(
      onTap: tapHandler,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: content,
          ),
        ),
      ),
    );

    if (outlined) {
      return Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: enabled ? AppColors.pink : colors.outlineVariant,
              width: 1.6,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: tapArea,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.buttonGradient : null,
          color: enabled ? null : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(_height / 2),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x40F0357A),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: tapArea,
        ),
      ),
    );
  }
}
