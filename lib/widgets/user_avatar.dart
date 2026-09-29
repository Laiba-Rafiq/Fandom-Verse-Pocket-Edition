import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.radius = 28,
    this.onDark = false,
  });

  final String initials;
  final String? imageUrl;
  final double radius;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: onDark ? Colors.white24 : colors.primaryContainer,
      foregroundColor: onDark ? Colors.white : colors.onPrimaryContainer,
      backgroundImage: hasImage
          ? NetworkImage(
              CloudinaryService.optimizedUrl(
                imageUrl!,
                width: (radius * 6).round(),
              ),
            )
          : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
