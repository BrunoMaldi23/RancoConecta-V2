import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/gastronomy_repository.dart';

class TableReservationScreen extends ConsumerStatefulWidget {
  const TableReservationScreen({
    required this.businessId,
    super.key,
  });

  final String businessId;

  @override
  ConsumerState<TableReservationScreen> createState() =>
      _TableReservationScreenState();
}

class _TableReservationScreenState
    extends ConsumerState<TableReservationScreen> {
  DateTime? _date;
  final _time = TextEditingController();
  final _guests = TextEditingController(text: '2');
  final _message = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _time.dispose();
    _guests.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: const RancoAppBar(
        title: 'Reserva de mesa',
        fallbackRoute: '/explore',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD5E2DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Solicitar mesa',
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'El restaurante confirmará o rechazará tu solicitud. No se realizará ningún cobro.',
                      style: TextStyle(color: Color(0xFF61736A), height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _date == null
                            ? 'Seleccionar fecha'
                            : '${_date!.day}/${_date!.month}/${_date!.year}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _time,
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        hintText: '20:30',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _guests,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Comensales',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _message,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje opcional',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_seat_outlined),
                      label: const Text('Enviar solicitud'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        minimumSize: const Size.fromHeight(52),
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
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 180)),
      initialDate: _date ?? today,
    );

    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final next = '/business/${widget.businessId}/table-reservation';

    if (user == null) {
      context.go(
        Uri(path: '/sign-in', queryParameters: {'next': next}).toString(),
      );
      return;
    }

    final date = _date;
    final guests = int.tryParse(_guests.text.trim());
    final time = _time.text.trim();

    if (date == null || guests == null || guests < 1 || !_validTime(time)) {
      _snack('Revisa fecha, hora y comensales.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(gastronomyRepositoryProvider).createReservation(
            businessId: widget.businessId,
            date: date,
            time: time,
            guests: guests,
            message: _message.text,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: const Text(
            'El restaurante recibió tu solicitud de reserva.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      );

      if (mounted) {
        context.go('/business/${widget.businessId}');
      }
    } catch (error) {
      if (mounted) {
        _snack('No pudimos enviar la solicitud: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _validTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
