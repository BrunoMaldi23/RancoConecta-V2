import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RancoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RancoAppBar({
    required this.title,
    this.fallbackRoute,
    this.showBack = true,
    this.actions,
    super.key,
  });

  final String title;
  final String? fallbackRoute;
  final bool showBack;
  final List<Widget>? actions;

  static const _forest = Color(
    0xFF2E7D5A,
  );

  @override
  Size get preferredSize => const Size.fromHeight(
        64,
      );

  void _back(
    BuildContext context,
  ) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    final fallback = fallbackRoute;

    if (fallback != null) {
      context.go(
        fallback,
      );
      return;
    }

    context.go(
      '/',
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      leadingWidth: showBack ? 68 : 16,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(
                left: 14,
                top: 7,
                bottom: 7,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  14,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                  onTap: () {
                    _back(
                      context,
                    );
                  },
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _forest,
                    size: 23,
                  ),
                ),
              ),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: actions,
    );
  }
}
