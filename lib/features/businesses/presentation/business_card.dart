import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    final coverage = business.coverage
        .map((location) => location.name)
        .take(2)
        .join(' Ãƒâ€š\u00B7 ');

    final serviceName = business.services.isNotEmpty
        ? business.services.first.subcategory.name
        : business.type.label;

    final openNow = _isOpenNow(
      business.hours,
      DateTime.now(),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          context.go('/business/${business.id}');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD5E2DC),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ======================================================
              // HERO
              // ======================================================

              Container(
                height: 125,
                margin: const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _iconForType(business.type),
                          color: RancoColors.forest,
                          size: 29,
                        ),
                      ),
                    ),

                    // Verificado
                    if (business.isVerified)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: const _HeroBadge(
                          icon: Icons.verified_rounded,
                          label: 'Verificado',
                          foregroundColor: RancoColors.forest,
                          backgroundColor: Colors.white,
                        ),
                      ),

                    // Destacado
                    if (business.isFeatured)
                      const Positioned(
                        top: 10,
                        left: 10,
                        child: const _HeroBadge(
                          icon: Icons.star_rounded,
                          label: 'Destacado',
                          foregroundColor: Color(0xFF8A5B12),
                          backgroundColor: Color(0xFFFFF3D9),
                        ),
                      ),
                  ],
                ),
              ),

              // ======================================================
              // INFORMACIÃƒÆ’Ã¢â‚¬Å“N
              // ======================================================

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF30443B),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (business.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(
                              Icons.verified_rounded,
                              color: RancoColors.forest,
                              size: 18,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5D7168),
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // RATING + DISPONIBILIDAD
                    // ==================================================

                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (business.ratingAvg > 0)
                          _InfoBadge(
                            icon: Icons.star_rounded,
                            label:
                                '${business.ratingAvg.toStringAsFixed(1)} (${business.reviewCount})',
                            iconColor: const Color(0xFFB7791F),
                          ),
                        _AvailabilityBadge(
                          openNow: openNow,
                        ),
                      ],
                    ),

                    if (coverage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: RancoColors.forest,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              coverage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF73847C),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              context.go(
                                '/business/${business.id}',
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: RancoColors.forest,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Ver perfil',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              context.go(
                                '/business/${business.id}',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: const BorderSide(
                                color: Color(0xFFD5E2DC),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Icon(
                              Icons.favorite_border_rounded,
                              color: RancoColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOpenNow(
    List<BusinessHour> hours,
    DateTime now,
  ) {
    if (hours.isEmpty) {
      return false;
    }

    BusinessHour? today;

    for (final hour in hours) {
      if (hour.dayOfWeek == now.weekday) {
        today = hour;
        break;
      }
    }

    if (today == null ||
        today.isClosed ||
        today.openTime == null ||
        today.closeTime == null) {
      return false;
    }

    final open = _timeToMinutes(
      today.openTime!,
    );

    final close = _timeToMinutes(
      today.closeTime!,
    );

    if (open == null || close == null) {
      return false;
    }

    final current = (now.hour * 60) + now.minute;

    return current >= open && current <= close;
  }

  int? _timeToMinutes(
    String value,
  ) {
    final parts = value.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return (hour * 60) + minute;
  }

  IconData _iconForType(
    BusinessType type,
  ) {
    return switch (type) {
      BusinessType.service => Icons.handyman_outlined,
      BusinessType.commerce => Icons.storefront_outlined,
      BusinessType.gastronomy => Icons.restaurant_outlined,
      BusinessType.lodging => Icons.bed_outlined,
    };
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: foregroundColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF52645C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({
    required this.openNow,
  });

  final bool openNow;

  @override
  Widget build(BuildContext context) {
    final foreground =
        openNow ? const Color(0xFF267A55) : const Color(0xFF8C6840);

    final background =
        openNow ? const Color(0xFFE4F3EB) : const Color(0xFFF5EEE5);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            openNow ? 'Disponible ahora' : 'Fuera de horario',
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
