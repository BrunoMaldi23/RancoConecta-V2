import 'package:flutter/material.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';

class BusinessAvatar extends StatelessWidget {
  const BusinessAvatar({
    required this.businessType,
    this.imageUrl,
    this.fallbackIcon,
    this.size = 96,
    this.borderWidth = 4,
    this.showShadow = true,
    super.key,
  });

  final BusinessType businessType;
  final String? imageUrl;
  final IconData? fallbackIcon;
  final double size;
  final double borderWidth;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl?.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: borderWidth,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: .10,
                  ),
                  blurRadius: 18,
                  offset: const Offset(
                    0,
                    7,
                  ),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: resolvedUrl == null || resolvedUrl.isEmpty
            ? _BusinessAvatarFallback(
                businessType: businessType,
                icon: fallbackIcon,
              )
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const _BusinessAvatarPlaceholder();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _BusinessAvatarFallback(
                    businessType: businessType,
                    icon: fallbackIcon,
                  );
                },
              ),
      ),
    );
  }
}

class _BusinessAvatarPlaceholder extends StatelessWidget {
  const _BusinessAvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEAF4EF),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _BusinessAvatarFallback extends StatelessWidget {
  const _BusinessAvatarFallback({
    required this.businessType,
    this.icon,
  });

  final BusinessType businessType;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEAF4EF),
      child: Center(
        child: Icon(
          icon ?? businessIconForType(businessType),
          color: RancoColors.forest,
          size: 34,
        ),
      ),
    );
  }
}

IconData businessIconForType(BusinessType type) {
  return switch (type) {
    BusinessType.service => Icons.handyman_outlined,
    BusinessType.commerce => Icons.storefront_outlined,
    BusinessType.gastronomy => Icons.restaurant_outlined,
    BusinessType.lodging => Icons.bed_outlined,
    BusinessType.tourism => Icons.terrain_outlined,
    BusinessType.emergency => Icons.emergency_outlined,
  };
}
