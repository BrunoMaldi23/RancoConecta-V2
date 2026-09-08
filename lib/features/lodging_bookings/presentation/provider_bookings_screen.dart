import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ranco_colors.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../application/lodging_booking_providers.dart';
import '../data/lodging_booking_repository.dart';

class ProviderBookingsScreen extends ConsumerWidget {
  const ProviderBookingsScreen({
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
      appBar: AppBar(
        title: const Text(
          'Reservas',
        ),
      ),
      body: business.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text(
                'No encontramos tu alojamiento.',
              ),
            );
          }

          final bookings = ref.watch(
            lodgingBookingsForBusinessProvider(
              business.id,
            ),
          );

          return bookings.when(
            data: (items) {
              final pending = items
                  .where(
                    (item) => item.isPending,
                  )
                  .toList();

              final accepted = items
                  .where(
                    (item) => item.isAccepted,
                  )
                  .toList();

              final history = items
                  .where(
                    (item) => !item.isPending && !item.isAccepted,
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(
                  18,
                ),
                children: [
                  const Text(
                    'Reservas recibidas',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '${pending.length} pendientes',
                    style: const TextStyle(
                      color: Color(
                        0xFF687A71,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (pending.isEmpty) const _EmptyBookings(),
                  if (pending.isNotEmpty) ...[
                    const _SectionTitle(
                      'PENDIENTES',
                    ),
                    for (final booking in pending)
                      _BookingCard(
                        booking: booking,
                        showActions: true,
                        onAccept: () {
                          _accept(
                            context,
                            ref,
                            booking,
                          );
                        },
                        onReject: () {
                          _reject(
                            context,
                            ref,
                            booking,
                          );
                        },
                      ),
                  ],
                  if (accepted.isNotEmpty) ...[
                    const SizedBox(
                      height: 18,
                    ),
                    const _SectionTitle(
                      'PRÓXIMAS',
                    ),
                    for (final booking in accepted)
                      _BookingCard(
                        booking: booking,
                      ),
                  ],
                  if (history.isNotEmpty) ...[
                    const SizedBox(
                      height: 18,
                    ),
                    const _SectionTitle(
                      'HISTORIAL',
                    ),
                    for (final booking in history)
                      _BookingCard(
                        booking: booking,
                      ),
                  ],
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
                Center(
              child: Text(
                'No pudimos cargar las reservas: $error',
              ),
            ),
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

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    LodgingBooking booking,
  ) async {
    try {
      await ref
          .read(
            lodgingBookingRepositoryProvider,
          )
          .accept(
            booking.id,
          );

      ref.invalidate(
        lodgingBookingsForBusinessProvider(
          booking.businessId,
        ),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Reserva aceptada.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos aceptar: $error',
          ),
        ),
      );
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    LodgingBooking booking,
  ) async {
    try {
      await ref
          .read(
            lodgingBookingRepositoryProvider,
          )
          .reject(
            booking.id,
          );

      ref.invalidate(
        lodgingBookingsForBusinessProvider(
          booking.businessId,
        ),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Reserva rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos rechazar: $error',
          ),
        ),
      );
    }
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.showActions = false,
    this.onAccept,
    this.onReject,
  });

  final LodgingBooking booking;

  final bool showActions;

  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 11,
      ),
      padding: const EdgeInsets.all(
        16,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFE3F2EB,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  booking.guestName.isNotEmpty
                      ? booking.guestName[0].toUpperCase()
                      : 'H',
                  style: const TextStyle(
                    color: RancoColors.forest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.guestName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${_date(booking.checkIn)} → ${_date(booking.checkOut)}',
                      style: const TextStyle(
                        color: Color(
                          0xFF677970,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                status: booking.status,
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.nights_stay_outlined,
                text: '${booking.nights} noches',
              ),
              _InfoChip(
                icon: Icons.people_outline,
                text: '${booking.guests} huéspedes',
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Color(
                    0xFF677970,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _money(
                  booking.totalAmount,
                ),
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (booking.guestMessage?.trim().isNotEmpty == true) ...[
            const SizedBox(
              height: 12,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                11,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF4F7F5,
                ),
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Text(
                booking.guestMessage!,
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(
              height: 14,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text(
                      'Rechazar',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: RancoColors.forest,
                    ),
                    child: const Text(
                      'Aceptar',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _date(
    DateTime value,
  ) {
    return '${value.day}/${value.month}/${value.year}';
  }

  static String _money(
    int value,
  ) {
    final raw = value.toString();

    final buffer = StringBuffer();

    for (var i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;

      buffer.write(
        raw[i],
      );

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$${buffer.toString()}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE5F2EC,
        ),
        borderRadius: BorderRadius.circular(
          11,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: RancoColors.forest,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(
    BuildContext context,
  ) {
    var label = 'Pendiente';

    var background = const Color(
      0xFFFFF1D6,
    );

    var foreground = const Color(
      0xFF895B19,
    );

    if (status == 'accepted') {
      label = 'Aceptada';

      background = const Color(
        0xFFE1F3E8,
      );

      foreground = const Color(
        0xFF257552,
      );
    }

    if (status == 'rejected') {
      label = 'Rechazada';

      background = const Color(
        0xFFFFE5DF,
      );

      foreground = const Color(
        0xFFB75342,
      );
    }

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
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
    this.text,
  );

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 9,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(
            0xFF718078,
          ),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(
        28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 38,
            color: Color(
              0xFF748A80,
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'Aún no tienes reservas pendientes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
