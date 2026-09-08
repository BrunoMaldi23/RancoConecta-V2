import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../favorites/application/favorite_providers.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../../provider_dashboard/data/business_media_repository.dart';
import '../../reviews/presentation/reviews_section.dart';

class LodgingPublicProfile extends ConsumerWidget {
  const LodgingPublicProfile({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final details = ref.watch(
      lodgingDetailsProvider(
        business.id,
      ),
    );

    final favorite = ref.watch(
      isFavoriteProvider(
        business.id,
      ),
    );

    final mediaRepository = ref.read(
      businessMediaRepositoryProvider,
    );

    final cover = _coverMedia();

    final coverUrl = cover == null
        ? null
        : mediaRepository.publicUrl(
            cover.storagePath,
          );

    final gallery = business.media
        .where(
          (item) => item.type != 'cover',
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(
        0xFFEAF4F0,
      ),
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
                          return;
                        }

                        context.go('/explore');
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Alojamiento',
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    26,
                  ),
                  child: SizedBox(
                    height: 270,
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
                              return const ColoredBox(
                                color: Color(
                                  0xFF315F50,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.holiday_village_outlined,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                                ),
                              );
                            },
                          ),
                        if (coverUrl == null)
                          const ColoredBox(
                            color: Color(
                              0xFF315F50,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.holiday_village_outlined,
                                size: 80,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(
                                  0xDD173A2E,
                                ),
                              ],
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              Row(
                                children: [
                                  const Text(
                                    'Alojamiento',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
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
            ),

            // ==================================================
            // BADGES
            // ==================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(
                    13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: const Color(
                        0xFFD5E2DC,
                      ),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (business.ratingAvg > 0)
                        _StatusChip(
                          icon: Icons.star_rounded,
                          label:
                              '${business.ratingAvg.toStringAsFixed(1)} (${business.reviewCount})',
                          foreground: const Color(
                            0xFF8A5B12,
                          ),
                          background: const Color(
                            0xFFFFF3D9,
                          ),
                        ),
                      if (business.isVerified)
                        const _StatusChip(
                          icon: Icons.verified_rounded,
                          label: 'Verificado',
                          foreground: RancoColors.forest,
                          background: Color(
                            0xFFE5F1EC,
                          ),
                        ),
                      if (business.isFeatured)
                        const _StatusChip(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Destacado',
                          foreground: Color(
                            0xFF8A5B12,
                          ),
                          background: Color(
                            0xFFFFF3D9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================================
            // CONTACTO
            // ==================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  0,
                ),
                child: Row(
                  children: [
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
                            backgroundColor: RancoColors.forest,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(
                              52,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (business.whatsapp?.isNotEmpty == true)
                      const SizedBox(
                        width: 10,
                      ),
                    favorite.when(
                      data: (isFavorite) {
                        return SizedBox(
                          width: 54,
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
                        width: 54,
                      ),
                      error: (
                        error,
                        stackTrace,
                      ) =>
                          const SizedBox(
                        width: 54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // CONTENIDO
            // ==================================================
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
                    // --------------------------------------------------
                    // TARIFA + CARACTERISTICAS
                    // --------------------------------------------------
                    details.when(
                      data: (lodging) {
                        return Column(
                          children: [
                            _ProfileSection(
                              title: 'Tu estadia',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_money(lodging.pricePerNight)} / noche',
                                    style: const TextStyle(
                                      color: RancoColors.forest,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 16,
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _FeatureChip(
                                        icon: Icons.people_outline,
                                        label: '${lodging.maxGuests} huespedes',
                                      ),
                                      _FeatureChip(
                                        icon: Icons.bedroom_parent_outlined,
                                        label:
                                            '${lodging.bedrooms} dormitorios',
                                      ),
                                      _FeatureChip(
                                        icon: Icons.bed_outlined,
                                        label: '${lodging.beds} camas',
                                      ),
                                      _FeatureChip(
                                        icon: Icons.bathtub_outlined,
                                        label:
                                            '${_bathroomLabel(lodging.bathrooms)} banos',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _ProfileSection(
                              title: 'Ingreso y salida',
                              child: Column(
                                children: [
                                  _InfoRow(
                                    icon: Icons.login_rounded,
                                    label: 'Check-in',
                                    value: lodging.checkInTime,
                                  ),
                                  const Divider(),
                                  _InfoRow(
                                    icon: Icons.logout_rounded,
                                    label: 'Check-out',
                                    value: lodging.checkOutTime,
                                  ),
                                  const Divider(),
                                  _InfoRow(
                                    icon: Icons.nights_stay_outlined,
                                    label: 'Estadia minima',
                                    value:
                                        '${lodging.minNights} ${lodging.minNights == 1 ? 'noche' : 'noches'}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const _LoadingCard(),
                      error: (
                        error,
                        stackTrace,
                      ) =>
                          const SizedBox.shrink(),
                    ),

                    // --------------------------------------------------
                    // ACERCA
                    // --------------------------------------------------
                    _ProfileSection(
                      title: 'Acerca del alojamiento',
                      child: Text(
                        (business.description ?? '').trim().isEmpty
                            ? 'El alojamiento aun no ha agregado una descripcion.'
                            : business.description!,
                        style: const TextStyle(
                          color: Color(
                            0xFF61736A,
                          ),
                          height: 1.5,
                        ),
                      ),
                    ),

                    // --------------------------------------------------
                    // GALERIA
                    // --------------------------------------------------
                    if (gallery.isNotEmpty)
                      _ProfileSection(
                        title: 'Fotografias',
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: gallery.length > 6 ? 6 : gallery.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final item = gallery[index];

                            final url = mediaRepository.publicUrl(
                              item.storagePath,
                            );

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(
                                14,
                              ),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const ColoredBox(
                                    color: Color(
                                      0xFFE4F1EB,
                                    ),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),

                    // --------------------------------------------------
                    // UBICACION
                    // --------------------------------------------------
                    _ProfileSection(
                      title: 'Ubicacion',
                      child: business.coverage.isEmpty
                          ? const Text(
                              'Ubicacion no informada.',
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

                    // --------------------------------------------------
                    // POLITICAS
                    // --------------------------------------------------
                    details.when(
                      data: (lodging) {
                        if (lodging.cancellationPolicy.trim().isEmpty &&
                            lodging.houseRules.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _ProfileSection(
                          title: 'Reglas y politicas',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lodging.cancellationPolicy
                                  .trim()
                                  .isNotEmpty) ...[
                                const Text(
                                  'Cancelacion',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  lodging.cancellationPolicy,
                                  style: const TextStyle(
                                    color: Color(
                                      0xFF61736A,
                                    ),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (lodging.cancellationPolicy
                                      .trim()
                                      .isNotEmpty &&
                                  lodging.houseRules.trim().isNotEmpty)
                                const SizedBox(
                                  height: 16,
                                ),
                              if (lodging.houseRules.trim().isNotEmpty) ...[
                                const Text(
                                  'Reglas del alojamiento',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  lodging.houseRules,
                                  style: const TextStyle(
                                    color: Color(
                                      0xFF61736A,
                                    ),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (
                        error,
                        stackTrace,
                      ) =>
                          const SizedBox.shrink(),
                    ),

                    ReviewsSection(
                      businessId: business.id,
                      ratingAvg: business.ratingAvg,
                      reviewCount: business.reviewCount,
                    ),

                    // --------------------------------------------------
                    // DISPONIBILIDAD
                    // --------------------------------------------------
                    FilledButton.icon(
                      onPressed: () {
                        context.go(
                          '/business/${business.id}/availability',
                        );
                      },
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                      ),
                      label: const Text(
                        'Ver disponibilidad',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(
                          56,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            17,
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

  BusinessMedia? _coverMedia() {
    for (final item in business.media) {
      if (item.type == 'cover') {
        return item;
      }
    }

    if (business.media.isNotEmpty) {
      return business.media.first;
    }

    return null;
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

        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
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

  static String _money(
    int amount,
  ) {
    final value = amount.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      final remaining = value.length - index;

      buffer.write(
        value[index],
      );

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$${buffer.toString()}';
  }

  static String _bathroomLabel(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(
      1,
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
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: SizedBox(
          width: 46,
          height: 46,
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
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
              color: Color(
                0xFF30443B,
              ),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
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
          Icon(
            icon,
            size: 16,
            color: foreground,
          ),
          const SizedBox(
            width: 5,
          ),
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

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE6F2EC,
        ),
        borderRadius: BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: RancoColors.forest,
          ),
          const SizedBox(
            width: 6,
          ),
          Text(
            label,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: RancoColors.forest,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              label,
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({
    required this.name,
  });

  final String name;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE5F1EC,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: RancoColors.forest,
            size: 15,
          ),
          const SizedBox(
            width: 4,
          ),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
