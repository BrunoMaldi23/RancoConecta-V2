import 'package:flutter/material.dart';

class RancoSkeleton extends StatelessWidget {
  const RancoSkeleton({this.height = 96, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          )),
                      const SizedBox(height: 10),
                      FractionallySizedBox(
                        widthFactor: .68,
                        alignment: Alignment.centerLeft,
                        child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            )),
                      ),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
