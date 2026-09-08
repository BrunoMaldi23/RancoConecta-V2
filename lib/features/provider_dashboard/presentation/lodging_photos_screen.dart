import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/business_media_repository.dart';

class LodgingPhotosScreen extends ConsumerStatefulWidget {
  const LodgingPhotosScreen({
    super.key,
  });

  @override
  ConsumerState<LodgingPhotosScreen> createState() =>
      _LodgingPhotosScreenState();
}

class _LodgingPhotosScreenState extends ConsumerState<LodgingPhotosScreen> {
  final _picker = ImagePicker();

  bool _working = false;

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
          'Fotografias',
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

          final media = ref.watch(
            providerBusinessMediaProvider(
              business.id,
            ),
          );

          return media.when(
            data: (items) {
              final cover = items
                  .where(
                    (item) => item.isCover,
                  )
                  .firstOrNull;

              final gallery = items
                  .where(
                    (item) => !item.isCover,
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(
                  18,
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Portada y galeria',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(
                              height: 4,
                            ),
                            Text(
                              'Sube hasta 15 fotografias de tu alojamiento.',
                              style: TextStyle(
                                color: Color(
                                  0xFF697A72,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${items.length}/15',
                        style: const TextStyle(
                          color: RancoColors.forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'PORTADA',
                    style: TextStyle(
                      color: Color(
                        0xFF718078,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  if (cover == null)
                    _AddCoverCard(
                      busy: _working,
                      onTap: () {
                        _pickAndUpload(
                          business.id,
                        );
                      },
                    ),
                  if (cover != null)
                    _CoverCard(
                      item: cover,
                      url: ref
                          .read(
                            businessMediaRepositoryProvider,
                          )
                          .publicUrl(
                            cover.storagePath,
                          ),
                      busy: _working,
                      onDelete: () {
                        _delete(
                          cover,
                          business.id,
                        );
                      },
                    ),
                  const SizedBox(
                    height: 22,
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'GALERIA',
                          style: TextStyle(
                            color: Color(
                              0xFF718078,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                      if (items.length < 15)
                        TextButton.icon(
                          onPressed: _working
                              ? null
                              : () {
                                  _pickAndUpload(
                                    business.id,
                                  );
                                },
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                          ),
                          label: const Text(
                            'Agregar',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  if (gallery.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(
                        20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 36,
                            color: Color(
                              0xFF7A8D84,
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Aun no hay fotos en la galeria.',
                          ),
                        ],
                      ),
                    ),
                  if (gallery.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gallery.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        final item = gallery[index];

                        final url = ref
                            .read(
                              businessMediaRepositoryProvider,
                            )
                            .publicUrl(
                              item.storagePath,
                            );

                        return _GalleryTile(
                          item: item,
                          url: url,
                          busy: _working,
                          onMakeCover: () {
                            _makeCover(
                              item,
                              business.id,
                            );
                          },
                          onDelete: () {
                            _delete(
                              item,
                              business.id,
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (items.length < 15)
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () {
                              _pickAndUpload(
                                business.id,
                              );
                            },
                      icon: _working
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                      label: const Text(
                        'Agregar fotografia',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        minimumSize: const Size.fromHeight(
                          52,
                        ),
                      ),
                    ),
                ],
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
                'No pudimos cargar las fotografias: $error',
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

  Future<void> _pickAndUpload(
    String businessId,
  ) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );

    if (image == null) {
      return;
    }

    final extension =
        image.name.contains('.') ? image.name.split('.').last : 'jpg';

    final bytes = await image.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await ref
          .read(
            businessMediaRepositoryProvider,
          )
          .upload(
            businessId: businessId,
            bytes: bytes,
            extension: extension,
          );

      ref.invalidate(
        providerBusinessMediaProvider(
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
            'Fotografia subida correctamente.',
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
            'No pudimos subir la fotografia: $error',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _working = false;
      });
    }
  }

  Future<void> _makeCover(
    ProviderMediaItem item,
    String businessId,
  ) async {
    setState(() {
      _working = true;
    });

    try {
      await ref
          .read(
            businessMediaRepositoryProvider,
          )
          .makeCover(
            businessId: businessId,
            mediaId: item.id,
          );

      ref.invalidate(
        providerBusinessMediaProvider(
          businessId,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _delete(
    ProviderMediaItem item,
    String businessId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Eliminar fotografia',
          ),
          content: const Text(
            'Esta fotografia se eliminara de forma permanente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
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
                  context,
                  true,
                );
              },
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

    setState(() {
      _working = true;
    });

    try {
      await ref
          .read(
            businessMediaRepositoryProvider,
          )
          .delete(
            item,
          );

      ref.invalidate(
        providerBusinessMediaProvider(
          businessId,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }
}

class _AddCoverCard extends StatelessWidget {
  const _AddCoverCard({
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(
        18,
      ),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: const Color(
              0xFFC9DAD1,
            ),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: RancoColors.forest,
            ),
            SizedBox(
              height: 8,
            ),
            Text(
              'Agregar foto de portada',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.item,
    required this.url,
    required this.busy,
    required this.onDelete,
  });

  final ProviderMediaItem item;
  final String url;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        18,
      ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) =>
                  const ColoredBox(
                color: Color(
                  0xFFDDEBE5,
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
              child: const Text(
                'Portada',
                style: TextStyle(
                  color: RancoColors.forest,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filled(
              onPressed: busy ? null : onDelete,
              icon: const Icon(
                Icons.delete_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.item,
    required this.url,
    required this.busy,
    required this.onMakeCover,
    required this.onDelete,
  });

  final ProviderMediaItem item;
  final String url;
  final bool busy;
  final VoidCallback onMakeCover;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        15,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 5,
            top: 5,
            child: PopupMenuButton<String>(
              color: Colors.white,
              enabled: !busy,
              onSelected: (value) {
                if (value == 'cover') {
                  onMakeCover();
                }

                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'cover',
                  child: Text(
                    'Usar como portada',
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Eliminar',
                  ),
                ),
              ],
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
