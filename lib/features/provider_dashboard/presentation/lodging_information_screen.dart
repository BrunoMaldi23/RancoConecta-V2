import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/lodging_details_repository.dart';

class LodgingInformationScreen extends ConsumerStatefulWidget {
  const LodgingInformationScreen({
    super.key,
  });

  @override
  ConsumerState<LodgingInformationScreen> createState() =>
      _LodgingInformationScreenState();
}

class _LodgingInformationScreenState
    extends ConsumerState<LodgingInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _maxGuests = TextEditingController();

  final _includedGuests = TextEditingController();

  final _bedrooms = TextEditingController();

  final _beds = TextEditingController();

  final _bathrooms = TextEditingController();

  final _checkIn = TextEditingController();

  final _checkOut = TextEditingController();

  final _minNights = TextEditingController();

  final _cancellation = TextEditingController();

  final _rules = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _maxGuests.dispose();
    _includedGuests.dispose();
    _bedrooms.dispose();
    _beds.dispose();
    _bathrooms.dispose();
    _checkIn.dispose();
    _checkOut.dispose();
    _minNights.dispose();
    _cancellation.dispose();
    _rules.dispose();
    super.dispose();
  }

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
          'Informacion del alojamiento',
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

          final details = ref.watch(
            lodgingDetailsProvider(
              business.id,
            ),
          );

          return details.when(
            data: (details) {
              _load(
                details,
              );

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(
                    18,
                  ),
                  children: [
                    _Card(
                      title: 'Capacidad',
                      children: [
                        _NumberField(
                          controller: _maxGuests,
                          label: 'Maximo de huespedes',
                        ),
                        _NumberField(
                          controller: _includedGuests,
                          label: 'Huespedes incluidos',
                        ),
                      ],
                    ),
                    _Card(
                      title: 'Distribucion',
                      children: [
                        _NumberField(
                          controller: _bedrooms,
                          label: 'Dormitorios',
                        ),
                        _NumberField(
                          controller: _beds,
                          label: 'Camas',
                        ),
                        _DecimalField(
                          controller: _bathrooms,
                          label: 'Banos',
                        ),
                      ],
                    ),
                    _Card(
                      title: 'Ingreso y salida',
                      children: [
                        _TextField(
                          controller: _checkIn,
                          label: 'Check-in',
                        ),
                        _TextField(
                          controller: _checkOut,
                          label: 'Check-out',
                        ),
                        _NumberField(
                          controller: _minNights,
                          label: 'Estadia minima',
                        ),
                      ],
                    ),
                    _Card(
                      title: 'Politicas',
                      children: [
                        _TextArea(
                          controller: _cancellation,
                          label: 'Politica de cancelacion',
                        ),
                        _TextArea(
                          controller: _rules,
                          label: 'Reglas del alojamiento',
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              _save(
                                business.id,
                              );
                            },
                      icon: const Icon(
                        Icons.save_outlined,
                      ),
                      label: const Text(
                        'Guardar cambios',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        minimumSize: const Size.fromHeight(
                          52,
                        ),
                      ),
                    ),
                  ],
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
                'Error: $error',
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

  void _load(
    LodgingDetails details,
  ) {
    if (_loaded) {
      return;
    }

    _loaded = true;

    _maxGuests.text = details.maxGuests.toString();

    _includedGuests.text = details.includedGuests.toString();

    _bedrooms.text = details.bedrooms.toString();

    _beds.text = details.beds.toString();

    _bathrooms.text = details.bathrooms.toStringAsFixed(
      1,
    );

    _checkIn.text = details.checkInTime;

    _checkOut.text = details.checkOutTime;

    _minNights.text = details.minNights.toString();

    _cancellation.text = details.cancellationPolicy;

    _rules.text = details.houseRules;
  }

  Future<void> _save(
    String businessId,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(
            lodgingDetailsRepositoryProvider,
          )
          .updateInformation(
            businessId: businessId,
            maxGuests: int.parse(
              _maxGuests.text,
            ),
            includedGuests: int.parse(
              _includedGuests.text,
            ),
            bedrooms: int.parse(
              _bedrooms.text,
            ),
            beds: int.parse(
              _beds.text,
            ),
            bathrooms: double.parse(
              _bathrooms.text.replaceAll(
                ',',
                '.',
              ),
            ),
            checkInTime: _checkIn.text.trim(),
            checkOutTime: _checkOut.text.trim(),
            minNights: int.parse(
              _minNights.text,
            ),
            cancellationPolicy: _cancellation.text,
            houseRules: _rules.text,
          );

      ref.invalidate(
        lodgingDetailsProvider(
          businessId,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Informacion guardada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos guardar: $error',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(
                height: 12,
              ),
          ],
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
      ),
      validator: (value) {
        final number = int.tryParse(
          value ?? '',
        );

        if (number == null || number < 1) {
          return 'Valor invalido';
        }

        return null;
      },
    );
  }
}

class _DecimalField extends StatelessWidget {
  const _DecimalField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:mm',
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      minLines: 3,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
      ),
    );
  }
}
