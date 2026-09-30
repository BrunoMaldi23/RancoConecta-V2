import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../lodging_bookings/data/lodging_booking_repository.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../../provider_dashboard/data/business_media_repository.dart';
import '../../provider_dashboard/data/lodging_calendar_repository.dart';

class LodgingAvailabilityScreen extends ConsumerStatefulWidget {
  const LodgingAvailabilityScreen({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  ConsumerState<LodgingAvailabilityScreen> createState() =>
      _LodgingAvailabilityScreenState();
}

class _LodgingAvailabilityScreenState
    extends ConsumerState<LodgingAvailabilityScreen> {
  DateTimeRange? _range;

  int _guests = 1;

  final _messageController = TextEditingController();

  bool _creating = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final details = ref.watch(
      lodgingDetailsProvider(
        widget.business.id,
      ),
    );

    final mediaRepository = ref.read(
      businessMediaRepositoryProvider,
    );

    final coverPath = widget.business.coverPath;

    final coverUrl = coverPath == null
        ? null
        : mediaRepository.publicUrl(
            coverPath,
          );

    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F7F5,
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(
            left: 14,
            top: 7,
            bottom: 7,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              14,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(
                14,
              ),
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                  return;
                }

                context.go(
                  '/business/${widget.business.id}',
                );
              },
              child: const Icon(
                Icons.arrow_back_rounded,
                color: RancoColors.forest,
                size: 23,
              ),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservar alojamiento',
              style: TextStyle(
                color: Color(
                  0xFF263E34,
                ),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Completa los datos de tu solicitud',
              style: TextStyle(
                color: Color(
                  0xFF718078,
                ),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: details.when(
        data: (lodging) {
          final screenWidth = MediaQuery.sizeOf(context).width;

          final desktop = screenWidth >= 980;

          Widget bookingStatus() {
            if (_range == null) {
              return _BookingSummaryIdle(
                pricePerNight: lodging.pricePerNight,
                guests: _guests,
              );
            }

            return FutureBuilder<List<LodgingCalendarDay>>(
              future: ref
                  .read(
                    lodgingCalendarRepositoryProvider,
                  )
                  .listRange(
                    businessId: widget.business.id,
                    from: _range!.start,
                    to: _range!.end,
                  ),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _BookingAsideCard(
                    child: SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _BookingAsideCard(
                    child: _MessageCard(
                      icon: Icons.error_outline,
                      title: 'No pudimos revisar las fechas',
                      message: '${snapshot.error}',
                      error: true,
                    ),
                  );
                }

                final entries = snapshot.data ?? const <LodgingCalendarDay>[];

                final nights = _range!.end
                    .difference(
                      _range!.start,
                    )
                    .inDays;

                final blocked = _hasBlockedNight(
                  entries,
                  _range!.start,
                  nights,
                );

                if (blocked) {
                  return const _BookingAsideCard(
                    child: _MessageCard(
                      icon: Icons.block_outlined,
                      title: 'Fechas no disponibles',
                      message:
                          'Una o m\u00e1s noches seleccionadas est\u00e1n bloqueadas.',
                      error: true,
                    ),
                  );
                }

                if (nights < lodging.minNights) {
                  return _BookingAsideCard(
                    child: _MessageCard(
                      icon: Icons.nights_stay_outlined,
                      title: 'Estad\u00eda m\u00ednima',
                      message:
                          'Este alojamiento requiere una estad\u00eda m\u00ednima de ${lodging.minNights} noches.',
                      error: true,
                    ),
                  );
                }

                if (lodging.maxNights != null && nights > lodging.maxNights!) {
                  return _BookingAsideCard(
                    child: _MessageCard(
                      icon: Icons.event_busy_outlined,
                      title: 'Estad\u00eda m\u00e1xima',
                      message:
                          'Este alojamiento permite una estad\u00eda m\u00e1xima de ${lodging.maxNights} noches.',
                      error: true,
                    ),
                  );
                }

                final baseTotal = _calculateBaseTotal(
                  entries: entries,
                  start: _range!.start,
                  nights: nights,
                  standardPrice: lodging.pricePerNight,
                );

                final extraGuests = math.max(
                  _guests - lodging.includedGuests,
                  0,
                );

                final extraTotal =
                    extraGuests * lodging.extraGuestPrice * nights;

                final total = baseTotal + extraTotal;

                return _BookingAsideCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(
                                0xFFE3F2EA,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: RancoColors.forest,
                              size: 19,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fechas disponibles',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF2C4439,
                                    ),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Tu selecci\u00f3n est\u00e1 disponible.',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF718078,
                                    ),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      _SummaryCard(
                        range: _range!,
                        nights: nights,
                        baseTotal: baseTotal,
                        extraTotal: extraTotal,
                        total: total,
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      FilledButton.icon(
                        onPressed: _creating ? null : _confirmBooking,
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.event_available_outlined,
                              ),
                        label: Text(
                          _creating
                              ? 'Enviando solicitud...'
                              : 'Solicitar reserva',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: RancoColors.forest,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(
                            54,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 11,
                      ),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 15,
                            color: Color(
                              0xFF718078,
                            ),
                          ),
                          SizedBox(
                            width: 6,
                          ),
                          Expanded(
                            child: Text(
                              'No se realizar\u00e1 ning\u00fan cobro ahora. El anfitri\u00f3n debe aceptar la solicitud.',
                              style: TextStyle(
                                color: Color(
                                  0xFF718078,
                                ),
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }

          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Completa tu reserva',
                style: TextStyle(
                  color: Color(
                    0xFF263E34,
                  ),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              const Text(
                'Selecciona las fechas y quienes viajar\u00e1n.',
                style: TextStyle(
                  color: Color(
                    0xFF718078,
                  ),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              _BookingSection(
                number: '1',
                title: 'Elige tus fechas',
                primary: true,
                subtitle: 'Selecciona entrada y salida.',
                child: _DateSelectionBox(
                  range: _range,
                  onTap: _openDateSelector,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              _BookingSection(
                number: '2',
                title: 'Hu\u00e9spedes',
                subtitle: 'Hasta ${lodging.maxGuests} personas.',
                child: _GuestSelector(
                  value: _guests,
                  maxGuests: lodging.maxGuests,
                  onChanged: (
                    value,
                  ) {
                    setState(() {
                      _guests = value;
                    });
                  },
                ),
              ),
              if (_guests > lodging.includedGuests) ...[
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(
                    13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFFFF6E6,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: const Color(
                        0xFFF1DEB8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(
                          0xFF916B2D,
                        ),
                        size: 18,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          '${_guests - lodging.includedGuests} hu\u00e9sped adicional: ${_money(lodging.extraGuestPrice)} por persona y noche.',
                          style: const TextStyle(
                            color: Color(
                              0xFF765624,
                            ),
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(
                height: 12,
              ),
              _BookingSection(
                number: '3',
                title: 'Mensaje al anfitri\u00f3n',
                subtitle: 'Opcional',
                child: TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Ej: Llegaremos cerca de las 18:00.',
                    filled: true,
                    fillColor: const Color(
                      0xFFF5F8F6,
                    ),
                    contentPadding: const EdgeInsets.all(
                      15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      borderSide: const BorderSide(
                        color: Color(
                          0xFFE2EAE6,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      borderSide: const BorderSide(
                        color: RancoColors.forest,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          if (desktop) {
            return LayoutBuilder(
              builder: (
                context,
                viewport,
              ) {
                final availableWidth = math.min(
                  1180.0,
                  viewport.maxWidth - 44,
                );

                final availableHeight = viewport.maxHeight - 36;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: availableWidth,
                      height: availableHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PropertyHeader(
                            name: widget.business.name,
                            coverUrl: coverUrl,
                            price: lodging.pricePerNight,
                            maxGuests: lodging.maxGuests,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(
                                      bottom: 32,
                                    ),
                                    child: _BookingFormCard(
                                      child: form,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 20,
                                ),
                                SizedBox(
                                  width: 390,
                                  height: double.infinity,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(
                                      bottom: 24,
                                    ),
                                    child: bookingStatus(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              44,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PropertyHeader(
                      name: widget.business.name,
                      coverUrl: coverUrl,
                      price: lodging.pricePerNight,
                      maxGuests: lodging.maxGuests,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    _BookingFormCard(
                      child: form,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    bookingStatus(),
                    const SizedBox(
                      height: 24,
                    ),
                  ],
                ),
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
            Center(
          child: Text(
            'No pudimos cargar el alojamiento: $error',
          ),
        ),
      ),
    );
  }

  Future<void> _openDateSelector() async {
    final now = DateTime.now();

    final blockedDays = await ref
        .read(
          lodgingCalendarRepositoryProvider,
        )
        .listRange(
          businessId: widget.business.id,
          from: DateTime(
            now.year,
            now.month,
            now.day,
          ),
          to: DateTime(
            now.year + 1,
            now.month,
            now.day,
          ),
        );

    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CustomDateRangeSheet(
          initialRange: _range,
          blockedDays: blockedDays,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _range = selected;
    });
  }

  Future<void> _confirmBooking() async {
    final range = _range;

    if (range == null) {
      return;
    }

    final nights = range.end.difference(range.start).inDays;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.event_available_rounded,
            size: 46,
            color: RancoColors.forest,
          ),
          title: const Text(
            'Confirmar solicitud',
          ),
          content: Text(
            'Estás por solicitar una reserva para $nights ${nights == 1 ? 'noche' : 'noches'} y $_guests ${_guests == 1 ? 'huésped' : 'huéspedes'}.\n\nEl anfitrión deberá aceptar tu solicitud antes de que la reserva quede confirmada.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Volver',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: RancoColors.forest,
              ),
              child: const Text(
                'Confirmar solicitud',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _createBooking();
  }

  Future<void> _createBooking() async {
    final range = _range;

    if (range == null) {
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go('/sign-in');
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      await ref
          .read(
            lodgingBookingRepositoryProvider,
          )
          .create(
            businessId: widget.business.id,
            checkIn: range.start,
            checkOut: range.end,
            guests: _guests,
            message: _messageController.text,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: RancoColors.forest,
              size: 48,
            ),
            title: const Text(
              'Solicitud enviada',
            ),
            content: const Text(
              'El anfitrión recibió tu solicitud de reserva.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: RancoColors.forest,
                ),
                child: const Text(
                  'Entendido',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      context.go(
        '/business/${widget.business.id}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos crear la reserva: $error',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _creating = false;
      });
    }
  }

  static bool _hasBlockedNight(
    List<LodgingCalendarDay> entries,
    DateTime start,
    int nights,
  ) {
    for (var offset = 0; offset < nights; offset++) {
      final date = start.add(
        Duration(
          days: offset,
        ),
      );

      for (final entry in entries) {
        if (_sameDay(
              entry.date,
              date,
            ) &&
            entry.isBlocked) {
          return true;
        }
      }
    }

    return false;
  }

  static int _calculateBaseTotal({
    required List<LodgingCalendarDay> entries,
    required DateTime start,
    required int nights,
    required int standardPrice,
  }) {
    var total = 0;

    for (var offset = 0; offset < nights; offset++) {
      final date = start.add(
        Duration(
          days: offset,
        ),
      );

      LodgingCalendarDay? custom;

      for (final entry in entries) {
        if (_sameDay(
          entry.date,
          date,
        )) {
          custom = entry;
          break;
        }
      }

      total += custom?.priceOverride ?? standardPrice;
    }

    return total;
  }

  static bool _sameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateLabel(
    DateTime date,
  ) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _money(
    int value,
  ) {
    final raw = value.toString();

    final buffer = StringBuffer();

    for (var index = 0; index < raw.length; index++) {
      final remaining = raw.length - index;

      buffer.write(
        raw[index],
      );

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$${buffer.toString()}';
  }
}

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({
    required this.name,
    required this.coverUrl,
    required this.price,
    required this.maxGuests,
  });

  final String name;
  final String? coverUrl;
  final int price;
  final int maxGuests;

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop = constraints.maxWidth >= 760;

        if (!desktop) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                18,
              ),
              border: Border.all(
                color: const Color(
                  0xFFDDE7E2,
                ),
              ),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(
                      17,
                    ),
                  ),
                  child: SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: _PropertyImage(
                      coverUrl: coverUrl,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PropertyText(
                          name: name,
                          maxGuests: maxGuests,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      _PropertyPrice(
                        price: price,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 108,
          padding: const EdgeInsets.all(
            9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: const Color(
                0xFFDDE7E2,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  12,
                ),
                child: SizedBox(
                  width: 138,
                  height: double.infinity,
                  child: _PropertyImage(
                    coverUrl: coverUrl,
                  ),
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: _PropertyText(
                  name: name,
                  maxGuests: maxGuests,
                ),
              ),
              const SizedBox(
                width: 16,
              ),
              Container(
                width: 1,
                height: 58,
                color: const Color(
                  0xFFE5ECE8,
                ),
              ),
              const SizedBox(
                width: 18,
              ),
              _PropertyPrice(
                price: price,
              ),
              const SizedBox(
                width: 10,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PropertyImage extends StatelessWidget {
  const _PropertyImage({
    required this.coverUrl,
  });

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) {
      return const ColoredBox(
        color: Color(
          0xFFDDECE5,
        ),
        child: Center(
          child: Icon(
            Icons.holiday_village_outlined,
            size: 46,
            color: RancoColors.forest,
          ),
        ),
      );
    }

    return Image.network(
      coverUrl!,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return const ColoredBox(
          color: Color(
            0xFFDDECE5,
          ),
          child: Center(
            child: Icon(
              Icons.holiday_village_outlined,
              size: 46,
              color: RancoColors.forest,
            ),
          ),
        );
      },
    );
  }
}

class _PropertyText extends StatelessWidget {
  const _PropertyText({
    required this.name,
    required this.maxGuests,
  });

  final String name;
  final int maxGuests;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu alojamiento',
          style: TextStyle(
            color: RancoColors.forest,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(
              0xFF263E34,
            ),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 15,
              color: Color(
                0xFF718078,
              ),
            ),
            const SizedBox(
              width: 5,
            ),
            Text(
              'Hasta $maxGuests hu\u00e9spedes',
              style: const TextStyle(
                color: Color(
                  0xFF718078,
                ),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PropertyPrice extends StatelessWidget {
  const _PropertyPrice({
    required this.price,
  });

  final int price;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _LodgingAvailabilityScreenState._money(
            price,
          ),
          style: const TextStyle(
            color: RancoColors.forest,
            fontSize: 23,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        const Text(
          'por noche',
          style: TextStyle(
            color: Color(
              0xFF718078,
            ),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BookingFormCard extends StatelessWidget {
  const _BookingFormCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class _BookingAsideCard extends StatelessWidget {
  const _BookingAsideCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFD8E5DE,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF193B2F,
            ).withValues(
              alpha: .055,
            ),
            blurRadius: 28,
            offset: const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BookingSummaryIdle extends StatelessWidget {
  const _BookingSummaryIdle({
    required this.pricePerNight,
    required this.guests,
  });

  final int pricePerNight;
  final int guests;

  @override
  Widget build(BuildContext context) {
    return _BookingAsideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen de tu reserva',
            style: TextStyle(
              color: Color(
                0xFF263E34,
              ),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          const Text(
            'Completa las fechas para calcular el total.',
            style: TextStyle(
              color: Color(
                0xFF718078,
              ),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _LodgingAvailabilityScreenState._money(
                  pricePerNight,
                ),
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 5,
                  bottom: 2,
                ),
                child: Text(
                  '/ noche',
                  style: TextStyle(
                    color: Color(
                      0xFF718078,
                    ),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const Divider(
            height: 1,
            color: Color(
              0xFFE5ECE8,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const _BookingAsideLine(
            icon: Icons.calendar_month_outlined,
            label: 'Fechas',
            value: 'Seleccionar',
          ),
          const SizedBox(
            height: 13,
          ),
          _BookingAsideLine(
            icon: Icons.groups_outlined,
            label: 'Hu\u00e9spedes',
            value: '$guests',
          ),
          const SizedBox(
            height: 13,
          ),
          const _BookingAsideLine(
            icon: Icons.nights_stay_outlined,
            label: 'Noches',
            value: '\u2014',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 17,
            ),
            child: Divider(
              height: 1,
              color: Color(
                0xFFE5ECE8,
              ),
            ),
          ),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Total estimado',
                  style: TextStyle(
                    color: Color(
                      0xFF30443B,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '\u2014',
                style: TextStyle(
                  color: RancoColors.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(
              Icons.calendar_month_outlined,
            ),
            label: const Text(
              'Selecciona tus fechas',
            ),
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(
                0xFFDDE7E2,
              ),
              disabledForegroundColor: const Color(
                0xFF718078,
              ),
              minimumSize: const Size.fromHeight(
                52,
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 13,
          ),
          Container(
            padding: const EdgeInsets.all(
              12,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFF3F7F5,
              ),
              borderRadius: BorderRadius.circular(
                13,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: RancoColors.forest,
                ),
                SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    'No se realizar\u00e1 ning\u00fan cobro en este paso.',
                    style: TextStyle(
                      color: Color(
                        0xFF64766D,
                      ),
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
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

class _BookingAsideLine extends StatelessWidget {
  const _BookingAsideLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE8F3ED,
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
          width: 10,
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(
                0xFF6A7B73,
              ),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(
              0xFF30443B,
            ),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _BookingSection extends StatelessWidget {
  const _BookingSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    this.primary = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;
  final bool primary;

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 180,
      ),
      padding: EdgeInsets.all(
        primary ? 18 : 15,
      ),
      decoration: BoxDecoration(
        color: primary
            ? const Color(
                0xFFF8FCFA,
              )
            : const Color(
                0xFFFCFDFC,
              ),
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: primary
              ? const Color(
                  0xFFBFD9CC,
                )
              : const Color(
                  0xFFE3EAE6,
                ),
          width: primary ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: primary ? 32 : 29,
                height: primary ? 32 : 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary
                      ? RancoColors.forest
                      : const Color(
                          0xFFE2F2EA,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: primary ? Colors.white : RancoColors.forest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: const Color(
                          0xFF30443B,
                        ),
                        fontSize: primary ? 16 : 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(
                          0xFF7A8982,
                        ),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (primary) const _RequiredPill(),
            ],
          ),
          SizedBox(
            height: primary ? 16 : 13,
          ),
          child,
        ],
      ),
    );
  }
}

class _RequiredPill extends StatelessWidget {
  const _RequiredPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE6F2EB,
        ),
        borderRadius: BorderRadius.circular(
          99,
        ),
      ),
      child: const Text(
        'Obligatorio',
        style: TextStyle(
          color: RancoColors.forest,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DateSelectionBox extends StatelessWidget {
  const _DateSelectionBox({
    required this.range,
    required this.onTap,
  });

  final DateTimeRange? range;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        15,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: const Color(
            0xFFF3F7F5,
          ),
          borderRadius: BorderRadius.circular(
            15,
          ),
        ),
        child: range == null
            ? const Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: RancoColors.forest,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      'Seleccionar fechas',
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _DateMini(
                      label: 'ENTRADA',
                      value: _LodgingAvailabilityScreenState._dateLabel(
                        range!.start,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(
                      0xFF708078,
                    ),
                  ),
                  Expanded(
                    child: _DateMini(
                      label: 'SALIDA',
                      value: _LodgingAvailabilityScreenState._dateLabel(
                        range!.end,
                      ),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DateMini extends StatelessWidget {
  const _DateMini({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(
              0xFF718078,
            ),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(
              0xFF30443B,
            ),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _GuestSelector extends StatelessWidget {
  const _GuestSelector({
    required this.value,
    required this.maxGuests,
    required this.onChanged,
  });

  final int value;
  final int maxGuests;
  final ValueChanged<int> onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF3F7F5,
        ),
        borderRadius: BorderRadius.circular(
          15,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            color: RancoColors.forest,
          ),
          const SizedBox(
            width: 10,
          ),
          const Expanded(
            child: Text(
              'Personas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.outlined(
            onPressed: value > 1
                ? () {
                    onChanged(
                      value - 1,
                    );
                  }
                : null,
            icon: const Icon(
              Icons.remove_rounded,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: value < maxGuests
                ? () {
                    onChanged(
                      value + 1,
                    );
                  }
                : null,
            style: IconButton.styleFrom(
              backgroundColor: RancoColors.forest,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(
              Icons.add_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomDateRangeSheet extends StatefulWidget {
  const _CustomDateRangeSheet({
    required this.initialRange,
    required this.blockedDays,
  });

  final DateTimeRange? initialRange;

  final List<LodgingCalendarDay> blockedDays;

  @override
  State<_CustomDateRangeSheet> createState() => _CustomDateRangeSheetState();
}

class _CustomDateRangeSheetState extends State<_CustomDateRangeSheet> {
  late DateTime _month;

  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();

    final base = widget.initialRange?.start ?? DateTime.now();

    _month = DateTime(
      base.year,
      base.month,
    );

    _start = widget.initialRange?.start;

    _end = widget.initialRange?.end;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: MediaQuery.sizeOf(
            context,
          ).height *
          .78,
      decoration: const BoxDecoration(
        color: Color(
          0xFFF9FBFA,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            26,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFD0D9D4,
                ),
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                10,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elige tus fechas',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Selecciona entrada y salida',
                          style: TextStyle(
                            color: Color(
                              0xFF718078,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),
            if (_start != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(
                    13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFE4F2EB,
                    ),
                    borderRadius: BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DateMini(
                          label: 'ENTRADA',
                          value: _LodgingAvailabilityScreenState._dateLabel(
                            _start!,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: RancoColors.forest,
                      ),
                      Expanded(
                        child: _DateMini(
                          label: 'SALIDA',
                          value: _end == null
                              ? 'Selecciona'
                              : _LodgingAvailabilityScreenState._dateLabel(
                                  _end!,
                                ),
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _month = DateTime(
                          _month.year,
                          _month.month - 1,
                        );
                      });
                    },
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _monthLabel(
                        _month,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _month = DateTime(
                          _month.year,
                          _month.month + 1,
                        );
                      });
                    },
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: Row(
                children: [
                  _DayHeader(
                    'L',
                  ),
                  _DayHeader(
                    'M',
                  ),
                  _DayHeader(
                    'M',
                  ),
                  _DayHeader(
                    'J',
                  ),
                  _DayHeader(
                    'V',
                  ),
                  _DayHeader(
                    'S',
                  ),
                  _DayHeader(
                    'D',
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: _MonthSelectorGrid(
                  month: _month,
                  start: _start,
                  end: _end,
                  blockedDays: widget.blockedDays,
                  onDateSelected: _selectDate,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                16,
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CalendarLegend(
                        color: Color(
                          0xFFE4F2EB,
                        ),
                        label: 'Disponible',
                      ),
                      SizedBox(
                        width: 14,
                      ),
                      _CalendarLegend(
                        color: Color(
                          0xFFFFE4DE,
                        ),
                        label: 'No disponible',
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  FilledButton(
                    onPressed: _start != null && _end != null
                        ? () {
                            Navigator.pop(
                              context,
                              DateTimeRange(
                                start: _start!,
                                end: _end!,
                              ),
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        52,
                      ),
                      backgroundColor: RancoColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    child: Text(
                      _end == null
                          ? 'Selecciona la fecha de salida'
                          : 'Confirmar fechas',
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

  void _selectDate(
    DateTime date,
  ) {
    if (_isBlocked(
      date,
    )) {
      return;
    }

    setState(() {
      if (_start == null ||
          _end != null ||
          date.isBefore(
            _start!,
          )) {
        _start = date;
        _end = null;
        return;
      }

      if (_containsBlockedDate(
        _start!,
        date,
      )) {
        _start = date;
        _end = null;
        return;
      }

      _end = date;
    });
  }

  bool _isBlocked(
    DateTime date,
  ) {
    for (final item in widget.blockedDays) {
      if (item.isBlocked &&
          _sameDate(
            item.date,
            date,
          )) {
        return true;
      }
    }

    return false;
  }

  bool _containsBlockedDate(
    DateTime start,
    DateTime end,
  ) {
    var current = start;

    while (current.isBefore(
      end,
    )) {
      if (_isBlocked(
        current,
      )) {
        return true;
      }

      current = current.add(
        const Duration(
          days: 1,
        ),
      );
    }

    return false;
  }

  static bool _sameDate(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _monthLabel(
    DateTime value,
  ) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return '${months[value.month - 1]} ${value.year}';
  }
}

class _MonthSelectorGrid extends StatelessWidget {
  const _MonthSelectorGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.blockedDays,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final List<LodgingCalendarDay> blockedDays;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(
    BuildContext context,
  ) {
    final first = DateTime(
      month.year,
      month.month,
      1,
    );

    final count = DateTime(
      month.year,
      month.month + 1,
      0,
    ).day;

    final offset = first.weekday - 1;

    final total = offset + count;

    final rows = (total / 7).ceil();

    final cells = rows * 7;

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        final day = index - offset + 1;

        if (day < 1 || day > count) {
          return const SizedBox();
        }

        final date = DateTime(
          month.year,
          month.month,
          day,
        );

        final isPast = date.isBefore(
          todayDate,
        );

        final blocked = _isBlocked(
          date,
        );

        final isStart = start != null &&
            _sameDate(
              date,
              start!,
            );

        final isEnd = end != null &&
            _sameDate(
              date,
              end!,
            );

        final inRange = start != null &&
            end != null &&
            date.isAfter(
              start!,
            ) &&
            date.isBefore(
              end!,
            );

        Color background = Colors.transparent;

        Color textColor = const Color(
          0xFF30443B,
        );

        if (blocked) {
          background = const Color(
            0xFFFFE4DE,
          );
          textColor = const Color(
            0xFFAE5A47,
          );
        }

        if (inRange) {
          background = const Color(
            0xFFDDF1E7,
          );
        }

        if (isStart || isEnd) {
          background = RancoColors.forest;
          textColor = Colors.white;
        }

        if (isPast) {
          textColor = const Color(
            0xFFB4BBB7,
          );
        }

        return InkWell(
          onTap: isPast || blocked
              ? null
              : () {
                  onDateSelected(
                    date,
                  );
                },
          borderRadius: BorderRadius.circular(
            12,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontWeight:
                    isStart || isEnd ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isBlocked(
    DateTime date,
  ) {
    for (final item in blockedDays) {
      if (item.isBlocked &&
          _sameDate(
            item.date,
            date,
          )) {
        return true;
      }
    }

    return false;
  }

  static bool _sameDate(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(
    this.label,
  );

  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(
            0xFF718078,
          ),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              4,
            ),
          ),
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(
              0xFF718078,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.range,
    required this.nights,
    required this.baseTotal,
    required this.extraTotal,
    required this.total,
  });

  final DateTimeRange range;
  final int nights;
  final int baseTotal;
  final int extraTotal;
  final int total;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen',
          style: TextStyle(
            color: Color(
              0xFF263E34,
            ),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 15,
        ),
        _SummaryRow(
          label:
              '${_LodgingAvailabilityScreenState._dateLabel(range.start)} - ${_LodgingAvailabilityScreenState._dateLabel(range.end)}',
          value: '$nights ${nights == 1 ? 'noche' : 'noches'}',
        ),
        const SizedBox(
          height: 11,
        ),
        _SummaryRow(
          label: 'Alojamiento',
          value: _LodgingAvailabilityScreenState._money(
            baseTotal,
          ),
        ),
        if (extraTotal > 0) ...[
          const SizedBox(
            height: 11,
          ),
          _SummaryRow(
            label: 'Hu\u00e9spedes adicionales',
            value: _LodgingAvailabilityScreenState._money(
              extraTotal,
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 16,
          ),
          child: Divider(
            height: 1,
            color: Color(
              0xFFE3EAE6,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Total estad\u00eda',
                style: TextStyle(
                  color: Color(
                    0xFF263E34,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              _LodgingAvailabilityScreenState._money(
                total,
              ),
              style: const TextStyle(
                color: RancoColors.forest,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(
                0xFF66786F,
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
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: error
            ? const Color(
                0xFFFFEBE6,
              )
            : const Color(
                0xFFE2F3EA,
              ),
        borderRadius: BorderRadius.circular(
          17,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: error
                ? const Color(
                    0xFFB65742,
                  )
                : RancoColors.forest,
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
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
