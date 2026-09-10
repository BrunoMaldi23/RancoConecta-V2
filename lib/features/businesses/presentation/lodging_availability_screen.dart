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
        0xFFEAF4F0,
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
        title: const Text(
          'Reservar',
        ),
      ),
      body: details.when(
        data: (lodging) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              32,
            ),
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
              _BookingSection(
                number: '1',
                title: 'Elige tus fechas',
                subtitle: 'Selecciona la entrada y la salida.',
                child: _DateSelectionBox(
                  range: _range,
                  onTap: () {
                    _openDateSelector();
                  },
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              _BookingSection(
                number: '2',
                title: 'Huéspedes',
                subtitle: 'Máximo ${lodging.maxGuests} personas.',
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
                      0xFFFFF3D9,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(
                          0xFF8A611F,
                        ),
                        size: 18,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          '${_guests - lodging.includedGuests} huésped adicional: ${_money(lodging.extraGuestPrice)} por persona y noche.',
                          style: const TextStyle(
                            color: Color(
                              0xFF7A581F,
                            ),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(
                height: 14,
              ),
              _BookingSection(
                number: '3',
                title: 'Mensaje al anfitrión',
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
                      0xFFF3F6F4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        15,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        15,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        15,
                      ),
                      borderSide: const BorderSide(
                        color: RancoColors.forest,
                      ),
                    ),
                  ),
                ),
              ),
              if (_range != null) ...[
                const SizedBox(
                  height: 14,
                ),
                FutureBuilder<List<LodgingCalendarDay>>(
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
                      return const Padding(
                        padding: EdgeInsets.all(
                          24,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MessageCard(
                        icon: Icons.error_outline,
                        title: 'No pudimos revisar las fechas',
                        message: '${snapshot.error}',
                        error: true,
                      );
                    }

                    final entries =
                        snapshot.data ?? const <LodgingCalendarDay>[];

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
                      return const _MessageCard(
                        icon: Icons.block_outlined,
                        title: 'Fechas no disponibles',
                        message:
                            'Una o más noches seleccionadas están bloqueadas.',
                        error: true,
                      );
                    }

                    if (nights < lodging.minNights) {
                      return _MessageCard(
                        icon: Icons.nights_stay_outlined,
                        title: 'Estadía mínima',
                        message:
                            'Este alojamiento exige al menos ${lodging.minNights} noches.',
                        error: true,
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

                    return Column(
                      children: [
                        _MessageCard(
                          icon: Icons.check_circle_outline,
                          title: 'Fechas disponibles',
                          message:
                              '$nights ${nights == 1 ? 'noche' : 'noches'} · $_guests ${_guests == 1 ? 'huésped' : 'huéspedes'}',
                        ),
                        const SizedBox(
                          height: 12,
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
                            _creating ? 'Enviando solicitud...' : 'Continuar',
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
                        const SizedBox(
                          height: 10,
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Color(
                                0xFF718078,
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Flexible(
                              child: Text(
                                'La solicitud quedará pendiente hasta que el anfitrión la confirme.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(
                                    0xFF718078,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
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
            'Estas por solicitar una reserva para $nights ${nights == 1 ? 'noche' : 'noches'} y $_guests ${_guests == 1 ? 'huesped' : 'huespedes'}.\n\nEl anfitrion debera aceptar tu solicitud antes de que la reserva quede confirmada.',
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          22,
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(
                21,
              ),
            ),
            child: SizedBox(
              height: 145,
              width: double.infinity,
              child: coverUrl != null
                  ? Image.network(
                      coverUrl!,
                      fit: BoxFit.cover,
                    )
                  : const ColoredBox(
                      color: Color(
                        0xFFDDECE5,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.holiday_village_outlined,
                          size: 52,
                          color: RancoColors.forest,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(
                            0xFF2E4239,
                          ),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Hasta $maxGuests huéspedes',
                        style: const TextStyle(
                          color: Color(
                            0xFF708078,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _LodgingAvailabilityScreenState._money(
                        price,
                      ),
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'por noche',
                      style: TextStyle(
                        color: Color(
                          0xFF708078,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSection extends StatelessWidget {
  const _BookingSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(
        17,
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(
                    0xFFE2F2EA,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: RancoColors.forest,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(
                          0xFF718078,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          child,
        ],
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
            0xFFD5E2DC,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          _SummaryRow(
            label:
                '${_LodgingAvailabilityScreenState._dateLabel(range.start)} → ${_LodgingAvailabilityScreenState._dateLabel(range.end)}',
            value: '$nights noches',
          ),
          const SizedBox(
            height: 9,
          ),
          _SummaryRow(
            label: 'Alojamiento',
            value: _LodgingAvailabilityScreenState._money(
              baseTotal,
            ),
          ),
          if (extraTotal > 0) ...[
            const SizedBox(
              height: 9,
            ),
            _SummaryRow(
              label: 'Huéspedes adicionales',
              value: _LodgingAvailabilityScreenState._money(
                extraTotal,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Divider(
              height: 1,
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total estadía',
                  style: TextStyle(
                    fontSize: 17,
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
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
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
