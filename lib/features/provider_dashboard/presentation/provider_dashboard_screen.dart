import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../../../core/widgets/ranco_app_bar.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final business = ref.watch(
      myProviderBusinessProvider,
    );

    return Scaffold(
      backgroundColor: const Color(
        0xFFEAF4F0,
      ),
      appBar: const RancoAppBar(
        title: 'Mi alojamiento',
        fallbackRoute: '/account',
      ),
      body: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text(
                'No encontramos tu negocio.',
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(
              18,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(
                  18,
                ),
                decoration: BoxDecoration(
                  color: RancoColors.forest,
                  borderRadius: BorderRadius.circular(
                    22,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.holiday_village_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    const Text(
                      'Membresia Alojamiento',
                      style: TextStyle(
                        color: Color(
                          0xFFD8EBE3,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.go(
                          '/business/${business.id}',
                        );
                      },
                      icon: const Icon(
                        Icons.visibility_outlined,
                      ),
                      label: const Text(
                        'Ver publicación',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              const Text(
                'GESTION',
                style: TextStyle(
                  color: Color(
                    0xFF718078,
                  ),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              _DashboardTile(
                icon: Icons.holiday_village_outlined,
                title: 'Información del alojamiento',
                subtitle: 'Huéspedes, dormitorios, camas y horarios',
                onTap: () {
                  context.go(
                    '/provider/lodging',
                  );
                },
              ),
              _DashboardTile(
                icon: Icons.payments_outlined,
                title: 'Tarifas',
                subtitle: 'Precio por noche y persona adicional',
                onTap: () {
                  context.go(
                    '/provider/rates',
                  );
                },
              ),
              _DashboardTile(
                icon: Icons.photo_library_outlined,
                title: 'Fotografías',
                subtitle: 'Portada y galería',
                onTap: () {
                  context.go(
                    '/provider/photos',
                  );
                },
              ),
              _DashboardTile(
                icon: Icons.calendar_month_outlined,
                title: 'Calendario',
                subtitle: 'Disponibilidad y bloqueos',
                onTap: () {
                  context.go(
                    '/provider/calendar',
                  );
                },
              ),
              _DashboardTile(
                icon: Icons.event_available_outlined,
                title: 'Reservas',
                subtitle: 'Solicitudes recibidas',
                onTap: () {
                  context.go(
                    '/provider/bookings',
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            const Center(
          child: Text(
            'No pudimos cargar el alojamiento.',
          ),
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: const Color(
            0xFFD4E0DA,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 5,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE4F3EC,
            ),
            borderRadius: BorderRadius.circular(
              13,
            ),
          ),
          child: Icon(
            icon,
            color: RancoColors.forest,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}
