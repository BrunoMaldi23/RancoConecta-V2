import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../favorites/application/favorite_providers.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../provider_dashboard/data/business_media_repository.dart';

class BusinessCard extends ConsumerWidget {
  const BusinessCard({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final coverage = business.coverage
        .map(
          (location) => location.name,
        )
        .take(2)
        .join(' · ');

    final serviceName = business.services.isNotEmpty
        ? business.services.first.subcategory.name
        : business.type.label;

    final isLodging = business.type == BusinessType.lodging;

    final openNow = _isOpenNow(
      business.hours,
      DateTime.now(),
    );

    final favorite = ref.watch(
      isFavoriteProvider(
        business.id,
      ),
    );

    final mediaRepository = ref.read(
      businessMediaRepositoryProvider,
    );

    final coverPath = business.coverPath;

    final coverUrl = coverPath == null
        ? null
        : mediaRepository.publicUrl(
            coverPath,
          );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        22,
      ),
      child: InkWell(
        onTap: () {
          context.go(
            '/business/${business.id}',
          );
        },
        borderRadius: BorderRadius.circular(
          22,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: const Color(
                0xFFD4E1DB,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  10,
                  10,
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    18,
                  ),
                  child: SizedBox(
                    height: 145,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverUrl != null)
                          Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return _FallbackHero(
                                type: business.type,
                              );
                            },
                          ),
                        if (coverUrl == null)
                          _FallbackHero(
                            type: business.type,
                          ),
                        if (coverUrl != null)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(
                                    0x18000000,
                                  ),
                                  Color(
                                    0x55000000,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (business.isFeatured)
                          const Positioned(
                            top: 10,
                            left: 10,
                            child: _HeroBadge(
                              icon: Icons.star_rounded,
                              label: 'Destacado',
                              foregroundColor: Color(
                                0xFF895A13,
                              ),
                              backgroundColor: Color(
                                0xFFFFF1CF,
                              ),
                            ),
                          ),
                        if (business.isVerified)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: _HeroBadge(
                              icon: Icons.verified_rounded,
                              label: 'Verificado',
                              foregroundColor: RancoColors.forest,
                              backgroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(
                                0xFF2F433A,
                              ),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(
                          0xFF60736A,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (business.ratingAvg > 0)
                          _InfoBadge(
                            icon: Icons.star_rounded,
                            label:
                                '${business.ratingAvg.toStringAsFixed(1)} (${business.reviewCount})',
                            iconColor: const Color(
                              0xFFB7791F,
                            ),
                          ),
                        if (!isLodging)
                          _AvailabilityBadge(
                            openNow: openNow,
                          ),
                        if (isLodging) const _LodgingBadge(),
                      ],
                    ),
                    if (coverage.isNotEmpty) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: RancoColors.forest,
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Expanded(
                            child: Text(
                              coverage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(
                                  0xFF73847C,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(
                      height: 14,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              context.go(
                                '/business/${business.id}',
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(
                                46,
                              ),
                              backgroundColor: RancoColors.forest,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  14,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLodging ? 'Ver alojamiento' : 'Ver perfil',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(
                                  width: 7,
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        favorite.when(
                          data: (isFavorite) {
                            return SizedBox(
                              width: 48,
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _toggleFavorite(
                                    context,
                                    ref,
                                    isFavorite,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: isFavorite
                                      ? const Color(
                                          0xFFE4F1EB,
                                        )
                                      : Colors.white,
                                  side: BorderSide(
                                    color: isFavorite
                                        ? RancoColors.forest
                                        : const Color(
                                            0xFFD5E2DC,
                                          ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: RancoColors.forest,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox(
                            width: 48,
                            height: 46,
                            child: Center(
                              child: SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          error: (
                            error,
                            stackTrace,
                          ) =>
                              SizedBox(
                            width: 48,
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () async {
                                await _toggleFavorite(
                                  context,
                                  ref,
                                  false,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: const BorderSide(
                                  color: Color(
                                    0xFFD5E2DC,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                color: RancoColors.forest,
                              ),
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

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go('/sign-in');
      return;
    }

    final repository = ref.read(
      favoritesRepositoryProvider,
    );

    final result = isFavorite
        ? await repository.removeFavorite(
            business.id,
          )
        : await repository.addFavorite(
            business.id,
          );

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(
          isFavoriteProvider(
            business.id,
          ),
        );

        ref.invalidate(
          favoriteBusinessesProvider,
        );

        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            duration: const Duration(
              seconds: 2,
            ),
            content: Text(
              isFavorite ? 'Quitado de Guardados' : 'Guardado en favoritos',
            ),
          ),
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              failure.message,
            ),
          ),
        );
      },
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
}

class _FallbackHero extends StatelessWidget {
  const _FallbackHero({
    required this.type,
  });

  final BusinessType type;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ColoredBox(
      color: const Color(
        0xFFE5F1EC,
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
          child: Icon(
            switch (type) {
              BusinessType.service => Icons.handyman_outlined,
              BusinessType.commerce => Icons.storefront_outlined,
              BusinessType.gastronomy => Icons.restaurant_outlined,
              BusinessType.lodging => Icons.bed_outlined,
            },
            color: RancoColors.forest,
            size: 30,
          ),
        ),
      ),
    );
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: foregroundColor,
          ),
          const SizedBox(
            width: 4,
          ),
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF4F7F5,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(
                0xFF52645C,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LodgingBadge extends StatelessWidget {
  const _LodgingBadge();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE4F1EB,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 14,
            color: RancoColors.forest,
          ),
          SizedBox(
            width: 5,
          ),
          Text(
            'Consulta disponibilidad',
            style: TextStyle(
              color: RancoColors.forest,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
  Widget build(
    BuildContext context,
  ) {
    final foreground = openNow
        ? const Color(
            0xFF267A55,
          )
        : const Color(
            0xFF8C6840,
          );

    final background = openNow
        ? const Color(
            0xFFE4F3EB,
          )
        : const Color(
            0xFFF5EEE5,
          );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          20,
        ),
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
          const SizedBox(
            width: 5,
          ),
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
