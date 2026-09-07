import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/favorites/application/favorite_providers.dart';
import '../../../features/favorites/data/favorites_repository.dart';
import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../application/business_hours.dart';
import '../application/business_providers.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({
    required this.businessId,
    super.key,
  });

  final String businessId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final business = ref.watch(
      businessDetailProvider(
        businessId,
      ),
    );

    return business.when(
      data: (business) {
        return _BusinessDetail(
          business: business,
        );
      },
      loading: () {
        return const Scaffold(
          backgroundColor: Color(0xFFEAF4F0),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        return Scaffold(
          backgroundColor: const Color(0xFFEAF4F0),
          body: SafeArea(
            child: RancoErrorState(
              message: businessFailureMessage(
                error,
              ),
              onRetry: () {
                ref.invalidate(
                  businessDetailProvider(
                    businessId,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BusinessDetail extends ConsumerWidget {
  const _BusinessDetail({
    required this.business,
  });

  final Business business;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final favorite = ref.watch(
      isFavoriteProvider(
        business.id,
      ),
    );

    final openNow = isOpenNow(
      business.hours,
      DateTime.now(),
    );

    final serviceName = business.services.isNotEmpty
        ? business.services.first.subcategory.name
        : business.type.label;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ==================================================
            // HEADER
            // ==================================================

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  10,
                ),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/explore');
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Perfil del prestador',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors.forest,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _RoundButton(
                      icon: Icons.home_outlined,
                      onTap: () {
                        context.go('/');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // HERO
            // ==================================================

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF315F50,
                    ),
                    borderRadius: BorderRadius.circular(
                      26,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            26,
                          ),
                          child: Container(
                            color: const Color(
                              0xFF315F50,
                            ),
                            child: Icon(
                              _businessIcon(
                                business.type,
                              ),
                              size: 90,
                              color: Colors.white.withValues(
                                alpha: .20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              26,
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(
                                  0xCC18392E,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    serviceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (business.isVerified) ...[
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================================
            // REPUTACIÓN / ESTADO
            // ==================================================

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  0,
                ),
                child: _BusinessStatsCard(
                  rating: business.ratingAvg,
                  reviewCount: business.reviewCount,
                  isFeatured: business.isFeatured,
                  isVerified: business.isVerified,
                  openNow: openNow,
                ),
              ),
            ),

            // ==================================================
            // ACCIONES
            // ==================================================

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  0,
                ),
                child: Row(
                  children: [
                    if (business.phone?.isNotEmpty == true)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _launchPhone(
                              business.phone!,
                            );
                          },
                          icon: const Icon(
                            Icons.call_outlined,
                          ),
                          label: const Text(
                            'Llamar',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              52,
                            ),
                            foregroundColor: RancoColors.forest,
                            side: const BorderSide(
                              color: Color(
                                0xFFD2E0D9,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (business.phone?.isNotEmpty == true &&
                        business.whatsapp?.isNotEmpty == true)
                      const SizedBox(
                        width: 10,
                      ),
                    if (business.whatsapp?.isNotEmpty == true)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            _launchWhatsApp(
                              business.whatsapp!,
                            );
                          },
                          icon: const Icon(
                            Icons.chat_outlined,
                          ),
                          label: const Text(
                            'WhatsApp',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              52,
                            ),
                            backgroundColor: RancoColors.forest,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(
                      width: 10,
                    ),
                    favorite.when(
                      data: (isFavorite) {
                        return SizedBox(
                          width: 52,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              _toggleFavorite(
                                context,
                                ref,
                                isFavorite,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: const BorderSide(
                                color: Color(
                                  0xFFD2E0D9,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  16,
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
                        width: 52,
                      ),
                      error: (_, __) => const SizedBox(
                        width: 52,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                36,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // =============================================
                    // ACERCA
                    // =============================================

                    _ProfileSection(
                      title: 'Acerca',
                      child: Text(
                        (business.description ?? '').trim().isEmpty
                            ? 'Este prestador aún no ha agregado una descripción.'
                            : business.description!,
                        style: const TextStyle(
                          color: Color(
                            0xFF61736A,
                          ),
                          height: 1.5,
                        ),
                      ),
                    ),

                    // =============================================
                    // SERVICIOS
                    // =============================================

                    _ProfileSection(
                      title: 'Servicios',
                      child: business.services.isEmpty
                          ? const Text(
                              'Este prestador aún no informa servicios especÃ­ficos.',
                              style: TextStyle(
                                color: Color(
                                  0xFF71827A,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final service in business.services)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 10,
                                    ),
                                    child: _ServiceRow(
                                      name: service.subcategory.name,
                                    ),
                                  ),
                              ],
                            ),
                    ),

                    // =============================================
                    // COBERTURA
                    // =============================================

                    _ProfileSection(
                      title: 'Cobertura',
                      child: business.coverage.isEmpty
                          ? const Text(
                              'Cobertura no informada.',
                              style: TextStyle(
                                color: Color(
                                  0xFF71827A,
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final location in business.coverage)
                                  _LocationBadge(
                                    name: location.name,
                                  ),
                              ],
                            ),
                    ),

                    // =============================================
                    // DISPONIBILIDAD
                    // =============================================

                    _ProfileSection(
                      title: 'Disponibilidad',
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: openNow
                                  ? const Color(
                                      0xFF2E8B61,
                                    )
                                  : const Color(
                                      0xFFD39A45,
                                    ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              openNow
                                  ? 'Disponible según horario'
                                  : 'Fuera del horario informado',
                              style: const TextStyle(
                                color: RancoColors.forest,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =============================================
                    // HORARIOS
                    // =============================================

                    _ProfileSection(
                      title: 'Horarios',
                      child: business.hours.isEmpty
                          ? const Text(
                              'Horarios no informados.',
                              style: TextStyle(
                                color: Color(
                                  0xFF71827A,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final hour in business.hours)
                                  _HoursRow(
                                    day: _dayLabel(
                                      hour.dayOfWeek,
                                    ),
                                    value: hour.isClosed
                                        ? 'Cerrado'
                                        : '${hour.openTime} - ${hour.closeTime}',
                                  ),
                              ],
                            ),
                    ),

                    // =============================================
                    // SOLICITAR SERVICIO
                    // =============================================

                    FilledButton.icon(
                      onPressed: () {
                        _requestService(
                          context,
                          ref,
                        );
                      },
                      icon: const Icon(
                        Icons.assignment_outlined,
                      ),
                      label: const Text(
                        'Solicitar servicio',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          54,
                        ),
                        backgroundColor: RancoColors.forest,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message,
            ),
          ),
        );
      },
    );
  }

  void _requestService(
    BuildContext context,
    WidgetRef ref,
  ) {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go('/sign-in');
      return;
    }

    context.go(
      '/business/${business.id}/request',
    );
  }

  Future<void> _launchPhone(
    String phone,
  ) async {
    final clean = phone.replaceAll(
      RegExp(r'\s+'),
      '',
    );

    await launchUrl(
      Uri(
        scheme: 'tel',
        path: clean,
      ),
    );
  }

  Future<void> _launchWhatsApp(
    String phone,
  ) async {
    var digits = phone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.startsWith('9') && digits.length == 9) {
      digits = '56$digits';
    }

    final uri = Uri.parse(
      'https://wa.me/$digits',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  static IconData _businessIcon(
    BusinessType type,
  ) {
    return switch (type) {
      BusinessType.service => Icons.handyman_outlined,
      BusinessType.commerce => Icons.storefront_outlined,
      BusinessType.gastronomy => Icons.restaurant_outlined,
      BusinessType.lodging => Icons.bed_outlined,
    };
  }

  static String _dayLabel(
    int day,
  ) {
    return switch (day) {
      1 => 'Lunes',
      2 => 'Martes',
      3 => 'Miércoles',
      4 => 'Jueves',
      5 => 'Viernes',
      6 => 'Sábado',
      7 => 'Domingo',
      _ => 'DÃ­a',
    };
  }
}

class _BusinessStatsCard extends StatelessWidget {
  const _BusinessStatsCard({
    required this.rating,
    required this.reviewCount,
    required this.isFeatured,
    required this.isVerified,
    required this.openNow,
  });

  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isVerified;
  final bool openNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD5E2DC),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (rating > 0)
            _ProfileStatusChip(
              icon: Icons.star_rounded,
              label:
                  '${rating.toStringAsFixed(1)} · $reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'}',
              foreground: const Color(0xFF8A5B12),
              background: const Color(0xFFFFF3D9),
            ),
          if (isVerified)
            const _ProfileStatusChip(
              icon: Icons.verified_rounded,
              label: 'Verificado',
              foreground: RancoColors.forest,
              background: Color(0xFFE5F1EC),
            ),
          if (isFeatured)
            const _ProfileStatusChip(
              icon: Icons.workspace_premium_rounded,
              label: 'Destacado',
              foreground: Color(0xFF8A5B12),
              background: Color(0xFFFFF3D9),
            ),
          _ProfileStatusChip(
            icon: openNow
                ? Icons.access_time_filled_rounded
                : Icons.access_time_rounded,
            label: openNow ? 'Disponible ahora' : 'Fuera de horario',
            foreground:
                openNow ? const Color(0xFF267A55) : const Color(0xFF8C6840),
            background:
                openNow ? const Color(0xFFE4F3EB) : const Color(0xFFF5EEE5),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: const Color(
                0xFFD5E2DC,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: RancoColors.forest,
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(
            0xFFD5E2DC,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF30443B),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE4F1EB,
            ),
            borderRadius: BorderRadius.circular(
              10,
            ),
          ),
          child: const Icon(
            Icons.handyman_outlined,
            color: RancoColors.forest,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 7,
            ),
            child: Text(
              name,
              style: const TextStyle(
                color: Color(
                  0xFF40534A,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE5F1EC,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: RancoColors.forest,
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.day,
    required this.value,
  });

  final String day;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: const TextStyle(
                color: Color(
                  0xFF61736A,
                ),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(
                0xFF30443B,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
