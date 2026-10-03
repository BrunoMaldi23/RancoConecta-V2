import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const termsVersion = '2026-10-01';
const privacyVersion = '2026-10-01';

class ConsentFields extends StatelessWidget {
  const ConsentFields({
    required this.terms,
    required this.privacy,
    required this.dataProcessing,
    required this.onTerms,
    required this.onPrivacy,
    required this.onDataProcessing,
    super.key,
  });

  final bool terms;
  final bool privacy;
  final bool dataProcessing;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool> onDataProcessing;

  @override
  Widget build(BuildContext context) => Material(
        // Material propio: los CheckboxListTile pintan su feedback aquí.
        color: const Color(0xFFF7FBF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDCE8E0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text(
                  'Consentimientos',
                  style: TextStyle(
                    color: Color(0xFF183027),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ConsentRow(
                value: terms,
                onChanged: onTerms,
                label: 'Acepto los términos y condiciones',
              ),
              _ConsentRow(
                value: privacy,
                onChanged: onPrivacy,
                label: 'Acepto la política de privacidad',
              ),
              _ConsentRow(
                value: dataProcessing,
                onChanged: onDataProcessing,
                label: 'Autorizo el tratamiento de mis datos personales',
              ),
              // Enlaces fuera de las filas: tocar una fila nunca navega.
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 12, 6),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Lee los ', style: _hint),
                    _ConsentLink(
                      label: 'Términos y condiciones',
                      route: '/terminos',
                    ),
                    Text(' y la ', style: _hint),
                    _ConsentLink(
                      label: 'Política de privacidad',
                      route: '/politica-privacidad',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

const _hint = TextStyle(color: Color(0xFF64786F), fontSize: 13);

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF183027),
            fontSize: 13.5,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      );
}

class _ConsentLink extends StatelessWidget {
  const _ConsentLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.push(route),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF145A3A),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      );
}
