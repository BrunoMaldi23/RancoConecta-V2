import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../auth/data/supabase_auth_repository.dart';

class ProviderRegistrationScreen extends ConsumerStatefulWidget {
  const ProviderRegistrationScreen({
    super.key,
  });

  @override
  ConsumerState<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends ConsumerState<ProviderRegistrationScreen> {
  final _pageController = PageController();

  int _step = 0;
  bool _loading = false;
  bool _obscurePassword = true;

  String? _error;
  String? _successMessage;

  final _accountKey = GlobalKey<FormState>();
  final _businessKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  String _publicationType = 'service';
  String _location = 'Lago Ranco';
  String _membership = 'basic';

  final List<String> _coverage = [
    'Lago Ranco',
  ];

  static const _locations = [
    'Lago Ranco',
    'Futrono',
    'Riñinahue',
    'Llifen',
    'Calcurrupe',
    'Maihue',
    'Dollinco',
    'Caunahue',
    'Curriñe',
    'Cerrillos',
    'Notuela',
  ];

  static const _steps = [
    'Cuenta',
    'Publicación',
    'Cobertura',
    'Membresía',
    'Confirmación',
  ];

  @override
  void dispose() {
    _pageController.dispose();

    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _businessNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF4F0),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Inscribir mi servicio',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              context.go('/');
            },
            icon: const Icon(
              Icons.home_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _ProgressHeader(
                  step: _step,
                  steps: _steps,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _accountStep(),
                      _publicationStep(),
                      _coverageStep(),
                      _membershipStep(),
                      _confirmationStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountStep() {
    return _RegistrationPage(
      title: 'Registra tus datos',
      subtitle: 'Estos datos se utilizarán para administrar tu publicación.',
      child: Form(
        key: _accountKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Nombre'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Tu nombre',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu nombre.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Correo'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'tu@correo.cl',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                ),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            const _Label('Contraseña'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Mínimo 8 caracteres',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Usa al menos 8 caracteres.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label(
              'Confirmar contraseña',
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(
                hintText: 'Repite tu contraseña',
                prefixIcon: Icon(
                  Icons.lock_reset_outlined,
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden.';
                }

                return null;
              },
            ),
            const SizedBox(height: 26),
            _NextButton(
              text: 'Continuar',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _publicationStep() {
    return _RegistrationPage(
      title: '¿Qué quieres publicar?',
      subtitle: 'Selecciona el tipo que mejor representa tu actividad.',
      child: Form(
        key: _businessKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _TypeCard(
                  selected: _publicationType == 'service',
                  icon: Icons.handyman_outlined,
                  title: 'Oficio o servicio',
                  subtitle: 'Electricidad, gasfitería, fletes y más.',
                  onTap: () {
                    setState(() {
                      _publicationType = 'service';
                    });
                  },
                ),
                _TypeCard(
                  selected: _publicationType == 'commerce',
                  icon: Icons.storefront_outlined,
                  title: 'Comercio local',
                  subtitle: 'Tiendas y emprendimientos.',
                  onTap: () {
                    setState(() {
                      _publicationType = 'commerce';
                    });
                  },
                ),
                _TypeCard(
                  selected: _publicationType == 'food',
                  icon: Icons.restaurant_outlined,
                  title: 'Gastronomía',
                  subtitle: 'Restaurantes y comida.',
                  onTap: () {
                    setState(() {
                      _publicationType = 'food';
                    });
                  },
                ),
                _TypeCard(
                  selected: _publicationType == 'lodging',
                  icon: Icons.bed_outlined,
                  title: 'Alojamiento',
                  subtitle: 'Cabañas y hospedajes.',
                  onTap: () {
                    setState(() {
                      _publicationType = 'lodging';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _Label(
              'Nombre del servicio o negocio',
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                hintText: 'Ej. Servicios del Ranco',
                prefixIcon: Icon(
                  Icons.store_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un nombre.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Descripción'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe brevemente lo que ofreces.',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 10) {
                  return 'Agrega una descripción más completa.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Teléfono'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+56 9 ...',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label(
              'Localidad principal',
            ),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: _location,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
              items: _locations
                  .map(
                    (location) => DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _location = value;

                  if (!_coverage.contains(value)) {
                    _coverage.add(value);
                  }
                });
              },
            ),
            const SizedBox(height: 26),
            _NextButton(
              text: 'Continuar',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverageStep() {
    return _RegistrationPage(
      title: '¿Dónde trabajas?',
      subtitle: 'Selecciona todas las localidades donde ofreces tus servicios.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _locations.map(
              (location) {
                final selected = _coverage.contains(location);

                return FilterChip(
                  selected: selected,
                  label: Text(location),
                  avatar: const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                  ),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        if (!_coverage.contains(location)) {
                          _coverage.add(location);
                        }
                      } else {
                        _coverage.remove(location);
                      }
                    });
                  },
                );
              },
            ).toList(),
          ),
          if (_coverage.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Selecciona al menos una localidad.',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 30),
          _NextButton(
            text: 'Continuar',
            onPressed: _coverage.isEmpty ? null : _next,
          ),
        ],
      ),
    );
  }

  Widget _membershipStep() {
    return _RegistrationPage(
      title: 'Elige tu membresía',
      subtitle:
          'La membresía define la publicación de tu perfil dentro de Ranco Conecta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MembershipCard(
            selected: _membership == 'basic',
            icon: Icons.handyman_outlined,
            title: 'Básico servicios',
            subtitle: 'Ideal para oficios y prestadores locales.',
            price: '\$9.990',
            badge: 'Recomendado',
            onTap: () {
              setState(() {
                _membership = 'basic';
              });
            },
          ),
          const SizedBox(height: 12),
          _MembershipCard(
            selected: _membership == 'commerce',
            icon: Icons.storefront_outlined,
            title: 'Comercio Pro',
            subtitle: 'Para negocios y comercios locales.',
            price: '\$19.990',
            onTap: () {
              setState(() {
                _membership = 'commerce';
              });
            },
          ),
          const SizedBox(height: 12),
          _MembershipCard(
            selected: _membership == 'featured',
            icon: Icons.star_outline_rounded,
            title: 'Destacado',
            subtitle: 'Mayor visibilidad dentro de la plataforma.',
            price: '\$29.990',
            onTap: () {
              setState(() {
                _membership = 'featured';
              });
            },
          ),
          const SizedBox(height: 12),
          _MembershipCard(
            selected: _membership == 'lodging',
            icon: Icons.bed_outlined,
            title: 'Alojamiento',
            subtitle: 'Para cabañas, hospedajes y alojamientos.',
            price: '\$39.990',
            onTap: () {
              setState(() {
                _membership = 'lodging';
              });
            },
          ),
          const SizedBox(height: 28),
          _NextButton(
            text: 'Revisar inscripción',
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _confirmationStep() {
    return _RegistrationPage(
      title: 'Revisa tu inscripción',
      subtitle:
          'Confirma que los datos sean correctos antes de crear tu cuenta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummarySection(
            title: 'Cuenta',
            rows: [
              _SummaryRow(
                label: 'Nombre',
                value: _nameController.text,
              ),
              _SummaryRow(
                label: 'Correo',
                value: _emailController.text,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummarySection(
            title: 'Publicación',
            rows: [
              _SummaryRow(
                label: 'Nombre',
                value: _businessNameController.text,
              ),
              _SummaryRow(
                label: 'Tipo',
                value: _publicationTypeLabel(),
              ),
              _SummaryRow(
                label: 'Localidad',
                value: _location,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummarySection(
            title: 'Cobertura',
            rows: [
              _SummaryRow(
                label: 'Localidades',
                value: _coverage.join(', '),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummarySection(
            title: 'Membresía',
            rows: [
              _SummaryRow(
                label: 'Plan',
                value: _membershipLabel(),
              ),
              _SummaryRow(
                label: 'Valor',
                value: _membershipPrice(),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFFFE8E5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF8C2F28),
                ),
              ),
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFE1F0EA,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _successMessage!,
                style: const TextStyle(
                  color: RancoColors.forest,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _finish,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: RancoColors.forest,
              foregroundColor: Colors.white,
            ),
            child: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Crear cuenta y continuar',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'El pago y activación de membresía se conectarán en el siguiente módulo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_step == 0) {
      if (!_accountKey.currentState!.validate()) {
        return;
      }
    }

    if (_step == 1) {
      if (!_businessKey.currentState!.validate()) {
        return;
      }
    }

    if (_step == 2 && _coverage.isEmpty) {
      return;
    }

    if (_step >= _steps.length - 1) {
      return;
    }

    setState(() {
      _step++;
    });

    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) {
      context.go('/provider/join');
      return;
    }

    setState(() {
      _step--;
    });

    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    final result = await ref.read(authRepositoryProvider).signUp(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    result.when(
      success: (user) {
        if (user == null || !user.emailConfirmed) {
          setState(() {
            _successMessage =
                'Cuenta creada. Revisa tu correo para confirmar tu cuenta antes de continuar.';
          });
        } else {
          context.go('/account');
        }
      },
      failure: (failure) {
        setState(() {
          _error = failure.message;
        });
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _publicationTypeLabel() {
    switch (_publicationType) {
      case 'commerce':
        return 'Comercio local';
      case 'food':
        return 'Gastronomía';
      case 'lodging':
        return 'Alojamiento';
      default:
        return 'Oficio o servicio';
    }
  }

  String _membershipLabel() {
    switch (_membership) {
      case 'commerce':
        return 'Comercio Pro';
      case 'featured':
        return 'Destacado';
      case 'lodging':
        return 'Alojamiento';
      default:
        return 'Básico servicios';
    }
  }

  String _membershipPrice() {
    switch (_membership) {
      case 'commerce':
        return '\$19.990 / año';
      case 'featured':
        return '\$29.990 / año';
      case 'lodging':
        return '\$39.990 / año';
      default:
        return '\$9.990 / año';
    }
  }

  String? _validateEmail(
    String? value,
  ) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Ingresa tu correo.';
    }

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }

    return null;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.steps,
  });

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(
              steps.length,
              (index) {
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(
                      right: index == steps.length - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: index <= step
                          ? RancoColors.forest
                          : const Color(
                              0xFFD5E3DD,
                            ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paso ${step + 1} de ${steps.length} · ${steps[step]}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(
                    0xFF6B7D75,
                  ),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationPage extends StatelessWidget {
  const _RegistrationPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: RancoColors.forest,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(
                    0xFF6B7D75,
                  ),
                ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF50665D),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.arrow_forward_rounded,
      ),
      label: Text(text),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: RancoColors.forest,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F8F4) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? RancoColors.forest
                  : const Color(
                      0xFFD5E2DC,
                    ),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? RancoColors.forest
                      : const Color(
                          0xFFE4F1EB,
                        ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : RancoColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF31443B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF708179),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? RancoColors.forest
                  : const Color(
                      0xFFD5E2DC,
                    ),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? RancoColors.forest
                      : const Color(
                          0xFFE4F1EB,
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : RancoColors.forest,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(
                                0xFF31443B,
                              ),
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(
                            width: 8,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFE9DF,
                              ),
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Color(
                                  0xFFC85D39,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(
                          0xFF708179,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    '/ año',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF708179),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD7E4DE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: Color(
                          0xFF708179,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        color: Color(
                          0xFF31443B,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
