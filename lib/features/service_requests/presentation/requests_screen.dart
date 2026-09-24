import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../config/app_config.dart';
import '../../../shared/models/request_attachment.dart';
import '../../../shared/models/service_request.dart';
import '../../../shared/models/service_request_status.dart';
import '../../../theme/ranco_colors.dart';
import '../application/service_request_providers.dart';
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
  _RequestListFilter _filter = _RequestListFilter.active;

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

          final requests = ref.watch(myRequestsProvider);

          return requests.when(
            data: (items) {
              final filtered = items.where(_filter.includes).toList();

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
                          filter: _filter,
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

  bool includes(ServiceRequest request) {
    return switch (this) {
      _RequestListFilter.active =>
        request.status == ServiceRequestStatus.submitted ||
            request.status == ServiceRequestStatus.viewed,
      _RequestListFilter.quotes =>
        request.status == ServiceRequestStatus.quoted,
      _RequestListFilter.inProgress =>
        request.status == ServiceRequestStatus.accepted ||
            request.status == ServiceRequestStatus.scheduled ||
            request.status == ServiceRequestStatus.inProgress,
      _RequestListFilter.finished =>
        request.status == ServiceRequestStatus.completed ||
            request.status == ServiceRequestStatus.confirmed ||
            request.status == ServiceRequestStatus.reviewed ||
            request.status == ServiceRequestStatus.cancelled ||
            request.status == ServiceRequestStatus.rejected ||
            request.status == ServiceRequestStatus.expired,
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_RequestListFilter>(
            segments: [
              for (final value in _RequestListFilter.values)
                ButtonSegment(
                  value: value,
                  label: Text(value.label),
                ),
            ],
            selected: {filter},
            onSelectionChanged: (values) {
              onFilterChanged(values.single);
            },
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
                            request.businessName ?? 'Solicitud abierta',
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
          Text(requestFailureMessage(error)),
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
        children: [Text(requestFailureMessage(error))],
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
