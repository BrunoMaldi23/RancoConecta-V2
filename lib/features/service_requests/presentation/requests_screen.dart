import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../shared/models/service_request.dart';
import '../../../theme/ranco_colors.dart';
import '../application/service_request_providers.dart';
import '../../auth/application/auth_controller.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({
    this.showBack = false,
    super.key,
  });

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return ColoredBox(
      color: RancoColors.canvas,
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestRequests();
          }

          final requests = ref.watch(myRequestsProvider);

          return requests.when(
            data: (items) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: _RequestsHeader(
                        count: items.length,
                      ),
                    ),
                  ),

                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyRequestsState(
                        onExplore: () {
                          context.go('/explore');
                        },
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          10,
                        ),
                        child: _RequestToolbar(
                          count: items.length,
                          onExplore: () {
                            context.go('/explore');
                          },
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        28,
                      ),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 9);
                        },
                        itemBuilder: (context, index) {
                          final request = items[index];

                          return _RequestCard(
                            request: request,
                            onTap: () {
                              context.go(
                                '/requests/${request.id}',
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },

            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },

            error: (error, stackTrace) {
              return RancoErrorState(
                message: requestFailureMessage(error),
                onRetry: () {
                  ref.invalidate(myRequestsProvider);
                },
              );
            },
          );
        },

        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },

        error: (error, stackTrace) {
          return const RancoErrorState(
            message: 'No pudimos leer la sesión.',
          );
        },
      ),
    );
  }
}

class _GuestRequests extends StatelessWidget {
  const _GuestRequests();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: _RequestsHeader(
              count: 0,
              guest: true,
            ),
          ),
        ),

        SliverFillRemaining(
          hasScrollBody: false,
          child: _GuestState(
            onSignIn: () {
              context.go('/sign-in');
            },
            onSignUp: () {
              context.go('/sign-up');
            },
          ),
        ),
      ],
    );
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader({
    required this.count,
    this.guest = false,
  });

  final int count;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            16,
            18,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 21,
                  color: RancoColors.forest,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitudes',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: RancoColors.forest,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1.0,
                          ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      guest
                          ? 'Gestiona tus solicitudes y sigue cada proceso en un solo lugar.'
                          : count == 0
                              ? 'Aquí podrás seguir tus solicitudes y revisar su estado.'
                              : '$count ${count == 1 ? 'solicitud registrada' : 'solicitudes registradas'} en tu cuenta.',
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
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
}

class _GuestState extends StatelessWidget {
  const _GuestState({
    required this.onSignIn,
    required this.onSignUp,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            42,
            24,
            90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 25,
                  color: RancoColors.forest,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Inicia sesión para ver tus solicitudes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Consulta estados, respuestas e historial de tus solicitudes desde tu cuenta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(
                    Icons.login_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Iniciar sesión',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: RancoColors.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              TextButton(
                onPressed: onSignUp,
                child: const Text(
                  'Crear una cuenta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState({
    required this.onExplore,
  });

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            38,
            24,
            90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 25,
                  color: RancoColors.forest,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Aún no tienes solicitudes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Cuando contactes a un negocio o prestador podrás seguir aquí todo el proceso.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Explorar negocios',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    190,
                    46,
                  ),
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestToolbar extends StatelessWidget {
  const _RequestToolbar({
    required this.count,
    required this.onExplore,
  });

  final int count;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'solicitud' : 'solicitudes'}',
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        TextButton.icon(
          onPressed: onExplore,
          icon: const Icon(
            Icons.add_rounded,
            size: 17,
          ),
          label: const Text(
            'Nueva solicitud',
          ),
          style: TextButton.styleFrom(
            foregroundColor: RancoColors.forest,
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onTap,
  });

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFD4E2DC),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1EC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 20,
                  color: RancoColors.forest,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.businessName ??
                                'Solicitud abierta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RancoColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        _StatusChip(
                          label: request.status.label,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      request.subcategoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Text(
                          request.publicCode,
                          style: const TextStyle(
                            color: RancoColors.forest,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const Spacer(),

                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: RancoColors.textSecondary,
                        ),
                      ],
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: RancoColors.forest,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({
    required this.requestId,
    super.key,
  });

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(
      requestDetailProvider(requestId),
    );

    final dateFormat = DateFormat.yMMMd('es');

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: const RancoAppBar(
        title: 'Solicitud',
        fallbackRoute: '/requests',
      ),
      body: request.when(
        data: (request) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 700,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  32,
                ),
                children: [
                  _RequestDetailHeader(
                    request: request,
                  ),

                  const SizedBox(height: 14),

                  _DetailSection(
                    title: 'Detalles',
                    children: [
                      _DetailRow(
                        label: 'Negocio',
                        value: request.businessName ??
                            'Solicitud abierta',
                      ),
                      _DetailRow(
                        label: 'Servicio',
                        value: request.subcategoryName,
                      ),
                      _DetailRow(
                        label: 'Urgencia',
                        value: request.urgency.label,
                      ),
                      _DetailRow(
                        label: 'Fecha deseada',
                        value: request.desiredDate == null
                            ? 'No definida'
                            : dateFormat.format(
                                request.desiredDate!,
                              ),
                      ),
                      _DetailRow(
                        label: 'Dirección',
                        value: request.addressText ??
                            'No informada',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _DetailSection(
                    title: 'Descripción',
                    children: [
                      Text(
                        request.description,
                        style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _DetailSection(
                    title: 'Seguimiento',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F1EC),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: RancoColors.forest,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Solicitud enviada',
                                  style: TextStyle(
                                    color:
                                        RancoColors.textPrimary,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  request.status.label,
                                  style: const TextStyle(
                                    color: RancoColors
                                        .textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },

        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },

        error: (error, stackTrace) {
          return RancoErrorState(
            message: requestFailureMessage(error),
            onRetry: () {
              ref.invalidate(
                requestDetailProvider(requestId),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestDetailHeader extends StatelessWidget {
  const _RequestDetailHeader({
    required this.request,
  });

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4E2DC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: RancoColors.forest,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.publicCode,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                _StatusChip(
                  label: request.status.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4E2DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}