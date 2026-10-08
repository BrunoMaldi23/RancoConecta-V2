import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/favorites/application/favorite_providers.dart';
import '../../../features/favorites/data/favorites_repository.dart';
import '../../../features/gastronomy/application/gastronomy_providers.dart';
import '../../../features/gastronomy/data/gastronomy_repository.dart'
    as gastronomy;
import '../../../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../../../features/provider_dashboard/data/business_media_repository.dart';
import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../reviews/presentation/reviews_section.dart';
import '../application/business_profile_presenter.dart';
import '../../../core/telemetry/telemetry.dart';
import '../application/business_providers.dart';
import '../data/business_analytics_repository.dart';
import 'business_avatar.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({
    required this.businessId,
    super.key,
  });

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessDetailProvider(businessId));

    return business.when(
      data: (business) => BusinessPublicProfile(business: business),
      loading: () => const _BusinessDetailSkeleton(),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: const Color(0xFFEAF4F0),
        body: SafeArea(
          child: RancoErrorState(
            message: 'No pudimos cargar este negocio.',
            onRetry: () {
              ref.invalidate(businessDetailProvider(businessId));
            },
          ),
        ),
      ),
    );
  }
}

class BusinessPublicProfile extends ConsumerStatefulWidget {
  const BusinessPublicProfile({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  ConsumerState<BusinessPublicProfile> createState() =>
      _BusinessPublicProfileState();
}

class _BusinessPublicProfileState extends ConsumerState<BusinessPublicProfile> {
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    Telemetry.capture('view_business');
    Future.microtask(() {
      if (mounted) {
        unawaited(ref
            .read(businessAnalyticsRepositoryProvider)
            .track(business.id, 'PROFILE_VIEW'));
      }
    });
  }

  Business get business => widget.business;

  @override
  Widget build(BuildContext context) {
    final presentation = businessProfilePresentation(business);

    final favorite = ref.watch(
      isFavoriteProvider(business.id),
    );

    final mediaRepository = ref.read(
      businessMediaRepositoryProvider,
    );

    final media = _profileMedia(
      mediaRepository,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;

    final desktop = screenWidth >= 980;

    final desktopSections = presentation.sections
        .where(
          (section) => section != BusinessProfileSection.lodgingDetails,
        )
        .toList();

    void goBack() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }

      context.go('/explore');
    }

    final onFavorite = favorite.hasValue
        ? () => _toggleFavorite(
              favorite.valueOrNull ?? false,
            )
        : null;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F7F5,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            if (!desktop)
              SliverToBoxAdapter(
                child: _ProfileAppBar(
                  title: business.type.label,
                  favorite: favorite.valueOrNull,
                  favoriteBusy: _favoriteBusy,
                  onBack: goBack,
                  onFavorite: onFavorite,
                ),
              ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1180,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 22 : 16,
                      desktop ? 18 : 0,
                      desktop ? 22 : 16,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BusinessHero(
                          business: business,
                          subtitle: presentation.subtitle,
                          media: media,
                          showAvailable: presentation.showAvailableBadge,
                          showOverlayActions: desktop,
                          favorite: favorite.valueOrNull,
                          favoriteBusy: _favoriteBusy,
                          onBack: goBack,
                          onFavorite: onFavorite,
                        ),
                        if (!desktop) ...[
                          const SizedBox(
                            height: 12,
                          ),
                          _BadgeRail(
                            business: business,
                            showAvailable: presentation.showAvailableBadge,
                          ),
                        ],
                        SizedBox(
                          height: desktop ? 20 : 14,
                        ),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _MainSections(
                                  business: business,
                                  sections: desktopSections,
                                  media: media.gallery,
                                ),
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              SizedBox(
                                width: 354,
                                child: _SidePanel(
                                  business: business,
                                  showRequestCta: presentation.showRequestCta,
                                  favorite: favorite,
                                  favoriteBusy: _favoriteBusy,
                                  onFavorite: _toggleFavorite,
                                  onRequest: _requestService,
                                  onTableReservation: _reserveTable,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _ActionBar(
                            business: business,
                            showRequestCta: presentation.showRequestCta,
                            favorite: favorite,
                            favoriteBusy: _favoriteBusy,
                            onFavorite: _toggleFavorite,
                            onRequest: _requestService,
                            onTableReservation: _reserveTable,
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          _MainSections(
                            business: business,
                            sections: presentation.sections,
                            media: media.gallery,
                          ),
                          if (presentation.showRequestCta) ...[
                            const SizedBox(
                              height: 2,
                            ),
                            _FinalRequestCta(
                              label: _primaryCtaLabel(
                                business.type,
                              ),
                              onPressed: _requestService,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ProfileMedia _profileMedia(BusinessMediaRepository repository) {
    String? urlFor(BusinessMedia media) {
      try {
        return repository.publicUrl(media.storagePath);
      } catch (_) {
        return null;
      }
    }

    final cover = business.coverPath == null
        ? null
        : business.media
            .where((item) => item.storagePath == business.coverPath)
            .firstOrNull;

    final logo = business.logoPath == null
        ? null
        : business.media
            .where((item) => item.storagePath == business.logoPath)
            .firstOrNull;

    final gallery = <_ProfilePhoto>[];
    final seen = <String>{};

    for (final item in business.media) {
      if (item.type == 'logo') {
        continue;
      }

      if (!seen.add(item.storagePath)) {
        continue;
      }

      final url = urlFor(item);
      if (url == null) {
        continue;
      }

      gallery.add(_ProfilePhoto(url: url, type: item.type));
    }

    return _ProfileMedia(
      coverUrl: cover == null ? null : urlFor(cover),
      logoUrl: logo == null ? null : urlFor(logo),
      gallery: gallery,
    );
  }

  Future<void> _toggleFavorite(bool isFavorite) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go(
        Uri(
          path: '/sign-in',
          queryParameters: {'next': '/business/${business.id}'},
        ).toString(),
      );
      return;
    }

    setState(() {
      _favoriteBusy = true;
    });

    final repository = ref.read(favoritesRepositoryProvider);
    final result = isFavorite
        ? await repository.removeFavorite(business.id)
        : await repository.addFavorite(business.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteBusy = false;
    });

    result.when(
      success: (_) {
        if (!isFavorite) {
          unawaited(ref
              .read(businessAnalyticsRepositoryProvider)
              .track(business.id, 'SAVE_BUSINESS'));
        }
        ref.invalidate(isFavoriteProvider(business.id));
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoriteBusinessesProvider);
        _showSnack(
          isFavorite ? 'Quitado de Guardados' : 'Guardado en favoritos',
          isFavorite ? Icons.favorite_border_rounded : Icons.favorite_rounded,
        );
      },
      failure: (failure) {
        _showSnack(failure.message, Icons.error_outline_rounded);
      },
    );
  }

  void _requestService() {
    unawaited(ref
        .read(businessAnalyticsRepositoryProvider)
        .track(business.id, 'REQUEST_CONTACT'));
    final next = '/business/${business.id}/request';
    context.go(next);
  }

  void _reserveTable() {
    final next = '/business/${business.id}/table-reservation';
    context.go(next);
  }

  void _showSnack(String message, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF234B3D),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.title,
    required this.favorite,
    required this.favoriteBusy,
    required this.onBack,
    required this.onFavorite,
  });

  final String title;
  final bool? favorite;
  final bool favoriteBusy;
  final VoidCallback onBack;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              _IconAction(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Volver',
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.forest,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _IconAction(
                icon: favorite == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                tooltip: favorite == true
                    ? 'Quitar de guardados'
                    : 'Guardar negocio',
                busy: favoriteBusy,
                onPressed: onFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessHero extends StatelessWidget {
  const _BusinessHero({
    required this.business,
    required this.subtitle,
    required this.media,
    required this.showAvailable,
    required this.showOverlayActions,
    required this.favorite,
    required this.favoriteBusy,
    required this.onBack,
    required this.onFavorite,
  });

  final Business business;
  final String subtitle;
  final _ProfileMedia media;

  final bool showAvailable;
  final bool showOverlayActions;

  final bool? favorite;
  final bool favoriteBusy;

  final VoidCallback onBack;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final desktop = width >= 980;

    final height = desktop ? 405.0 : 246.0;

    final now = DateTime.now();

    final openNow = businessIsAvailableNow(
      business,
      now,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        desktop ? 26 : 22,
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media.coverUrl != null)
              Image.network(
                media.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _HeroFallback(
                    type: business.type,
                  );
                },
              )
            else
              _HeroFallback(
                type: business.type,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [
                    0,
                    .42,
                    1,
                  ],
                  colors: [
                    Color(
                      0x18000000,
                    ),
                    Color(
                      0x33000000,
                    ),
                    Color(
                      0xE3193B30,
                    ),
                  ],
                ),
              ),
            ),
            if (showOverlayActions)
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: Row(
                  children: [
                    _HeroActionButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Volver',
                      onPressed: onBack,
                    ),
                    const Spacer(),
                    _HeroActionButton(
                      icon: favorite == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: favorite == true ? 'Guardado' : 'Guardar',
                      busy: favoriteBusy,
                      onPressed: onFavorite,
                    ),
                  ],
                ),
              ),
            Positioned(
              left: desktop ? 26 : 18,
              right: desktop ? 26 : 18,
              bottom: desktop ? 26 : 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (media.logoUrl != null) ...[
                    BusinessAvatar(
                      businessType: business.type,
                      imageUrl: media.logoUrl,
                      size: desktop ? 80 : 64,
                      borderWidth: 3,
                    ),
                    SizedBox(
                      width: desktop ? 16 : 12,
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: desktop ? 34 : 25,
                                  fontWeight: FontWeight.w900,
                                  height: 1.02,
                                  letterSpacing: -.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 7,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(
                              0xFFE5F1EC,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (desktop) ...[
                          const SizedBox(
                            height: 12,
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              if (business.reviewCount > 0)
                                _HeroStatusChip(
                                  icon: Icons.star_rounded,
                                  label:
                                      '${business.ratingAvg.toStringAsFixed(1)} · ${business.reviewCount} ${business.reviewCount == 1 ? 'opinión' : 'opiniones'}',
                                ),
                              if (business.isFeatured)
                                const _HeroStatusChip(
                                  icon: Icons.workspace_premium_rounded,
                                  label: 'Destacado',
                                ),
                              if (business.primaryLocation != null)
                                _HeroStatusChip(
                                  icon: Icons.location_on_outlined,
                                  label: business.primaryLocation!.name,
                                ),
                              if (showAvailable)
                                _HeroStatusChip(
                                  icon: openNow
                                      ? Icons.access_time_filled_rounded
                                      : Icons.access_time_rounded,
                                  label: _availabilityLabel(
                                    business,
                                    now,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: .94,
      ),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 19,
                  color: RancoColors.forest,
                ),
              const SizedBox(
                width: 7,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  const _HeroStatusChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: .91,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: RancoColors.forest,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: const TextStyle(
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

class _BadgeRail extends StatelessWidget {
  const _BadgeRail({
    required this.business,
    required this.showAvailable,
  });

  final Business business;
  final bool showAvailable;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final openNow = businessIsAvailableNow(business, now);
    final chips = <Widget>[
      if (business.reviewCount > 0)
        _StatusChip(
          icon: Icons.star_rounded,
          label:
              '${business.ratingAvg.toStringAsFixed(1)} · ${business.reviewCount} ${business.reviewCount == 1 ? 'reseña' : 'reseñas'}',
          foreground: const Color(0xFF8A5B12),
          background: const Color(0xFFFFF4D8),
        ),
      if (business.isFeatured)
        const _StatusChip(
          icon: Icons.workspace_premium_rounded,
          label: 'Destacado',
          foreground: Color(0xFF895A13),
          background: Color(0xFFFFF1CF),
        ),
      if (showAvailable)
        _StatusChip(
          icon: openNow
              ? Icons.access_time_filled_rounded
              : Icons.access_time_rounded,
          label: _availabilityLabel(business, now),
          foreground:
              openNow ? const Color(0xFF267A55) : const Color(0xFF8C6840),
          background:
              openNow ? const Color(0xFFE4F3EB) : const Color(0xFFF5EEE5),
        ),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.business,
    required this.showRequestCta,
    required this.favorite,
    required this.favoriteBusy,
    required this.onFavorite,
    required this.onRequest,
    required this.onTableReservation,
  });

  final Business business;
  final bool showRequestCta;
  final AsyncValue<bool> favorite;
  final bool favoriteBusy;
  final ValueChanged<bool> onFavorite;
  final VoidCallback onRequest;
  final VoidCallback onTableReservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showRequestCta)
            _PrimaryActionButton(
              label: _primaryCtaLabel(business.type),
              icon: Icons.assignment_outlined,
              onPressed: onRequest,
            ),
          if (business.type == BusinessType.gastronomy)
            _PrimaryActionButton(
              label: 'Reservar mesa',
              icon: Icons.event_seat_outlined,
              onPressed: onTableReservation,
            ),
          if (_hasText(business.addressText))
            _DirectionsButton(
              address: business.addressText!.trim(),
              locationName: business.primaryLocation?.name,
            ),
          ..._contactActions(business,
              onEvent: (event) => unawaited(
                    ref
                        .read(businessAnalyticsRepositoryProvider)
                        .track(business.id, event),
                  )),
          _FavoriteButton(
            favorite: favorite.valueOrNull ?? false,
            busy: favoriteBusy || favorite.isLoading,
            onPressed: favorite.hasValue
                ? () => onFavorite(favorite.valueOrNull ?? false)
                : null,
          ),
        ],
      ),
    );
  }
}

class _SidePanel extends ConsumerWidget {
  const _SidePanel({
    required this.business,
    required this.showRequestCta,
    required this.favorite,
    required this.favoriteBusy,
    required this.onFavorite,
    required this.onRequest,
    required this.onTableReservation,
  });

  final Business business;
  final bool showRequestCta;
  final AsyncValue<bool> favorite;
  final bool favoriteBusy;
  final ValueChanged<bool> onFavorite;
  final VoidCallback onRequest;
  final VoidCallback onTableReservation;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    void track(String event) => unawaited(
          ref
              .read(businessAnalyticsRepositoryProvider)
              .track(business.id, event),
        );
    final hasWhatsApp = _hasText(business.whatsapp);
    final tertiary = <Widget>[
      if (_hasText(business.phone))
        _ContactAction(
          icon: Icons.call_outlined,
          label: 'Llamar',
          fullWidth: true,
          height: 40,
          onPressed: () {
            track('CLICK_PHONE');
            _launchPhone(business.phone!);
          },
        ),
      if (_hasText(business.email))
        _ContactAction(
          icon: Icons.mail_outline_rounded,
          label: 'Correo',
          fullWidth: true,
          height: 40,
          onPressed: () => _launchEmail(business.email!),
        ),
      if (_hasText(business.website))
        _ContactAction(
          icon: Icons.language_rounded,
          label: 'Sitio web',
          fullWidth: true,
          height: 40,
          onPressed: () => _launchUri(business.website!),
        ),
      if (_hasText(business.addressText))
        _ContactAction(
          icon: Icons.directions_outlined,
          label: 'Cómo llegar',
          fullWidth: true,
          height: 40,
          onPressed: () => _launchDirections(
            business.addressText!.trim(),
            business.primaryLocation?.name,
          ),
        ),
      _FavoriteButton(
        favorite: favorite.valueOrNull ?? false,
        busy: favoriteBusy || favorite.isLoading,
        onPressed: favorite.hasValue
            ? () => onFavorite(
                  favorite.valueOrNull ?? false,
                )
            : null,
        fullWidth: true,
        height: 40,
      ),
    ];

    final lodging = business.type == BusinessType.lodging
        ? ref.watch(
            lodgingDetailsProvider(
              business.id,
            ),
          )
        : null;

    return _SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lodging != null)
            lodging.when(
              data: (details) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Reserva tu estad\u00eda',
                      style: TextStyle(
                        color: Color(
                          0xFF30443B,
                        ),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    if (details.pricePerNight > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money(
                              details.pricePerNight,
                            ),
                            style: const TextStyle(
                              color: RancoColors.forest,
                              fontSize: 26,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(
                              bottom: 2,
                            ),
                            child: Text(
                              '/ noche',
                              style: TextStyle(
                                color: Color(
                                  0xFF6C7C74,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(
                      height: 17,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SideFact(
                          icon: Icons.groups_outlined,
                          value: '${details.maxGuests}',
                          label: 'Huéspedes',
                        ),
                        _SideFact(
                          icon: Icons.king_bed_outlined,
                          value: '${details.beds}',
                          label: 'Camas',
                        ),
                        _SideFact(
                          icon: Icons.bedroom_parent_outlined,
                          value: '${details.bedrooms}',
                          label: 'Dorm.',
                        ),
                        _SideFact(
                          icon: Icons.bathtub_outlined,
                          value: details.bathrooms.toStringAsFixed(
                            0,
                          ),
                          label: 'Baños',
                        ),
                      ],
                    ),
                    if (details.checkInTime.isNotEmpty ||
                        details.checkOutTime.isNotEmpty) ...[
                      const SizedBox(
                        height: 15,
                      ),
                      Container(
                        padding: const EdgeInsets.all(
                          12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF2F7F4,
                          ),
                          borderRadius: BorderRadius.circular(
                            13,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: RancoColors.forest,
                            ),
                            const SizedBox(
                              width: 9,
                            ),
                            Expanded(
                              child: Text(
                                [
                                  if (details.checkInTime.isNotEmpty)
                                    'Check-in ${details.checkInTime}',
                                  if (details.checkOutTime.isNotEmpty)
                                    'Check-out ${details.checkOutTime}',
                                ].join(
                                  '  ·  ',
                                ),
                                style: const TextStyle(
                                  color: Color(
                                    0xFF53675E,
                                  ),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 16,
                    ),
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
                        'Consultar disponibilidad',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          52,
                        ),
                        backgroundColor: RancoColors.forest,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Divider(
                      height: 1,
                      color: Color(
                        0xFFE4EBE7,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],
                );
              },
              loading: () {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              error: (
                error,
                stackTrace,
              ) {
                return const SizedBox.shrink();
              },
            )
          else if (showRequestCta) ...[
            const Text(
              'Contactar negocio',
              style: TextStyle(
                color: Color(
                  0xFF30443B,
                ),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _PrimaryActionButton(
              label: _primaryCtaLabel(
                business.type,
              ),
              icon: Icons.assignment_outlined,
              onPressed: onRequest,
              fullWidth: true,
            ),
            const SizedBox(
              height: 16,
            ),
            const Divider(
              height: 1,
              color: Color(
                0xFFE4EBE7,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
          ] else if (business.type == BusinessType.gastronomy) ...[
            const Text(
              'Reservar mesa',
              style: TextStyle(
                color: Color(
                  0xFF30443B,
                ),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _PrimaryActionButton(
              label: 'Solicitar reserva',
              icon: Icons.event_seat_outlined,
              onPressed: onTableReservation,
              fullWidth: true,
            ),
            const SizedBox(
              height: 16,
            ),
            const Divider(
              height: 1,
              color: Color(
                0xFFE4EBE7,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
          ],
          if (business.primaryLocation != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: RancoColors.forest,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    business.primaryLocation!.name,
                    style: const TextStyle(
                      color: Color(
                        0xFF30443B,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
          ],
          if (hasWhatsApp) ...[
            FilledButton.tonalIcon(
              onPressed: () {
                track('CLICK_WHATSAPP');
                _launchWhatsApp(business.whatsapp!);
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: RancoColors.primarySoft,
                foregroundColor: RancoColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          LayoutBuilder(builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in tertiary)
                  SizedBox(width: itemWidth, child: action),
              ],
            );
          }),
          if (business.type == BusinessType.commerce) ...[
            const SizedBox(
              height: 18,
            ),
            _CommerceInfoBlock(
              business: business,
            ),
          ],
        ],
      ),
    );
  }
}

class _SideFact extends StatelessWidget {
  const _SideFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF2F7F4,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(
            0xFFE1EBE6,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE2F0E8,
              ),
              borderRadius: BorderRadius.circular(
                9,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: RancoColors.forest,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: RancoColors.forest,
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(
                      0xFF728179,
                    ),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommerceInfoBlock extends StatelessWidget {
  const _CommerceInfoBlock({
    required this.business,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoLine(icon: Icons.storefront_outlined, label: business.type.label),
      if (business.hours.isNotEmpty)
        _InfoLine(
          icon: Icons.schedule_outlined,
          label: _availabilityLabel(business, DateTime.now()),
        ),
      if (_hasText(business.website))
        _InfoLine(icon: Icons.language_rounded, label: business.website!),
      if (_hasText(business.email))
        _InfoLine(icon: Icons.mail_outline_rounded, label: business.email!),
      if (_hasText(business.addressText))
        _InfoLine(
          icon: Icons.location_on_outlined,
          label: business.addressText!,
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información',
          style: TextStyle(
            color: Color(0xFF30443B),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          item,
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: RancoColors.forest),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF61736A),
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MainSections extends ConsumerWidget {
  const _MainSections({
    required this.business,
    required this.sections,
    required this.media,
  });

  final Business business;
  final List<BusinessProfileSection> sections;
  final List<_ProfilePhoto> media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];

    for (final section in sections) {
      switch (section) {
        case BusinessProfileSection.about:
          children.add(_AboutSection(description: business.description!));
        case BusinessProfileSection.services:
          children.add(_ServicesSection(business: business));
        case BusinessProfileSection.coverage:
          children.add(_CoverageSection(business: business));
        case BusinessProfileSection.hours:
          children.add(_HoursSummarySection(hours: business.hours));
        case BusinessProfileSection.photos:
          children.add(_PhotosSection(photos: media));
        case BusinessProfileSection.reviews:
          children.add(
            ReviewsSection(
              businessId: business.id,
              ratingAvg: business.ratingAvg,
              reviewCount: business.reviewCount,
            ),
          );
        case BusinessProfileSection.lodgingDetails:
          children.add(_LodgingDetailsSection(businessId: business.id));
        case BusinessProfileSection.location:
          children.add(_LocationSection(business: business));
        case BusinessProfileSection.menu:
          children.add(_MenuSection(businessId: business.id));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[
          child,
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.description,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Acerca',
      framed: false,
      child: Text(
        description.trim(),
        style: const TextStyle(
          color: Color(0xFF53675E),
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.business,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    final services = business.services
        .where((service) => service.subcategory.name.trim().isNotEmpty)
        .toList();

    return _ProfileSection(
      title:
          business.type == BusinessType.tourism ? 'Actividades' : 'Servicios',
      child: Column(
        children: [
          for (var index = 0; index < services.length; index++) ...[
            _ServiceItem(service: services[index]),
            if (index != services.length - 1)
              const Divider(height: 22, color: Color(0xFFE3EAE6)),
          ],
        ],
      ),
    );
  }
}

class _CoverageSection extends StatelessWidget {
  const _CoverageSection({
    required this.business,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    final visible = business.coverage.take(4).toList();
    final hiddenCount = business.coverage.length - visible.length;

    return _ProfileSection(
      title: 'Cobertura',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final location in visible) _LocationChip(name: location.name),
          if (hiddenCount > 0) _LocationChip(name: '+ $hiddenCount más'),
        ],
      ),
    );
  }
}

class _HoursSummarySection extends StatelessWidget {
  const _HoursSummarySection({
    required this.hours,
  });

  final List<BusinessHour> hours;

  @override
  Widget build(BuildContext context) {
    final today = hours
        .where((hour) => hour.dayOfWeek == DateTime.now().weekday)
        .firstOrNull;
    final todayText = today == null
        ? 'No informado'
        : today.isClosed
            ? 'Cerrado'
            : '${_shortTime(today.openTime)} - ${_shortTime(today.closeTime)}';

    return _ProfileSection(
      title: 'Horarios',
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: RancoColors.forest,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hoy',
                  style: TextStyle(
                    color: Color(0xFF6A7B73),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  todayText,
                  style: const TextStyle(
                    color: Color(0xFF30443B),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showHoursSheet(context, hours),
            child: const Text('Ver horarios'),
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.business,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    final location = business.primaryLocation;
    final address = business.addressText?.trim();

    return _ProfileSection(
      title: 'Ubicación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F1EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: RancoColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (address != null && address.isNotEmpty)
                      Text(
                        address,
                        style: const TextStyle(
                          color: Color(0xFF30443B),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (location != null) ...[
                      if (address != null && address.isNotEmpty)
                        const SizedBox(height: 4),
                      Text(
                        location.communeName == null
                            ? location.name
                            : '${location.name} · ${location.communeName}',
                        style: const TextStyle(
                          color: Color(0xFF6A7B73),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DirectionsButton(
              address: address,
              locationName: location?.name,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuSection extends ConsumerWidget {
  const _MenuSection({
    required this.businessId,
  });

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(gastronomyMenuProvider(businessId));

    return menu.when(
      data: (menu) {
        final visibleItems = menu.items
            .where((item) => item.name.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        if (visibleItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final categoryNames = {
          for (final category in menu.categories) category.id: category.name,
        };

        final grouped = <String?, List<gastronomy.MenuItem>>{};
        for (final item in visibleItems) {
          grouped.putIfAbsent(item.categoryId, () => []).add(item);
        }

        return _ProfileSection(
          title: 'Menú',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in grouped.entries) ...[
                if ((categoryNames[entry.key] ?? '').trim().isNotEmpty) ...[
                  Text(
                    categoryNames[entry.key]!.trim(),
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (var index = 0; index < entry.value.length; index++) ...[
                  _MenuItemRow(item: entry.value[index]),
                  if (index != entry.value.length - 1)
                    const Divider(height: 18, color: Color(0xFFE3EAE6)),
                ],
                if (entry.key != grouped.keys.last) const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
      loading: () => const _SectionCard(
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
  });

  final gastronomy.MenuItem item;

  @override
  Widget build(BuildContext context) {
    final description = item.description?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.trim(),
                      style: const TextStyle(
                        color: Color(0xFF30443B),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!item.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E6E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'No disponible',
                        style: TextStyle(
                          color: Color(0xFF8A4B35),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF61736A),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          _money(item.price),
          style: const TextStyle(
            color: RancoColors.forest,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LodgingDetailsSection extends ConsumerWidget {
  const _LodgingDetailsSection({
    required this.businessId,
  });

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(lodgingDetailsProvider(businessId));

    return details.when(
      data: (lodging) => _ProfileSection(
        title: 'Alojamiento',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lodging.pricePerNight > 0) ...[
              Text(
                '${_money(lodging.pricePerNight)} / noche',
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FactChip(
                  icon: Icons.groups_outlined,
                  label: '${lodging.maxGuests} '
                      '${lodging.maxGuests == 1 ? 'huésped' : 'huéspedes'}',
                ),
                _FactChip(
                  icon: Icons.king_bed_outlined,
                  label: '${lodging.beds} camas',
                ),
                _FactChip(
                  icon: Icons.bedroom_parent_outlined,
                  label: '${lodging.bedrooms} dormitorios',
                ),
                _FactChip(
                  icon: Icons.bathtub_outlined,
                  label: '${lodging.bathrooms.toStringAsFixed(0)} baños',
                ),
              ],
            ),
            if (lodging.checkInTime.isNotEmpty ||
                lodging.checkOutTime.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                [
                  if (lodging.checkInTime.isNotEmpty)
                    'Check-in ${lodging.checkInTime}',
                  if (lodging.checkOutTime.isNotEmpty)
                    'Check-out ${lodging.checkOutTime}',
                ].join(' · '),
                style: const TextStyle(
                  color: Color(0xFF53675E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  context.go('/business/$businessId/availability');
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Consultar disponibilidad'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const _SectionCard(
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.photos,
  });

  final List<_ProfilePhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return _ProfileSection(
      title: 'Fotos',
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final desktop = constraints.maxWidth >= 620;

          if (!desktop || photos.length < 3) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                return _GalleryPhoto(
                  photo: photos[index],
                  photos: photos,
                  initialIndex: index,
                );
              },
            );
          }

          final visible = photos.take(3).toList();

          final extra = photos.length - 3;

          return SizedBox(
            height: 320,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _GalleryPhoto(
                    photo: visible[0],
                    photos: photos,
                    initialIndex: 0,
                    radius: const BorderRadius.horizontal(
                      left: Radius.circular(
                        16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 9,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _GalleryPhoto(
                          photo: visible[1],
                          photos: photos,
                          initialIndex: 1,
                          radius: const BorderRadius.only(
                            topRight: Radius.circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 9,
                      ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _GalleryPhoto(
                              photo: visible[2],
                              photos: photos,
                              initialIndex: 2,
                              radius: const BorderRadius.only(
                                bottomRight: Radius.circular(
                                  16,
                                ),
                              ),
                            ),
                            if (extra > 0)
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    99,
                                  ),
                                  child: InkWell(
                                    onTap: () => _showPhotoViewer(
                                      context,
                                      photos,
                                      initialIndex: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      99,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Ver todas  +$extra',
                                        style: const TextStyle(
                                          color: RancoColors.forest,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GalleryPhoto extends StatelessWidget {
  const _GalleryPhoto({
    required this.photo,
    required this.photos,
    required this.initialIndex,
    this.radius = const BorderRadius.all(
      Radius.circular(14),
    ),
  });

  final _ProfilePhoto photo;
  final List<_ProfilePhoto> photos;
  final int initialIndex;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(
        0xFFE4F1EB,
      ),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showPhotoViewer(
            context,
            photos,
            initialIndex: initialIndex,
          );
        },
        child: Image.network(
          photo.url,
          width: double.infinity,
          height: double.infinity,
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
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: RancoColors.forest,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.service,
  });

  final BusinessService service;

  @override
  Widget build(BuildContext context) {
    final description = service.description?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F1EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.handyman_outlined,
            color: RancoColors.forest,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.subcategory.name,
                style: const TextStyle(
                  color: Color(0xFF30443B),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6A7B73),
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (service.priceFrom != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Desde ${_money(service.priceFrom!)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: RancoColors.forest,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FinalRequestCta extends StatelessWidget {
  const _FinalRequestCta({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.assignment_outlined),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: RancoColors.forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
    this.framed = true,
  });

  final String title;
  final Widget child;

  /// Sin marco: para bloques de texto corto donde una tarjeta grande sobra.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(
              0xFF263E34,
            ),
            fontSize: 19,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(
          height: 14,
        ),
        child,
      ],
    );
    if (!framed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: content,
      );
    }
    return _SectionCard(child: content);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(
            0xFFDDE7E2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: .018,
            ),
            blurRadius: 16,
            offset: const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({
    required this.type,
  });

  final BusinessType type;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF315F50),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 26),
          child: Icon(
            businessIconForType(type),
            size: 112,
            color: Colors.white.withValues(alpha: .18),
          ),
        ),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return _FactChip(
      icon: Icons.location_on_outlined,
      label: name,
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RancoColors.forest, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: RancoColors.forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({
    required this.address,
    this.locationName,
    this.fullWidth = false,
  });

  final String address;
  final String? locationName;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: () => _launchDirections(address, locationName),
      icon: const Icon(Icons.directions_outlined),
      label: const Text(
        'Cómo llegar',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: RancoColors.forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.height = 46,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: RancoColors.forest,
        side: const BorderSide(color: Color(0xFFD2E0D9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.favorite,
    required this.busy,
    required this.onPressed,
    this.fullWidth = false,
    this.height = 46,
  });

  final bool favorite;
  final bool busy;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          );

    if (fullWidth) {
      return OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: child,
        label: Text(favorite ? 'Guardado' : 'Guardar'),
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(height),
          foregroundColor: RancoColors.forest,
          side: const BorderSide(color: Color(0xFFD2E0D9)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return SizedBox(
      width: 46,
      height: 46,
      child: Tooltip(
        message: favorite ? 'Quitar de guardados' : 'Guardar',
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: RancoColors.forest,
            side: const BorderSide(color: Color(0xFFD2E0D9)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: 42,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            foregroundColor: RancoColors.forest,
            side: const BorderSide(color: Color(0xFFD2E0D9)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: busy
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 21),
        ),
      ),
    );
  }
}

class _BusinessDetailSkeleton extends StatelessWidget {
  const _BusinessDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 44),
                  Container(
                    height: 246,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE9E3),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD5E2DC)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMedia {
  const _ProfileMedia({
    required this.coverUrl,
    required this.logoUrl,
    required this.gallery,
  });

  final String? coverUrl;
  final String? logoUrl;
  final List<_ProfilePhoto> gallery;
}

class _ProfilePhoto {
  const _ProfilePhoto({
    required this.url,
    required this.type,
  });

  final String url;
  final String type;
}

List<Widget> _contactActions(
  Business business, {
  bool fullWidth = false,
  ValueChanged<String>? onEvent,
}) {
  return [
    if (_hasText(business.phone))
      _ContactAction(
        icon: Icons.call_outlined,
        label: 'Llamar',
        fullWidth: fullWidth,
        onPressed: () {
          onEvent?.call('CLICK_PHONE');
          _launchPhone(business.phone!);
        },
      ),
    if (_hasText(business.whatsapp))
      _ContactAction(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        fullWidth: fullWidth,
        onPressed: () {
          onEvent?.call('CLICK_WHATSAPP');
          _launchWhatsApp(business.whatsapp!);
        },
      ),
    if (_hasText(business.website))
      _ContactAction(
        icon: Icons.language_rounded,
        label: 'Sitio web',
        fullWidth: fullWidth,
        onPressed: () => _launchUri(business.website!),
      ),
    if (_hasText(business.email))
      _ContactAction(
        icon: Icons.mail_outline_rounded,
        label: 'Correo',
        fullWidth: fullWidth,
        onPressed: () => _launchEmail(business.email!),
      ),
  ];
}

void _showHoursSheet(BuildContext context, List<BusinessHour> hours) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Horarios',
                      style: TextStyle(
                        color: Color(0xFF30443B),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var day = 1; day <= 7; day++)
                _HourLine(
                  day: _dayLabel(day),
                  hour:
                      hours.where((item) => item.dayOfWeek == day).firstOrNull,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _HourLine extends StatelessWidget {
  const _HourLine({
    required this.day,
    required this.hour,
  });

  final String day;
  final BusinessHour? hour;

  @override
  Widget build(BuildContext context) {
    final value = hour == null
        ? 'No informado'
        : hour!.isClosed
            ? 'Cerrado'
            : '${_shortTime(hour!.openTime)} - ${_shortTime(hour!.closeTime)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: const TextStyle(color: Color(0xFF61736A)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF30443B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

void _showPhotoViewer(
  BuildContext context,
  List<_ProfilePhoto> photos, {
  required int initialIndex,
}) {
  if (photos.isEmpty) {
    return;
  }

  showDialog<void>(
    context: context,
    builder: (context) {
      return _PhotoCarouselDialog(
        photos: photos,
        initialIndex: initialIndex.clamp(0, photos.length - 1),
      );
    },
  );
}

class _PhotoCarouselDialog extends StatefulWidget {
  const _PhotoCarouselDialog({
    required this.photos,
    required this.initialIndex,
  });

  final List<_ProfilePhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoCarouselDialog> createState() => _PhotoCarouselDialogState();
}

class _PhotoCarouselDialogState extends State<_PhotoCarouselDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    final hasPrevious = _index > 0;
    final hasNext = _index < total - 1;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    final bottomRailHeight = total > 1 ? (compact ? 74.0 : 92.0) : 0.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 28,
        vertical: compact ? 12 : 22,
      ),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: size.width,
        constraints: BoxConstraints(
          maxWidth: 1240,
          maxHeight: size.height * .9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF050807),
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          border: Border.all(
            color: Colors.white.withValues(alpha: .08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .38),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: size.height * (compact ? .86 : .88),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: bottomRailHeight,
                child: ColoredBox(
                  color: Colors.black,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (value) {
                      setState(() {
                        _index = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 3.5,
                        child: Center(
                          child: Image.network(
                            widget.photos[index].url,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 10 : 14,
                    compact ? 8 : 14,
                    compact ? 10 : 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .76),
                        Colors.black.withValues(alpha: .00),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: RancoColors.forest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Fotos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_index + 1} de $total',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .12),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (total > 1) ...[
                Positioned(
                  left: compact ? 8 : 18,
                  top: 76,
                  bottom: bottomRailHeight,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.chevron_left_rounded,
                      enabled: hasPrevious,
                      onTap: () {
                        _goTo(_index - 1);
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: compact ? 8 : 18,
                  top: 76,
                  bottom: bottomRailHeight,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: hasNext,
                      onTap: () {
                        _goTo(_index + 1);
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: bottomRailHeight,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 10 : 18,
                      compact ? 9 : 12,
                      compact ? 10 : 18,
                      compact ? 10 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF09110E),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: .08),
                        ),
                      ),
                    ),
                    child: Center(
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: total,
                        separatorBuilder: (_, __) {
                          return SizedBox(width: compact ? 7 : 10);
                        },
                        itemBuilder: (context, index) {
                          final selected = index == _index;

                          return InkWell(
                            onTap: () {
                              _goTo(index);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: compact ? 58 : 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? RancoColors.primaryMuted
                                      : Colors.white.withValues(alpha: .18),
                                  width: selected ? 2.5 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: RancoColors.forest.withValues(
                                            alpha: .28,
                                          ),
                                          blurRadius: 14,
                                        ),
                                      ]
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                widget.photos[index].url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const ColoredBox(
                                    color: Color(0xFF223029),
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white70,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.photos.length) {
      return;
    }

    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: enabled ? onTap : null,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Colors.white.withValues(alpha: .14),
        disabledBackgroundColor: Colors.white.withValues(alpha: .05),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
      ),
      icon: Icon(
        icon,
        size: 30,
      ),
    );
  }
}

Future<void> _launchPhone(String phone) async {
  final clean = phone.replaceAll(RegExp(r'\s+'), '');
  await launchUrl(Uri(scheme: 'tel', path: clean));
}

Future<void> _launchWhatsApp(String phone) async {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.startsWith('9') && digits.length == 9) {
    digits = '56$digits';
  }

  await launchUrl(
    Uri.parse('https://wa.me/$digits'),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchDirections(String address, String? locationName) async {
  final query = [
    address.trim(),
    if (locationName?.trim().isNotEmpty == true) locationName!.trim(),
    'Región de Los Ríos',
    'Chile',
  ].join(', ');

  await launchUrl(
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchEmail(String email) async {
  await launchUrl(Uri(scheme: 'mailto', path: email.trim()));
}

Future<void> _launchUri(String value) async {
  final clean = value.trim();
  final uri =
      clean.startsWith('http') ? Uri.parse(clean) : Uri.parse('https://$clean');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _primaryCtaLabel(BusinessType type) {
  return switch (type) {
    BusinessType.service => 'Solicitar servicio',
    BusinessType.tourism => 'Solicitar actividad',
    _ => 'Solicitar',
  };
}

String _dayLabel(int day) {
  return switch (day) {
    1 => 'Lunes',
    2 => 'Martes',
    3 => 'Miércoles',
    4 => 'Jueves',
    5 => 'Viernes',
    6 => 'Sábado',
    7 => 'Domingo',
    _ => 'Día',
  };
}

String _shortTime(String? value) {
  if (value == null || value.isEmpty) {
    return 'No informado';
  }

  final parts = value.split(':');
  if (parts.length < 2) {
    return value;
  }

  return '${parts[0]}:${parts[1]}';
}

String _availabilityLabel(Business business, DateTime now) {
  final today =
      business.hours.where((hour) => hour.dayOfWeek == now.weekday).firstOrNull;

  if (today == null || today.isClosed) {
    return 'Cerrado ahora';
  }

  final closes = _shortTime(today.closeTime);
  if (businessIsAvailableNow(business, now) && closes != 'No informado') {
    return 'Abierto ahora · Cierra a $closes';
  }

  final opens = _shortTime(today.openTime);
  if (opens != 'No informado') {
    return 'Cerrado ahora · Abre a $opens';
  }

  return businessIsAvailableNow(business, now)
      ? 'Abierto ahora'
      : 'Cerrado ahora';
}

String _money(int value) {
  return NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$',
    decimalDigits: 0,
  ).format(value);
}

bool _hasText(String? value) {
  return value?.trim().isNotEmpty == true;
}
