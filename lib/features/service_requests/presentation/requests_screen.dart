import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_segmented_control.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_page_empty_state.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../core/widgets/ranco_site_footer.dart';
import '../../../config/app_config.dart';
import '../../../shared/models/request_attachment.dart';
import '../../../shared/models/service_request.dart';
import '../../../shared/models/service_request_status.dart';
import '../../../theme/ranco_colors.dart';
import '../application/service_request_providers.dart';
import '../domain/customer_activity_item.dart';
import '../data/request_attachment_repository.dart';
import '../data/quote_repository.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../auth/application/auth_controller.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({
    this.showBack = false,
    super.key,
  });

  final bool showBack;

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _RequestListFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return ColoredBox(
      color: RancoColors.canvas,
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestRequests();
          }

          final requests = ref.watch(myCustomerActivityProvider);

          return requests.when(
            data: (items) {
              if (user.isAnonymous) {
                return _VisitorRequestsView(
                  items: items,
                  onExplore: () => context.go('/explore'),
                  onOpen: (route) => context.go(route),
                );
              }
              final selectedFilter = _filter ??
                  _RequestListFilter.values.firstWhere(
                    (value) => items.any(value.includes),
                    orElse: () => _RequestListFilter.active,
                  );
              final filtered = items.where(selectedFilter.includes).toList();

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
                    SliverToBoxAdapter(
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
                          filter: selectedFilter,
                          onFilterChanged: (value) {
                            setState(() {
                              _filter = value;
                            });
                          },
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
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 9);
                        },
                        itemBuilder: (context, index) {
                          final request = filtered[index];

                          return _RequestCard(
                            request: request,
                            onTap: () {
                              context.go(request.detailRoute);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const RancoFooterSliver(),
                ],
              );
            },
            // Esqueleto estructural en vez de spinner centrado.
            loading: () => const _VisitorRequestsLoading(),
            error: (error, stackTrace) {
              return RancoErrorState(
                message: requestFailureMessage(error),
                onRetry: () {
                  ref.invalidate(myCustomerActivityProvider);
                },
              );
            },
          );
        },
        loading: () {
          return const RancoLoadingState();
        },
        error: (error, stackTrace) {
          return RancoErrorState(
            message: 'No pudimos leer la sesión.',
            onRetry: () => ref.invalidate(authStateProvider),
          );
        },
      ),
    );
  }
}

enum _VisitorRequestStage {
  pending('Pendiente'),
  accepted('Aceptada'),
  rejected('Rechazada'),
  finished('Finalizada'),
  other('Otros estados');

  const _VisitorRequestStage(this.label);
  final String label;

  static _VisitorRequestStage of(CustomerActivityStage stage) =>
      switch (stage) {
        CustomerActivityStage.pending => pending,
        CustomerActivityStage.accepted => accepted,
        CustomerActivityStage.rejected => rejected,
        CustomerActivityStage.finished => finished,
        _ => other,
      };
}

class _VisitorRequestsView extends StatelessWidget {
  const _VisitorRequestsView({
    required this.items,
    required this.onExplore,
    required this.onOpen,
  });

  final List<CustomerActivityItem> items;
  final VoidCallback onExplore;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mis solicitudes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: RancoColors.textPrimary,
                                    fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(
                          items.isEmpty
                              ? 'Aquí podrás seguir las respuestas de los negocios.'
                              : '${items.length} ${items.length == 1 ? 'solicitud' : 'solicitudes'} en tu perfil visitante.',
                          style: const TextStyle(
                              color: RancoColors.textSecondary, fontSize: 13),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(spacing: 7, runSpacing: 7, children: [
                            for (final stage in _VisitorRequestStage.values)
                              if (stage != _VisitorRequestStage.other ||
                                  items.any((item) =>
                                      _VisitorRequestStage.of(item.stage) ==
                                      stage))
                                _StageCount(
                                  stage: stage,
                                  count: items
                                      .where((item) =>
                                          _VisitorRequestStage.of(item.stage) ==
                                          stage)
                                      .length,
                                ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyRequestsState(onExplore: onExplore),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 724),
                    child: _VisitorRequestCard(
                      request: items[index],
                      onTap: () => onOpen(items[index].detailRoute),
                    ),
                  ),
                ),
              ),
            ),
          const RancoFooterSliver(),
        ],
      );
}

class _StageCount extends StatelessWidget {
  const _StageCount({required this.stage, required this.count});
  final _VisitorRequestStage stage;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4EF),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('${stage.label} · $count',
            style: const TextStyle(
                color: RancoColors.forest,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

class _VisitorRequestCard extends StatelessWidget {
  const _VisitorRequestCard({required this.request, required this.onTap});
  final CustomerActivityItem request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _ActivityRow(request: request, onTap: onTap, showDescription: true);
}

class _VisitorRequestsLoading extends StatelessWidget {
  const _VisitorRequestsLoading();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              for (final width in [210.0, 130.0, 320.0, 320.0]) ...[
                Container(
                  width: width,
                  height: width == 320 ? 104 : 20,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

enum _RequestListFilter {
  active,
  quotes,
  inProgress,
  finished;

  String get label {
    return switch (this) {
      _RequestListFilter.active => 'Activas',
      _RequestListFilter.quotes => 'Cotizaciones',
      _RequestListFilter.inProgress => 'En curso',
      _RequestListFilter.finished => 'Finalizadas',
    };
  }

  bool includes(CustomerActivityItem request) {
    return switch (this) {
      _RequestListFilter.active =>
        request.stage == CustomerActivityStage.pending && !request.isQuoted,
      _RequestListFilter.quotes => request.isQuoted,
      _RequestListFilter.inProgress =>
        request.stage == CustomerActivityStage.accepted,
      _RequestListFilter.finished =>
        request.stage == CustomerActivityStage.finished ||
            request.stage == CustomerActivityStage.cancelled ||
            request.stage == CustomerActivityStage.rejected ||
            request.stage == CustomerActivityStage.other,
    };
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
        SliverToBoxAdapter(
          child: _GuestState(
            onSignIn: () {
              context.go('/sign-in');
            },
            onSignUp: () {
              context.go('/sign-up');
            },
          ),
        ),
        const RancoFooterSliver(),
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
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
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
            40,
            24,
            40,
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
    return RancoPageEmptyState(
      icon: Icons.assignment_outlined,
      topSpacing: 88,
      title: 'Aún no tienes solicitudes',
      message: 'Cuando contactes a un negocio o envíes una reserva, podrás '
          'seguir desde aquí su estado.',
      actionLabel: 'Explorar negocios',
      onAction: onExplore,
    );
  }
}

class _RequestToolbar extends StatelessWidget {
  const _RequestToolbar({
    required this.count,
    required this.filter,
    required this.onFilterChanged,
    required this.onExplore,
  });

  final int count;
  final _RequestListFilter filter;
  final ValueChanged<_RequestListFilter> onFilterChanged;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: RancoSegmentedControl<_RequestListFilter>(
            segments: [
              for (final value in _RequestListFilter.values)
                RancoSegment(value: value, label: value.label),
            ],
            selected: filter,
            onChanged: onFilterChanged,
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

  final CustomerActivityItem request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _ActivityRow(request: request, onTap: onTap);
}

/// Fila compacta de solicitud/reserva, común a todas las verticales.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.request,
    required this.onTap,
    this.showDescription = false,
  });

  final CustomerActivityItem request;
  final VoidCallback onTap;
  final bool showDescription;

  static (IconData, String) _typeOf(CustomerActivityType type) =>
      switch (type) {
        CustomerActivityType.lodging => (
            Icons.bed_outlined,
            'Reserva de alojamiento'
          ),
        CustomerActivityType.gastronomy => (
            Icons.restaurant_outlined,
            'Reserva de mesa'
          ),
        CustomerActivityType.tourism => (
            Icons.terrain_outlined,
            'Experiencia turística'
          ),
        CustomerActivityType.service => (
            Icons.home_repair_service_outlined,
            'Solicitud de servicio'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, typeLabel) = _typeOf(request.type);
    final date = DateFormat('dd/MM/yyyy').format(request.createdAt);
    final description = request.description?.trim();
    final status = _StatusChip(
      label: _stageLabel(request.stage, request.statusLabel),
      tone: _stageTone(request.stage),
    );
    const cta = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Ver detalle',
          style: TextStyle(
              color: RancoColors.primaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
      SizedBox(width: 2),
      Icon(Icons.chevron_right_rounded, size: 18, color: RancoColors.forest),
    ]);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE6E1)),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 460;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(typeLabel,
                    style: const TextStyle(
                        color: RancoColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${request.summary} · $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RancoColors.textSecondary, fontSize: 13)),
                if (showDescription &&
                    description != null &&
                    description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 13,
                          height: 1.35)),
                ],
              ],
            );
            final leading = Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5F2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: RancoColors.primaryDark),
            );
            if (narrow) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: 8),
                          Row(children: [
                            Flexible(child: status),
                            const Spacer(),
                            cta,
                          ]),
                        ],
                      ),
                    ),
                  ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [status, const SizedBox(height: 10), cta],
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Etiqueta de estado unificada por etapa.
String _stageLabel(CustomerActivityStage stage, String fallback) =>
    switch (stage) {
      CustomerActivityStage.pending => 'Pendiente',
      CustomerActivityStage.accepted => 'Aceptada',
      CustomerActivityStage.rejected => 'Rechazada',
      CustomerActivityStage.finished => 'Finalizada',
      CustomerActivityStage.cancelled => 'Cancelada',
      CustomerActivityStage.other => fallback,
    };

/// Pendiente ámbar, aceptada verde, rechazada rojo suave, finalizada neutra,
/// cancelada gris.
RancoStatusTone _stageTone(CustomerActivityStage stage) => switch (stage) {
      CustomerActivityStage.pending => RancoStatusTone.warning,
      CustomerActivityStage.accepted => RancoStatusTone.success,
      CustomerActivityStage.rejected => RancoStatusTone.danger,
      CustomerActivityStage.finished => RancoStatusTone.info,
      CustomerActivityStage.cancelled => RancoStatusTone.muted,
      CustomerActivityStage.other => RancoStatusTone.neutral,
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.tone,
  });

  final String label;
  final RancoStatusTone? tone;

  @override
  Widget build(BuildContext context) => RancoStatusBadge(
        label: label,
        tone: tone ?? rancoToneForStatusLabel(label),
      );
}

class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({
    required this.requestId,
    this.justSent = false,
    this.attachmentsFailed = false,
    super.key,
  });

  final String requestId;
  final bool justSent;
  final bool attachmentsFailed;

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
                  if (justSent) ...[
                    _VisitorRequestConfirmation(
                      request: request,
                      attachmentsFailed: attachmentsFailed,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _RequestDetailHeader(
                    request: request,
                  ),
                  _ChatEntrySection(request: request),
                  const SizedBox(height: 14),
                  _DetailSection(
                    title: 'Detalles',
                    children: [
                      _DetailRow(
                        label: 'Categoría',
                        value: request.categoryName,
                      ),
                      _DetailRow(
                        label: 'Negocio',
                        value: request.businessName ?? 'Solicitud abierta',
                      ),
                      _DetailRow(
                        label: 'Servicio',
                        value: request.subcategoryName,
                      ),
                      _DetailRow(
                        label: 'Localidad',
                        value: request.locationName ?? 'No informada',
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
                        value: request.addressText ?? 'No informada',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AttachmentsSection(requestId: request.id),
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
                              borderRadius: BorderRadius.circular(10),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Solicitud enviada',
                                  style: TextStyle(
                                    color: RancoColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  request.status.label,
                                  style: const TextStyle(
                                    color: RancoColors.textSecondary,
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
                  const SizedBox(height: 12),
                  _QuotesSection(requestId: request.id),
                ],
              ),
            ),
          );
        },
        loading: () {
          return const RancoLoadingState();
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

class _VisitorRequestConfirmation extends StatelessWidget {
  const _VisitorRequestConfirmation({
    required this.request,
    required this.attachmentsFailed,
  });

  final ServiceRequest request;
  final bool attachmentsFailed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCEE2D5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.check_circle_rounded, color: RancoColors.forest),
              SizedBox(width: 9),
              Expanded(
                child: Text('Solicitud enviada',
                    style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(request.businessName ?? 'Solicitud abierta'),
            const SizedBox(height: 3),
            Text(
                'Fecha: ${DateFormat('dd/MM/yyyy').format(request.createdAt)}'),
            const SizedBox(height: 3),
            Text(
                'Estado: ${request.status == ServiceRequestStatus.submitted || request.status == ServiceRequestStatus.viewed ? 'Pendiente de respuesta' : request.status.label}'),
            if (attachmentsFailed) ...[
              const SizedBox(height: 8),
              const Text(
                'La solicitud se envió, pero no pudimos adjuntar algunos archivos.',
                style: TextStyle(color: RancoColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/requests'),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Ver mis solicitudes'),
            ),
          ],
        ),
      );
}

class _ChatEntrySection extends ConsumerWidget {
  const _ChatEntrySection({
    required this.request,
  });

  final ServiceRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatEnabled = ref.watch(appConfigProvider).featureFlags.chatEnabled;
    final canChat = request.businessId != null &&
        (request.status == ServiceRequestStatus.accepted ||
            request.status == ServiceRequestStatus.scheduled ||
            request.status == ServiceRequestStatus.inProgress ||
            request.status == ServiceRequestStatus.completed ||
            request.status == ServiceRequestStatus.confirmed ||
            request.status == ServiceRequestStatus.reviewed);

    if (!chatEnabled || !canChat) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FilledButton.icon(
        onPressed: () => _openChat(context, ref),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Abrir mensajes'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: RancoColors.forest,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(messagingRepositoryProvider).getOrCreateConversation(
              contextType: 'service_request',
              contextId: request.id,
            );

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (conversationId) {
        context.go('/messages/$conversationId');
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }
}

class _QuotesSection extends ConsumerWidget {
  const _QuotesSection({
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(requestQuotesProvider(requestId));

    return quotes.when(
      data: (items) {
        if (items.isEmpty) {
          return const _DetailSection(
            title: 'Cotizaciones',
            children: [
              Text(
                'Aún no hay cotizaciones para esta solicitud.',
                style: TextStyle(
                  color: RancoColors.textSecondary,
                ),
              ),
            ],
          );
        }

        return _DetailSection(
          title: 'Cotizaciones',
          children: [
            for (final quote in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4E2DC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quote.businessName,
                              style: const TextStyle(
                                color: RancoColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _StatusChip(label: quote.status.label),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        quote.formattedTotal,
                        style: const TextStyle(
                          color: RancoColors.forest,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (quote.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          quote.description!,
                          style: const TextStyle(
                            color: RancoColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (quote.status.canRespond) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => _acceptQuote(context, ref, quote.id),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Aceptar'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _rejectQuote(context, ref, quote.id),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rechazar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const _DetailSection(
        title: 'Cotizaciones',
        children: [LinearProgressIndicator(minHeight: 2)],
      ),
      error: (error, stackTrace) => _DetailSection(
        title: 'Cotizaciones',
        children: [
          const Text('No pudimos cargar las cotizaciones.'),
          TextButton.icon(
            onPressed: () => ref.invalidate(requestQuotesProvider(requestId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptQuote(
    BuildContext context,
    WidgetRef ref,
    String quoteId,
  ) async {
    final result = await ref.read(quoteRepositoryProvider).acceptQuote(quoteId);

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(requestQuotesProvider(requestId));
        ref.invalidate(requestDetailProvider(requestId));
        ref.invalidate(myRequestsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotización aceptada.')),
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  Future<void> _rejectQuote(
    BuildContext context,
    WidgetRef ref,
    String quoteId,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rechazar cotización'),
            content:
                const Text('Esta cotización quedará marcada como rechazada.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Rechazar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final result = await ref.read(quoteRepositoryProvider).rejectQuote(quoteId);

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(requestQuotesProvider(requestId));
        ref.invalidate(requestDetailProvider(requestId));
        ref.invalidate(myRequestsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotización rechazada.')),
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }
}

class _AttachmentsSection extends ConsumerWidget {
  const _AttachmentsSection({
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(requestAttachmentsProvider(requestId));

    return attachments.when(
      data: (items) {
        if (items.isEmpty) {
          return const _DetailSection(
            title: 'Adjuntos',
            children: [
              Text(
                'No hay adjuntos en esta solicitud.',
                style: TextStyle(color: RancoColors.textSecondary),
              ),
            ],
          );
        }

        return _DetailSection(
          title: 'Adjuntos',
          children: [
            for (final attachment in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  attachment.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: RancoColors.forest,
                ),
                title: Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${(attachment.sizeBytes / 1024).ceil()} KB'),
                onTap: () => _openAttachment(context, ref, attachment),
              ),
          ],
        );
      },
      loading: () => const _DetailSection(
        title: 'Adjuntos',
        children: [LinearProgressIndicator(minHeight: 2)],
      ),
      error: (error, stackTrace) => _DetailSection(
        title: 'Adjuntos',
        children: [
          const Text('No pudimos cargar los adjuntos.'),
          TextButton.icon(
            onPressed: () =>
                ref.invalidate(requestAttachmentsProvider(requestId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    RequestAttachment attachment,
  ) async {
    final result = await ref
        .read(requestAttachmentRepositoryProvider)
        .signedUrl(attachment);

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (uri) async {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
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
