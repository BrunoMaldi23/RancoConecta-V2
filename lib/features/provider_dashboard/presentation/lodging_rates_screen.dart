import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/lodging_details_repository.dart';

class LodgingRatesScreen extends ConsumerStatefulWidget {
  const LodgingRatesScreen({
    super.key,
  });

  @override
  ConsumerState<LodgingRatesScreen> createState() => _LodgingRatesScreenState();
}

class _LodgingRatesScreenState extends ConsumerState<LodgingRatesScreen> {
  final _formKey = GlobalKey<FormState>();

  final _price = TextEditingController();

  final _included = TextEditingController();

  final _extra = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _included.dispose();
    _extra.dispose();
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
          'Tarifas',
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
                    Container(
                      padding: const EdgeInsets.all(
                        18,
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
                          const Text(
                            'Tarifa base',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Precio por noche',
                              prefixText: '\$ ',
                            ),
                            validator: _positive,
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          TextFormField(
                            controller: _included,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Personas incluidas',
                            ),
                            validator: _positive,
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          TextFormField(
                            controller: _extra,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Valor por persona adicional',
                              prefixText: '\$ ',
                            ),
                            validator: _zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 18,
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
                        'Guardar tarifas',
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

    _price.text = details.pricePerNight.toString();

    _included.text = details.includedGuests.toString();

    _extra.text = details.extraGuestPrice.toString();
  }

  String? _positive(
    String? value,
  ) {
    final number = int.tryParse(
      value ?? '',
    );

    if (number == null || number < 1) {
      return 'Valor invalido';
    }

    return null;
  }

  String? _zero(
    String? value,
  ) {
    final number = int.tryParse(
      value ?? '',
    );

    if (number == null || number < 0) {
      return 'Valor invalido';
    }

    return null;
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
          .updateRates(
            businessId: businessId,
            pricePerNight: int.parse(
              _price.text,
            ),
            includedGuests: int.parse(
              _included.text,
            ),
            extraGuestPrice: int.parse(
              _extra.text,
            ),
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
            'Tarifas actualizadas.',
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
