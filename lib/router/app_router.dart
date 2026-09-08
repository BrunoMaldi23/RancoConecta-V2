import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/businesses/data/business_repository.dart';
import '../features/businesses/presentation/business_detail_screen.dart';
import '../features/businesses/presentation/lodging_availability_screen.dart';
import '../features/discovery/presentation/explore_screen.dart';
import '../features/favorites/presentation/saved_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/account_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/lodging_bookings/presentation/provider_bookings_screen.dart';
import '../features/provider_dashboard/presentation/lodging_calendar_screen.dart';
import '../features/provider_dashboard/presentation/lodging_information_screen.dart';
import '../features/provider_dashboard/presentation/lodging_photos_screen.dart';
import '../features/provider_dashboard/presentation/lodging_rates_screen.dart';
import '../features/provider_dashboard/presentation/provider_dashboard_screen.dart';
import '../features/provider_registration/presentation/provider_registration_screen.dart';
import '../features/service_requests/presentation/create_request_screen.dart';
import '../features/service_requests/presentation/requests_screen.dart';
import '../router/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  final refreshListenable = GoRouterRefreshStream(
    authRepository.observeAuthState(),
  );

  ref.onDispose(
    refreshListenable.dispose,
  );

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = authRepository.currentUser();

      final path = state.uri.path;

      final protected = (path.startsWith('/business/') &&
              path.endsWith(
                '/request',
              )) ||
          path.startsWith(
            '/requests/',
          ) ||
          path == '/account/edit';

      if (protected && user == null) {
        return '/sign-in';
      }

      return null;
    },
    routes: [
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
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RequestsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SavedScreen(),
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
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
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
        path: '/provider/dashboard',
        builder: (context, state) => const ProviderDashboardScreen(),
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/account/edit',
        builder: (context, state) => const EditProfileScreen(),
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(
    Stream<dynamic> stream,
  ) {
    notifyListeners();

    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
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
