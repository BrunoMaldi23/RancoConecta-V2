import 'package:flutter/material.dart';

class RancoSkeleton extends StatelessWidget {
  const RancoSkeleton({this.height = 96, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
