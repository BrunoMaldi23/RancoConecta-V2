import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/business.dart';
import '../../../core/result/result.dart';
import '../../../core/widgets/ranco_hover_surface.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../../discovery/application/business_card_data.dart';
import '../../auth/application/auth_controller.dart';
import '../../favorites/application/favorite_providers.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../provider_dashboard/data/business_media_repository.dart';
import 'business_avatar.dart';

/// home: destacados; explore: grilla comparativa (alturas reservadas para
/// alinear filas); saved: como explore pero sin alturas reservadas.
enum BusinessCardVariant { home, explore, saved }

class BusinessCard extends ConsumerWidget {
  const BusinessCard({
    required this.business,
    this.variant = BusinessCardVariant.explore,
    this.exploreData,
    this.fillHeight = false,
    super.key,
  });

  final Business business;
  final BusinessCardVariant variant;
  final BusinessCardData? exploreData;

  /// En grillas de filas con altura igualada: el CTA baja al final para
  /// quedar alineado entre tarjetas. Requiere altura acotada.
  final bool fillHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = exploreData ?? BusinessCardData.fromBusiness(business);
    final mediaRepository = ref.read(businessMediaRepositoryProvider);
    final coverPath = data.coverImagePath;
    final logoPath = data.logoImagePath;
    final favorite = ref.watch(isFavoriteProvider(business.id));

    return _BusinessCardContent(
      variant: variant,
      data: data,
      fillHeight: fillHeight,
      priceFrom: business.services.firstOrNull?.priceFrom,
      imageUrl: coverPath == null ? null : mediaRepository.publicUrl(coverPath),
      avatarUrl: data.providerAvatarUrl ??
          (logoPath == null ? null : mediaRepository.publicUrl(logoPath)),
      favorite: favorite,
      onFavoriteTap: (isFavorite) => _toggleFavorite(context, ref, isFavorite),
    );
  }

  /// Devuelve `true` si el cambio quedó confirmado; la tarjeta revierte el
  /// estado optimista en caso contrario.
  Future<bool> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go('/sign-in');
      return false;
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
      return result is Success;
    }

    return result.when(
      success: (_) {
        ref.invalidate(favoriteIdsProvider);
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
        return true;
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
        return false;
      },
    );
  }
}

class _BusinessCardContent extends StatelessWidget {
  const _BusinessCardContent({
    required this.variant,
    required this.data,
    required this.fillHeight,
    required this.priceFrom,
    required this.imageUrl,
    required this.avatarUrl,
    required this.favorite,
    required this.onFavoriteTap,
  });

  final BusinessCardVariant variant;
  final BusinessCardData data;
  final bool fillHeight;
  final int? priceFrom;
  final String? imageUrl;
  final String? avatarUrl;
  final AsyncValue<bool> favorite;
  final Future<bool> Function(bool isFavorite) onFavoriteTap;

  static final _money =
      NumberFormat.currency(locale: 'es_CL', symbol: r'$', decimalDigits: 0);

  /// Datos clave según vertical. Se muestran como máximo 3 filas para que la
  /// tarjeta no intente resumir toda la ficha.
  List<_CardDetail> _details(bool isHome) {
    final location = data.location;
    final isLodging = data.type == BusinessType.lodging;
    final isService = data.type == BusinessType.service ||
        data.type == BusinessType.emergency;
    final pricePerNight = data.lodging?.pricePerNight;
    final guests = data.lodging?.maxGuests;
    final beds = data.lodging?.beds;
    final capacity = [
      if (guests != null) '$guests ${guests == 1 ? 'huésped' : 'huéspedes'}',
      if (beds != null) '$beds ${beds == 1 ? 'cama' : 'camas'}',
    ].join(' · ');
    final hasHours = data.businessHours.isNotEmpty;
    final openNow = data.isOpenNow(DateTime.now());

    final details = <_CardDetail>[
      if (location != null && location.isNotEmpty)
        _CardDetail(Icons.location_on_outlined, location),
      if (!isHome && isService && data.coverage.isNotEmpty)
        _CardDetail(Icons.near_me_outlined, 'Cobertura: ${data.coverage}'),
      if (isLodging && pricePerNight != null)
        _CardDetail(
          Icons.payments_outlined,
          '${_money.format(pricePerNight)} / noche',
        ),
      if (!isHome && isLodging && capacity.isNotEmpty)
        _CardDetail(Icons.groups_outlined, capacity),
      if (!isHome && !isLodging && hasHours)
        _CardDetail(
          Icons.schedule_rounded,
          openNow ? 'En horario' : 'Consulta el horario',
        ),
      if (!isLodging && priceFrom != null)
        _CardDetail(
          Icons.payments_outlined,
          'Desde ${_money.format(priceFrom)}',
        ),
    ];
    return details.take(isHome ? 2 : 3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isHome = variant == BusinessCardVariant.home;
    final reserveHeights = variant == BusinessCardVariant.explore;
    final icon = _exploreIconFor(data);
    final details = _details(isHome);
    final showRating = !isHome && data.rating > 0;

    Widget fallback() => _ExploreHeroFallback(
          label: data.serviceName,
          slug: data.serviceSlug,
          icon: icon,
          type: data.type,
          logoUrl: avatarUrl,
        );

    return RancoHoverSurface(
      radius: 18,
      onTap: () => context.go('/business/${data.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl == null
                    ? fallback()
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : fallback(),
                        errorBuilder: (context, error, stackTrace) =>
                            fallback(),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _FavoriteButton(
                  favorite: favorite,
                  onTap: onFavoriteTap,
                ),
              ),
            ],
          ),
          _expandIf(
            fillHeight,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    // Dos líneas reservadas en Explorar para alinear títulos.
                    constraints:
                        BoxConstraints(minHeight: reserveHeights ? 40 : 0),
                    child: Text(
                      data.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: reserveHeights && !fillHeight ? 66 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final detail in details)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _ExploreCardDetail(
                              icon: detail.icon,
                              text: detail.text,
                            ),
                          ),
                        if (showRating)
                          _ExploreCardDetail(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFFC88A12),
                            text:
                                '${data.rating.toStringAsFixed(1)} · ${data.reviewsCount} ${data.reviewsCount == 1 ? 'reseña' : 'reseñas'}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (fillHeight) const Spacer(),
                  SizedBox(
                    height: 40,
                    child: FilledButton.tonal(
                      onPressed: () => context.go('/business/${data.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.primarySoft,
                        foregroundColor: RancoColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver detalle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _expandIf(bool expand, Widget child) =>
      expand ? Expanded(child: child) : child;
}

class _CardDetail {
  const _CardDetail(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// Corazón optimista: cambia al instante, bloquea toques repetidos mientras
/// se confirma y revierte si la operación falla.
class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.favorite, required this.onTap});

  final AsyncValue<bool> favorite;
  final Future<bool> Function(bool isFavorite) onTap;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool? _optimistic;
  bool _pending = false;

  Future<void> _toggle(bool current) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _optimistic = !current;
    });
    final confirmed = await widget.onTap(current);
    if (!mounted) return;
    setState(() {
      _pending = false;
      // Confirmado: el provider ya refleja el cambio. Fallo: se revierte.
      _optimistic = confirmed ? _optimistic : null;
    });
  }

  @override
  void didUpdateWidget(covariant _FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final server = widget.favorite.valueOrNull;
    if (!_pending && server != null && server == _optimistic) {
      _optimistic = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.favorite.isLoading && _optimistic == null;
    final isFavorite = _optimistic ?? widget.favorite.valueOrNull ?? false;
    return Material(
      color: Colors.white.withValues(alpha: .94),
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black26,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: isFavorite ? 'Quitar de guardados' : 'Guardar prestador',
          // Mientras carga el estado inicial se muestra el contorno atenuado
          // (sin spinner ni salto de layout).
          onPressed: loading ? null : () => _toggle(isFavorite),
          iconSize: 20,
          color: isFavorite ? const Color(0xFFB63C49) : RancoColors.pine,
          disabledColor: RancoColors.pine.withValues(alpha: .35),
          hoverColor: const Color(0xFFB63C49).withValues(alpha: .08),
          icon: AnimatedSwitcher(
            duration: RancoDurations.quick,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: .7, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(isFavorite),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreCardDetail extends StatelessWidget {
  const _ExploreCardDetail({
    required this.icon,
    required this.text,
    this.iconColor = RancoColors.primary,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF52655C),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreHeroFallback extends StatelessWidget {
  const _ExploreHeroFallback({
    required this.label,
    required this.slug,
    required this.icon,
    required this.type,
    this.logoUrl,
  });

  final String label;
  final String? slug;
  final IconData icon;
  final BusinessType type;

  /// Logo del negocio: se usa como marca cuando no hay fotografía de portada.
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final category = '${slug ?? ''} $label'.toLowerCase();
    final (start, end) = category.contains('electric')
        ? (const Color(0xFFFFF3D8), const Color(0xFFF4DB9F))
        : category.contains('mecan')
            ? (const Color(0xFFE8EEEE), const Color(0xFFCAD9D7))
            : category.contains('gasfit') || category.contains('plumb')
                ? (const Color(0xFFE5F2F2), const Color(0xFFC6DFDB))
                : switch (type) {
                    BusinessType.lodging => (
                        const Color(0xFFE2EFEA),
                        const Color(0xFFC7DDD5)
                      ),
                    BusinessType.gastronomy => (
                        const Color(0xFFFFF0DE),
                        const Color(0xFFF0D9BC)
                      ),
                    BusinessType.tourism => (
                        const Color(0xFFE6F2E4),
                        const Color(0xFFBDD9C5)
                      ),
                    BusinessType.emergency => (
                        const Color(0xFFFFEDE4),
                        const Color(0xFFF4D0BF)
                      ),
                    _ => (const Color(0xFFEAF3E8), const Color(0xFFD0E4D7)),
                  };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  logoUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, size: 40, color: RancoColors.forest),
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .78),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: RancoColors.primaryDark),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RancoColors.primaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _exploreIconFor(BusinessCardData data) {
  final slug = data.serviceSlug?.toLowerCase() ?? '';
  if (slug.contains('electric')) return Icons.bolt_outlined;
  if (slug.contains('mecan')) return Icons.build_outlined;
  if (slug.contains('gasfit') || slug.contains('plumb')) {
    return Icons.plumbing_outlined;
  }
  if (slug.contains('aseo') || slug.contains('clean')) {
    return Icons.cleaning_services_outlined;
  }
  if (slug.contains('jardin') || slug.contains('garden')) {
    return Icons.yard_outlined;
  }
  return businessIconForType(data.type);
}
