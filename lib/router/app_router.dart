import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../config/app_build_info.dart';
import '../core/debug/bootstrap_debug_logger.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/access_screen.dart';

import '../features/admin/presentation/admin_screens.dart';
import '../features/admin/presentation/admin_settings_screens.dart';

import '../features/businesses/data/business_repository.dart';

import '../features/businesses/presentation/business_detail_screen.dart';

import '../features/businesses/presentation/lodging_availability_screen.dart';

import '../features/categories/presentation/categories_screen.dart';

import '../features/discovery/presentation/explore_screen.dart';

import '../features/favorites/presentation/saved_screen.dart';

import '../features/home/presentation/home_screen.dart';

import '../features/gastronomy/presentation/provider_gastronomy_screens.dart';
import '../features/gastronomy/presentation/table_reservation_screen.dart';

import '../features/profile/presentation/account_screen.dart';
import '../features/profile/presentation/account_security_screen.dart';

import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/application/profile_providers.dart';

import '../features/lodging_bookings/presentation/provider_bookings_screen.dart';
import '../features/legal/presentation/legal_screen.dart';

import '../features/messaging/presentation/messages_screen.dart';

import '../features/notifications/presentation/notifications_screen.dart';

import '../features/provider_dashboard/presentation/lodging_calendar_screen.dart';

import '../features/provider_dashboard/presentation/lodging_information_screen.dart';

import '../features/provider_dashboard/presentation/lodging_photos_screen.dart';

import '../features/provider_dashboard/presentation/lodging_rates_screen.dart';

import '../features/provider_dashboard/presentation/provider_dashboard_screen.dart';

import '../features/provider_dashboard/presentation/service_management_screens.dart';

import '../features/provider_dashboard/application/provider_context.dart';
import '../features/provider_dashboard/application/provider_context_state.dart';

import '../features/provider_registration/presentation/provider_business_status_screen.dart';

import '../features/provider_registration/presentation/provider_registration_screen.dart';

import '../features/service_requests/presentation/create_request_screen.dart';

import '../features/service_requests/presentation/provider_requests_screen.dart';

import '../features/service_requests/presentation/requests_screen.dart';
import '../features/service_requests/presentation/reservation_detail_screen.dart';
import '../features/service_requests/domain/customer_activity_item.dart';

import '../router/app_shell.dart';

import '../shared/models/business.dart';
import '../shared/models/profile.dart';
import '../core/widgets/ranco_brand.dart';
import '../core/widgets/ranco_app_bar.dart';
import '../core/widgets/ranco_error_state.dart';
import '../core/widgets/ranco_states.dart';
import '../theme/ranco_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshNotifier(ref);
  var recoveryReturnPending =
      kIsWeb && Uri.base.queryParameters['recovery'] == '1';

  ref.onDispose(
    refreshListenable.dispose,
  );

  return GoRouter(
    initialLocation: kIsWeb && Uri.base.path != '/'
        ? '${Uri.base.path}${Uri.base.hasQuery ? '?${Uri.base.query}' : ''}'
        : '/sign-in',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;
      if (ref.read(signingOutProvider)) {
        return path == '/sign-in' ? null : '/sign-in';
      }
      final auth = ref.read(authStateProvider);
      final user = auth.valueOrNull;

      final providerManagementRoute = _isProviderManagementRoute(path);
      final adminRoute = path.startsWith('/admin');

      final protected = path.startsWith(
            '/requests/',
          ) ||
          path.startsWith(
            '/messages',
          ) ||
          path.startsWith(
            '/notifications',
          ) ||
          path.startsWith('/requests/lodging/') ||
          path.startsWith('/requests/gastronomy/') ||
          path == '/account/edit' ||
          path == '/account/security' ||
          providerManagementRoute ||
          adminRoute;

      if (auth.isLoading && !auth.hasValue) {
        logBootstrapEvent('AUTH_BOOTSTRAP_START');
        return _bootstrapRoute(state);
      }

      if (auth.hasError) {
        logBootstrapEvent(
          'ROUTER_REDIRECT_DECISION',
          {
            'path': path,
            'decision': 'auth_error',
          },
        );

        return path == '/bootstrap' ? null : _bootstrapRoute(state);
      }

      logBootstrapEvent(user == null ? 'NO_SESSION' : 'AUTH_SESSION_FOUND');

      if (path == '/bootstrap') {
        logBootstrapEvent('BOOTSTRAP_READY');
        return _nextOrHome(state);
      }

      if (recoveryReturnPending) {
        recoveryReturnPending = false;
        if (path != '/reset-password') return '/reset-password';
      }

      if (path == '/sign-in' && user != null) {
        if (user.isAnonymous) {
          if (state.uri.queryParameters['choose'] == '1') return null;
          final next = _nextOrHome(state);
          if (next == '/') return '/';
          return next;
        }
        return _nextOrHome(state);
      }

      if (path == '/visitor/profile' && user != null && !user.isAnonymous) {
        return '/account';
      }

      if (user?.isAnonymous == true &&
          (providerManagementRoute || adminRoute)) {
        return providerManagementRoute
            ? Uri(path: '/provider/sign-in', queryParameters: {
                'next': state.uri.toString(),
              }).toString()
            : '/explore';
      }

      if (protected && user == null) {
        final loginUri = Uri(
          path: '/sign-in',
          queryParameters: {
            'next': state.uri.toString(),
          },
        );

        return loginUri.toString();
      }

      if (adminRoute && user != null) {
        final profile = ref.read(currentProfileProvider);
        if (profile.isLoading && !profile.hasValue) {
          return _bootstrapRoute(state);
        }
        if (profile.hasError) {
          return _bootstrapRoute(state);
        }
        if (profile.valueOrNull?.role.canAccessAdmin != true) {
          return '/explore';
        }
      }

      if (path == '/provider/status' || path == '/provider/dashboard') {
        return '/provider/business';
      }

      if (providerManagementRoute && user != null && !user.isAnonymous) {
        final profile = ref.read(currentProfileProvider);
        if (profile.isLoading && !profile.hasValue) {
          return _bootstrapRoute(state);
        }
        if (profile.hasError) {
          return path == '/bootstrap' ? null : _bootstrapRoute(state);
        }
        final role = profile.valueOrNull?.role;
        if (role?.canAccessAdmin == true) return '/admin';
        if (providerManagementRoute &&
            role != ProfileRole.provider &&
            role != ProfileRole.customer) {
          return '/provider/join';
        }
      }

      if (path == '/provider') {
        return user == null || user.isAnonymous
            ? '/provider/join'
            : '/provider/business';
      }

      if (providerManagementRoute && user != null) {
        final providerContext = ref.read(providerContextProvider);

        if (providerContext.isLoading && !providerContext.hasValue) {
          logBootstrapEvent(
            'ROUTER_REDIRECT_DECISION',
            {
              'path': path,
              'decision': 'provider_loading',
            },
          );

          return _bootstrapRoute(state);
        }

        if (providerContext.hasError) {
          logBootstrapEvent(
            'ROUTER_REDIRECT_DECISION',
            {
              'path': path,
              'decision': 'provider_error',
            },
          );

          return path == '/provider/business' ? null : '/provider/business';
        }

        final contextState = providerContext.valueOrNull;
        final decision = _providerRedirectDecision(
          path: path,
          contextState: contextState,
        );

        logBootstrapEvent(
          'ROUTER_REDIRECT_DECISION',
          {
            'path': path,
            'providerStatus': contextState?.status.name,
            'decision': decision ?? 'allow',
          },
        );

        return decision;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/bootstrap',
        builder: (context, state) => const BootstrapScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          context,
          state,
          navigationShell,
        ) {
          return AppShell(
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
              GoRoute(
                path: '/categories',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CategoriesScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ExploreScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/requests',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: RequestsScreen(
                    showBack: state.uri.queryParameters['from'] == 'account',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: SavedScreen(
                    showBack: state.uri.queryParameters['from'] == 'account',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AccountScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => AccessScreen(
          nextRoute: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: '/terminos',
        builder: (context, state) => const LegalScreen(privacy: false),
      ),
      GoRoute(
        path: '/politica-privacidad',
        builder: (context, state) => const LegalScreen(privacy: true),
      ),
      GoRoute(
        path: '/contacto',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/visitor/profile',
        redirect: (context, state) => '/explore',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/provider/sign-in',
        builder: (context, state) => SignInScreen(
          nextRoute: state.uri.queryParameters['next'],
          providerAccess: true,
        ),
      ),
      GoRoute(
        path: '/sign-up',
        redirect: (context, state) =>
            state.uri.queryParameters['next'] == '/account'
                ? null
                : '/provider/join',
        builder: (context, state) => SignUpScreen(
          nextRoute: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: '/provider/join',
        builder: (context, state) => const ProviderJoinScreen(),
      ),
      GoRoute(
        path: '/provider/register',
        builder: (context, state) => const ProviderRegistrationScreen(),
      ),
      GoRoute(
        path: '/provider/business',
        builder: (context, state) => const _ProviderBusinessHub(),
      ),
      GoRoute(
        path: '/provider/status',
        builder: (context, state) => const ProviderBusinessStatusScreen(),
      ),
      GoRoute(
        path: '/provider/dashboard',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/provider/profile',
        builder: (context, state) => const ProviderProfileScreen(),
      ),
      GoRoute(
        path: '/provider/services',
        builder: (context, state) => const ProviderServicesScreen(),
      ),
      GoRoute(
        path: '/provider/coverage',
        builder: (context, state) => const ProviderCoverageScreen(),
      ),
      GoRoute(
        path: '/provider/location',
        builder: (context, state) => const ProviderLocationScreen(),
      ),
      GoRoute(
        path: '/provider/hours',
        builder: (context, state) => const ProviderHoursScreen(),
      ),
      GoRoute(
        path: '/provider/lodging',
        builder: (context, state) => const LodgingInformationScreen(),
      ),
      GoRoute(
        path: '/provider/bookings',
        builder: (context, state) => const ProviderBookingsScreen(),
      ),
      GoRoute(
        path: '/provider/calendar',
        builder: (context, state) => const LodgingCalendarScreen(),
      ),
      GoRoute(
        path: '/provider/photos',
        builder: (context, state) => const LodgingPhotosScreen(),
      ),
      GoRoute(
        path: '/provider/rates',
        builder: (context, state) => const LodgingRatesScreen(),
      ),
      GoRoute(
        path: '/provider/requests',
        builder: (context, state) => const ProviderRequestsScreen(),
      ),
      GoRoute(
        path: '/provider/menu',
        builder: (context, state) => const ProviderMenuScreen(),
      ),
      GoRoute(
        path: '/provider/table-reservations',
        builder: (context, state) => const ProviderTableReservationsScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) => MessageDetailScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          nextRoute: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminWorkspaceShell(
          path: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/businesses',
            builder: (context, state) => AdminBusinessesScreen(
              initialStatus: state.uri.queryParameters['status'] == null
                  ? null
                  : BusinessPublicationStatus.parseOrDefault(
                      state.uri.queryParameters['status'],
                    ),
            ),
          ),
          GoRoute(
            path: '/admin/businesses/pending',
            builder: (context, state) => const AdminBusinessesScreen(
              initialStatus: BusinessPublicationStatus.pendingReview,
            ),
          ),
          GoRoute(
            path: '/admin/businesses/:id',
            builder: (context, state) => AdminBusinessDetailScreen(
              businessId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/categories',
            builder: (context, state) => const AdminCategoriesScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminWhatsAppSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/analytics',
            builder: (context, state) => const AdminAnalyticsScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AdminAuditScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/account/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/account/security',
        builder: (context, state) => const AccountSecurityScreen(),
      ),
      GoRoute(
        path: '/requests/lodging/:id',
        builder: (context, state) => ReservationDetailScreen(
          reservationId: state.pathParameters['id']!,
          type: CustomerActivityType.lodging,
        ),
      ),
      GoRoute(
        path: '/requests/gastronomy/:id',
        builder: (context, state) => ReservationDetailScreen(
          reservationId: state.pathParameters['id']!,
          type: CustomerActivityType.gastronomy,
        ),
      ),
      GoRoute(
        path: '/business/:id/availability',
        builder: (context, state) {
          final businessId = state.pathParameters['id']!;

          return _LodgingAvailabilityRoute(
            businessId: businessId,
          );
        },
      ),
      GoRoute(
        path: '/business/:id/table-reservation',
        builder: (context, state) => TableReservationScreen(
          businessId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/business/:id',
        builder: (context, state) => BusinessDetailScreen(
          businessId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'request',
            builder: (context, state) => CreateRequestScreen(
              businessId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/requests/:id',
        builder: (context, state) => RequestDetailScreen(
          requestId: state.pathParameters['id']!,
          justSent: state.uri.queryParameters['sent'] == '1',
          attachmentsFailed:
              state.uri.queryParameters['attachments'] == 'failed',
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Ruta no encontrada: ${state.uri.path}',
        ),
      ),
    ),
  );
});

bool _isProviderManagementRoute(String path) {
  return path == '/provider/business' ||
      path == '/provider/dashboard' ||
      path == '/provider/profile' ||
      path == '/provider/services' ||
      path == '/provider/coverage' ||
      path == '/provider/location' ||
      path == '/provider/hours' ||
      path == '/provider/register' ||
      path == '/provider/status' ||
      path == '/provider/lodging' ||
      path == '/provider/bookings' ||
      path == '/provider/requests' ||
      path == '/provider/calendar' ||
      path == '/provider/photos' ||
      path == '/provider/rates' ||
      path == '/provider/menu' ||
      path == '/provider/table-reservations';
}

String? _bootstrapRoute(GoRouterState state) {
  if (state.uri.path == '/bootstrap') {
    return null;
  }

  return Uri(
    path: '/bootstrap',
    queryParameters: {
      'next': state.uri.toString(),
    },
  ).toString();
}

String _nextOrHome(GoRouterState state) {
  final next = state.uri.queryParameters['next'];
  if (next == null || next.isEmpty || !next.startsWith('/')) {
    return '/';
  }
  return next;
}

String? _providerRedirectDecision({
  required String path,
  required ProviderContextState? contextState,
}) {
  final status = contextState?.status;

  if (status == null ||
      status == ProviderContextStatus.loading ||
      status == ProviderContextStatus.unauthenticated) {
    return null;
  }

  if (status == ProviderContextStatus.noBusiness) {
    return _isProviderOnboardingRoute(path) ? null : '/provider/business';
  }

  if (status == ProviderContextStatus.published) {
    return null;
  }

  if (_isProviderOnboardingRoute(path)) {
    return null;
  }

  return '/provider/business';
}

bool _isProviderOnboardingRoute(String path) {
  return path == '/provider/business' ||
      path == '/provider/status' ||
      path == '/provider/register' ||
      path == '/provider/join';
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this.ref) {
    notifyListeners();

    _authSubscription = ref.listen<AsyncValue<Object?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );

    _signingOutSubscription = ref.listen<bool>(
      signingOutProvider,
      (_, __) => notifyListeners(),
    );

    _providerSubscription = ref.listen<AsyncValue<Object?>>(
      providerContextProvider,
      (_, __) => notifyListeners(),
    );
    _profileSubscription = ref.listen<AsyncValue<Object?>>(
      currentProfileProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref ref;
  late final ProviderSubscription<AsyncValue<Object?>> _authSubscription;
  late final ProviderSubscription<bool> _signingOutSubscription;
  late final ProviderSubscription<AsyncValue<Object?>> _providerSubscription;
  late final ProviderSubscription<AsyncValue<Object?>> _profileSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _signingOutSubscription.close();
    _providerSubscription.close();
    _profileSubscription.close();

    super.dispose();
  }
}

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final providerContext =
        auth.valueOrNull == null ? null : ref.watch(providerContextProvider);
    final hasError = auth.hasError || providerContext?.hasError == true;

    // FASE 3.23: solo presentación (mismas condiciones). Marca, frase breve
    // e indicador discreto que aparece con un fundido corto: si el arranque
    // es rápido no hay destello de spinner.
    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RancoBrandMark(size: 56),
                const SizedBox(height: 18),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    hasError
                        ? 'No pudimos preparar tu sesión.'
                        : 'Preparando tu cuenta…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasError
                      ? 'Reintenta iniciar sesión para continuar.'
                      : 'Esto toma solo un momento.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                if (!hasError)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    // Invisible los primeros ~300 ms, luego fundido.
                    curve: const Interval(.6, 1, curve: Curves.easeOut),
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Color(0xFFE1ECE6),
                          color: RancoColors.forest,
                        ),
                      ),
                    ),
                  ),
                // Datos de build solo en desarrollo, nunca al usuario final.
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'build ${AppBuildInfo.version} · ${AppBuildInfo.gitSha}',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8A9A92),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderBusinessHub extends ConsumerWidget {
  const _ProviderBusinessHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerContext = ref.watch(providerContextProvider);
    return providerContext.when(
      data: (state) => state.status == ProviderContextStatus.published
          ? const ProviderDashboardScreen()
          : const ProviderBusinessStatusScreen(),
      // FASE 3.23: misma lógica; carga con esqueleto y error compartido.
      loading: () => const Scaffold(
        backgroundColor: RancoColors.canvas,
        appBar: RancoAppBar(title: 'Mi negocio', fallbackRoute: '/account'),
        body: RancoLoadingState(rows: 3, rowHeight: 96),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: RancoColors.canvas,
        appBar: const RancoAppBar(
          title: 'Mi negocio',
          fallbackRoute: '/account',
        ),
        body: RancoErrorState(
          message: 'No pudimos cargar tu negocio.',
          onRetry: () => ref.invalidate(providerContextProvider),
        ),
      ),
    );
  }
}

class _LodgingAvailabilityRoute extends ConsumerWidget {
  const _LodgingAvailabilityRoute({
    required this.businessId,
  });

  final String businessId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return FutureBuilder(
      future: ref
          .read(
            businessRepositoryProvider,
          )
          .getBusinessById(
            businessId,
          ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(
              0xFFEAF4F0,
            ),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'No pudimos cargar el alojamiento: ${snapshot.error}',
              ),
            ),
          );
        }

        final result = snapshot.data;

        if (result == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'No encontramos el alojamiento.',
              ),
            ),
          );
        }

        return result.when(
          success: (business) {
            return LodgingAvailabilityScreen(
              business: business,
            );
          },
          failure: (failure) {
            return Scaffold(
              backgroundColor: const Color(
                0xFFEAF4F0,
              ),
              appBar: AppBar(
                title: const Text(
                  'Disponibilidad',
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    24,
                  ),
                  child: Text(
                    failure.message,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
