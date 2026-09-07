import 'package:flutter/material.dart';

class RancoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RancoAppBar({required this.title, super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
  }
}
