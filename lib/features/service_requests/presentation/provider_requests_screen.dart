import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../shared/models/request_attachment.dart';
import '../../../shared/models/quote.dart';
import '../../../theme/ranco_colors.dart';
import '../application/service_request_providers.dart';
import '../data/provider_request_repository.dart';
import '../data/quote_repository.dart';
import '../data/request_attachment_repository.dart';
import '../../messaging/data/messaging_repository.dart';

class ProviderRequestsScreen extends ConsumerWidget {
  const ProviderRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(providerRequestQueueProvider);

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: const RancoAppBar(
        title: 'Solicitudes',
        fallbackRoute: '/provider/dashboard',
      ),
      body: requests.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyProviderRequests();
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _Summary(count: items.length),
              const SizedBox(height: 14),
              ...items.map(
                (item) => _ProviderRequestCard(item: item),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RancoErrorState(
          message: requestFailureMessage(error),
          onRetry: () {
            ref.invalidate(providerRequestQueueProvider);
          },
        ),
      ),
    );
  }
}

class _ProviderRequestCard extends ConsumerWidget {
  const _ProviderRequestCard({
    required this.item,
  });

  final ProviderRequestItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatEnabled = ref.watch(appConfigProvider).featureFlags.chatEnabled;
    final canChat = item.businessId.isNotEmpty &&
        (item.operationId != null ||
            item.requestStatus == 'accepted' ||
            item.requestStatus == 'scheduled' ||
            item.requestStatus == 'in_progress' ||
            item.requestStatus == 'completed');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.publicCode,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _StatePill(label: item.stateLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.subcategoryName,
            style: const TextStyle(
              color: RancoColors.forest,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RancoColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (item.addressText?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              item.locationName == null
                  ? item.addressText!
                  : '${item.locationName} · ${item.addressText!}',
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else if (item.locationName != null) ...[
            const SizedBox(height: 8),
            Text(
              item.locationName!,
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (item.attachmentCount > 0) ...[
            const SizedBox(height: 8),
            _ProviderAttachmentsButton(
              requestId: item.requestId,
              count: item.attachmentCount,
            ),
          ],
          const SizedBox(height: 12),
          _Actions(item: item),
          if (chatEnabled && canChat) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openChat(context, ref),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Mensajes'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(messagingRepositoryProvider).getOrCreateConversation(
              contextType: 'service_request',
              contextId: item.requestId,
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

class _ProviderAttachmentsButton extends ConsumerWidget {
  const _ProviderAttachmentsButton({
    required this.requestId,
    required this.count,
  });

  final String requestId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _showAttachments(context, ref),
        icon: const Icon(Icons.attach_file_rounded, size: 16),
        label: Text('$count ${count == 1 ? 'adjunto' : 'adjuntos'}'),
      ),
    );
  }

  Future<void> _showAttachments(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(requestAttachmentRepositoryProvider).list(
          requestId,
        );

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (attachments) {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Adjuntos',
                    style: TextStyle(
                      color: RancoColors.forest,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final attachment in attachments)
                    ListTile(
                      leading: Icon(
                        attachment.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                      ),
                      title: Text(attachment.fileName),
                      onTap: () => _openAttachment(context, ref, attachment),
                    ),
                ],
              ),
            );
          },
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
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

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.item,
  });

  final ProviderRequestItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.operationStatus == 'accepted' && item.operationId != null) {
      return FilledButton.icon(
        onPressed: () => _runOperation(
          context,
          ref,
          ref
              .read(providerRequestRepositoryProvider)
              .startOperation(item.operationId!),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Iniciar operación'),
      );
    }

    if (item.operationStatus == 'in_progress' && item.operationId != null) {
      return FilledButton.icon(
        onPressed: () => _runOperation(
          context,
          ref,
          ref
              .read(providerRequestRepositoryProvider)
              .completeOperation(item.operationId!),
        ),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Finalizar'),
      );
    }

    if (item.quoteId != null) {
      return Text(
        item.quoteTotal == null
            ? 'Cotización enviada'
            : 'Cotización enviada por \$${item.quoteTotal}',
        style: const TextStyle(
          color: RancoColors.forest,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () => _showQuoteDialog(context, ref, item),
      icon: const Icon(Icons.request_quote_outlined),
      label: const Text('Cotizar'),
    );
  }

  Future<void> _showQuoteDialog(
    BuildContext context,
    WidgetRef ref,
    ProviderRequestItem item,
  ) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enviar cotización'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total CLP',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Observación',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (sent != true) {
      return;
    }

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un monto válido.')),
        );
      }
      return;
    }

    final result = await ref.read(quoteRepositoryProvider).sendQuote(
          SendQuoteInput(
            requestId: item.requestId,
            businessId: item.businessId,
            description: descriptionController.text,
            totalAmount: amount,
          ),
        );

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(providerRequestQueueProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotización enviada.')),
        );
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  Future<void> _runOperation(
    BuildContext context,
    WidgetRef ref,
    Future<dynamic> action,
  ) async {
    final result = await action;

    if (!context.mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(providerRequestQueueProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operación actualizada.')),
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${count == 1 ? 'solicitud disponible' : 'solicitudes disponibles'}',
      style: const TextStyle(
        color: RancoColors.forest,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyProviderRequests extends StatelessWidget {
  const _EmptyProviderRequests();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay solicitudes disponibles para este negocio.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: RancoColors.forest,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
