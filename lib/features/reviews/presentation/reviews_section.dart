import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/review_providers.dart';
import '../data/business_review.dart';
import '../data/reviews_repository.dart';

class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({
    required this.businessId,
    required this.ratingAvg,
    required this.reviewCount,
    super.key,
  });

  final String businessId;
  final double ratingAvg;
  final int reviewCount;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final reviews = ref.watch(
      businessReviewsProvider(businessId),
    );

    final myReview = ref.watch(
      myBusinessReviewProvider(businessId),
    );

    final user = ref.watch(authStateProvider).valueOrNull;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(
        18,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Opiniones',
                  style: TextStyle(
                    color: Color(
                      0xFF30443B,
                    ),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (reviewCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFFFF3D9,
                    ),
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(
                          0xFFB7791F,
                        ),
                        size: 17,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        '${ratingAvg.toStringAsFixed(1)} ($reviewCount)',
                        style: const TextStyle(
                          color: Color(
                            0xFF8A5B12,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          myReview.when(
            data: (current) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (user == null) {
                      context.go('/sign-in');
                      return;
                    }

                    _openReviewEditor(
                      context,
                      ref,
                      current,
                    );
                  },
                  icon: Icon(
                    current == null
                        ? Icons.rate_review_outlined
                        : Icons.edit_outlined,
                  ),
                  label: Text(
                    current == null
                        ? 'Escribir una rese\u00f1a'
                        : 'Editar mi rese\u00f1a',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RancoColors.forest,
                    minimumSize: const Size.fromHeight(
                      48,
                    ),
                    side: const BorderSide(
                      color: Color(
                        0xFFD5E2DC,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(
            height: 16,
          ),
          reviews.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyReviews();
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _ReviewCard(
                      review: items[index],
                      isOwn: user?.id == items[index].userId,
                      onEdit: () {
                        _openReviewEditor(
                          context,
                          ref,
                          items[index],
                        );
                      },
                      onDelete: () {
                        _deleteReview(
                          context,
                          ref,
                          items[index],
                        );
                      },
                    ),
                    if (index != items.length - 1)
                      const Divider(
                        height: 28,
                        color: Color(
                          0xFFE3EAE6,
                        ),
                      ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (
              error,
              stackTrace,
            ) =>
                Column(
              children: [
                const Text(
                  'No pudimos cargar las opiniones.',
                  style: TextStyle(
                    color: Color(
                      0xFF71827A,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(
                      businessReviewsProvider(
                        businessId,
                      ),
                    );
                  },
                  child: const Text(
                    'Reintentar',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReviewEditor(
    BuildContext context,
    WidgetRef ref,
    BusinessReview? current,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      context.go('/sign-in');
      return;
    }

    var selectedRating = current?.rating ?? 5;

    final controller = TextEditingController(
      text: current?.comment ?? '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setState,
          ) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    26,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current == null
                                ? 'Escribir rese\u00f1a'
                                : 'Editar rese\u00f1a',
                            style: const TextStyle(
                              color: Color(
                                0xFF30443B,
                              ),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'Tu valoraci\u00f3n',
                      style: TextStyle(
                        color: Color(
                          0xFF53675E,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) {
                          final value = index + 1;

                          return IconButton(
                            padding: const EdgeInsets.only(
                              right: 4,
                            ),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(
                                () {
                                  selectedRating = value;
                                },
                              );
                            },
                            icon: Icon(
                              value <= selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(
                                0xFFB7791F,
                              ),
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 600,
                      decoration: InputDecoration(
                        labelText: 'Cu\u00e9ntanos tu experiencia',
                        hintText: 'Describe c\u00f3mo fue el servicio...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(
                          0xFFF6F8F7,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                          borderSide: const BorderSide(
                            color: Color(
                              0xFFD5E2DC,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                          borderSide: const BorderSide(
                            color: Color(
                              0xFFD5E2DC,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(
                                  reviewsRepositoryProvider,
                                )
                                .saveReview(
                                  businessId: businessId,
                                  rating: selectedRating,
                                  comment: controller.text,
                                );

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.pop(
                              context,
                              true,
                            );
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No pudimos guardar la rese\u00f1a.',
                                ),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            52,
                          ),
                          backgroundColor: RancoColors.forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        child: Text(
                          current == null
                              ? 'Publicar rese\u00f1a'
                              : 'Guardar cambios',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (saved != true) {
      return;
    }

    ref.invalidate(
      businessReviewsProvider(
        businessId,
      ),
    );

    ref.invalidate(
      myBusinessReviewProvider(
        businessId,
      ),
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(
          0xFF234B3D,
        ),
        margin: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        content: const Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: Colors.white,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'Rese\u00f1a publicada correctamente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    BusinessReview review,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar rese\u00f1a',
          ),
          content: const Text(
            '\u00bfQuieres eliminar tu rese\u00f1a? Esta acci\u00f3n no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(
                  0xFF8E3B32,
                ),
              ),
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(
            reviewsRepositoryProvider,
          )
          .deleteReview(
            review.id,
          );

      ref.invalidate(
        businessReviewsProvider(
          businessId,
        ),
      );

      ref.invalidate(
        myBusinessReviewProvider(
          businessId,
        ),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(
            0xFF234B3D,
          ),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              16,
            ),
          ),
          content: const Text(
            'Rese\u00f1a eliminada',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos eliminar la rese\u00f1a.',
          ),
        ),
      );
    }
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF6F8F7,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(
              0xFF789086,
            ),
            size: 30,
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            'A\u00fan no hay opiniones',
            style: TextStyle(
              color: Color(
                0xFF40534A,
              ),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(
            height: 4,
          ),
          Text(
            'S\u00e9 el primero en compartir tu experiencia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(
                0xFF71827A,
              ),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isOwn,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessReview review;
  final bool isOwn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(
                  0xFFE4F1EB,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: RancoColors.forest,
                size: 21,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOwn ? 'Tu rese\u00f1a' : 'Usuario de Ranco Conecta',
                    style: const TextStyle(
                      color: Color(
                        0xFF30443B,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    _formatDate(
                      review.createdAt,
                    ),
                    style: const TextStyle(
                      color: Color(
                        0xFF829188,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isOwn)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Editar',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Eliminar',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              index < review.rating
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: const Color(
                0xFFB7791F,
              ),
              size: 20,
            ),
          ),
        ),
        if (review.comment?.trim().isNotEmpty == true) ...[
          const SizedBox(
            height: 9,
          ),
          Text(
            review.comment!,
            style: const TextStyle(
              color: Color(
                0xFF5E7168,
              ),
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(
    DateTime value,
  ) {
    final local = value.toLocal();

    final day = local.day.toString().padLeft(
          2,
          '0',
        );

    final month = local.month.toString().padLeft(
          2,
          '0',
        );

    return '$day/$month/${local.year}';
  }
}
