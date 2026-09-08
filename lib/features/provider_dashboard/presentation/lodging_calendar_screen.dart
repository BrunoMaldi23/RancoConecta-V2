import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/lodging_calendar_repository.dart';

class LodgingCalendarScreen extends ConsumerStatefulWidget {
  const LodgingCalendarScreen({
    super.key,
  });

  @override
  ConsumerState<LodgingCalendarScreen> createState() =>
      _LodgingCalendarScreenState();
}

class _LodgingCalendarScreenState extends ConsumerState<LodgingCalendarScreen> {
  DateTime _month = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(
    BuildContext context,
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
          'Calendario',
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

          final request = (
            businessId: business.id,
            year: _month.year,
            month: _month.month,
          );

          final calendar = ref.watch(
            lodgingCalendarMonthProvider(
              request,
            ),
          );

          return calendar.when(
            data: (days) {
              return ListView(
                padding: const EdgeInsets.all(
                  18,
                ),
                children: [
                  const Text(
                    'Disponibilidad',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  const Text(
                    'Bloquea dias en los que no recibirás reservas o agrega una tarifa especial.',
                    style: TextStyle(
                      color: Color(
                        0xFF697A72,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding: const EdgeInsets.all(
                      14,
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
                      children: [
                        Row(
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
                        const SizedBox(
                          height: 8,
                        ),
                        const Row(
                          children: [
                            _WeekLabel(
                              'L',
                            ),
                            _WeekLabel(
                              'M',
                            ),
                            _WeekLabel(
                              'M',
                            ),
                            _WeekLabel(
                              'J',
                            ),
                            _WeekLabel(
                              'V',
                            ),
                            _WeekLabel(
                              'S',
                            ),
                            _WeekLabel(
                              'D',
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        _MonthGrid(
                          month: _month,
                          days: days,
                          onTap: (date) {
                            _editDay(
                              context,
                              business.id,
                              date,
                              _findDay(
                                days,
                                date,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Legend(
                        color: Color(
                          0xFFE2F3EA,
                        ),
                        label: 'Disponible',
                      ),
                      _Legend(
                        color: Color(
                          0xFFFFE5DF,
                        ),
                        label: 'Bloqueado',
                      ),
                      _Legend(
                        color: Color(
                          0xFFFFF1D6,
                        ),
                        label: 'Tarifa especial',
                      ),
                    ],
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
                Center(
              child: Text(
                'No pudimos cargar el calendario: $error',
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
            'No pudimos cargar el negocio.',
          ),
        ),
      ),
    );
  }

  Future<void> _editDay(
    BuildContext context,
    String businessId,
    DateTime date,
    LodgingCalendarDay? current,
  ) async {
    var status = current?.status ?? LodgingDayStatus.available;

    final price = TextEditingController(
      text: current?.priceOverride?.toString() ?? '',
    );

    final note = TextEditingController(
      text: current?.note ?? '',
    );

    final result = await showModalBottomSheet<_CalendarEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(
                      context,
                    ).bottom +
                    20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullDate(
                      date,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  SegmentedButton<LodgingDayStatus>(
                    segments: const [
                      ButtonSegment(
                        value: LodgingDayStatus.available,
                        icon: Icon(
                          Icons.check_circle_outline,
                        ),
                        label: Text(
                          'Disponible',
                        ),
                      ),
                      ButtonSegment(
                        value: LodgingDayStatus.blocked,
                        icon: Icon(
                          Icons.block_outlined,
                        ),
                        label: Text(
                          'Bloqueado',
                        ),
                      ),
                    ],
                    selected: {
                      status,
                    },
                    onSelectionChanged: (values) {
                      setModalState(() {
                        status = values.first;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tarifa especial',
                      prefixText: '\$ ',
                      hintText: 'Opcional',
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nota privada',
                      hintText: 'Ej: mantenimiento',
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  Row(
                    children: [
                      if (current != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                const _CalendarEditResult(
                                  reset: true,
                                ),
                              );
                            },
                            child: const Text(
                              'Restablecer',
                            ),
                          ),
                        ),
                      if (current != null)
                        const SizedBox(
                          width: 10,
                        ),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              _CalendarEditResult(
                                status: status,
                                priceOverride: int.tryParse(
                                  price.text,
                                ),
                                note: note.text,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: RancoColors.forest,
                          ),
                          child: const Text(
                            'Guardar',
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
      },
    );

    price.dispose();
    note.dispose();

    if (result == null) {
      return;
    }

    final repository = ref.read(
      lodgingCalendarRepositoryProvider,
    );

    try {
      if (result.reset) {
        await repository.resetDay(
          businessId: businessId,
          date: date,
        );
      }

      if (!result.reset) {
        await repository.saveDay(
          businessId: businessId,
          date: date,
          status: result.status ?? LodgingDayStatus.available,
          priceOverride: result.priceOverride,
          note: result.note,
        );
      }

      ref.invalidate(
        lodgingCalendarMonthProvider(
          (
            businessId: businessId,
            year: _month.year,
            month: _month.month,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              'No pudimos guardar: $error',
            ),
          ),
        );
      }
    }
  }

  static LodgingCalendarDay? _findDay(
    List<LodgingCalendarDay> days,
    DateTime date,
  ) {
    for (final item in days) {
      if (_sameDate(
        item.date,
        date,
      )) {
        return item;
      }
    }

    return null;
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

  static String _fullDate(
    DateTime value,
  ) {
    return '${value.day} de ${_monthLabel(value).split(' ').first} de ${value.year}';
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.days,
    required this.onTap,
  });

  final DateTime month;
  final List<LodgingCalendarDay> days;
  final ValueChanged<DateTime> onTap;

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

    return GridView.builder(
      shrinkWrap: true,
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
        final dayNumber = index - offset + 1;

        if (dayNumber < 1 || dayNumber > count) {
          return const SizedBox();
        }

        final date = DateTime(
          month.year,
          month.month,
          dayNumber,
        );

        LodgingCalendarDay? item;

        for (final candidate in days) {
          if (candidate.date.year == date.year &&
              candidate.date.month == date.month &&
              candidate.date.day == date.day) {
            item = candidate;
            break;
          }
        }

        final isPast = date.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );

        Color background = const Color(
          0xFFE2F3EA,
        );

        if (item?.isBlocked == true) {
          background = const Color(
            0xFFFFE5DF,
          );
        }

        if (item?.priceOverride != null && item?.isBlocked != true) {
          background = const Color(
            0xFFFFF1D6,
          );
        }

        if (isPast) {
          background = const Color(
            0xFFF0F2F1,
          );
        }

        return InkWell(
          onTap: isPast
              ? null
              : () {
                  onTap(
                    date,
                  );
                },
          borderRadius: BorderRadius.circular(
            10,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(
                10,
              ),
            ),
            child: Text(
              '$dayNumber',
              style: TextStyle(
                color: isPast
                    ? const Color(
                        0xFFABB3AF,
                      )
                    : const Color(
                        0xFF30443B,
                      ),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(
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
            0xFF708078,
          ),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
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
          width: 13,
          height: 13,
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
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CalendarEditResult {
  const _CalendarEditResult({
    this.status,
    this.priceOverride,
    this.note,
    this.reset = false,
  });

  final LodgingDayStatus? status;
  final int? priceOverride;
  final String? note;
  final bool reset;
}
