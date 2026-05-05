// ABOUTME: One-line product row — kind dot, brand+name, carb badge, stepper.
// ABOUTME: Stepper drives ProductSelection.quantity through onChanged.
import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'stepper.dart';

/// Short, human-readable label for a [ProductType]. Surfaces the product
/// kind in mono sublines and as the [Semantics.label] on the kind dot so
/// screen readers receive the type via text — color alone is decorative.
extension ProductTypeShortLabel on ProductType {
  String get shortLabel => switch (this) {
    ProductType.gel => 'Gel',
    ProductType.liquid => 'Liquid',
    ProductType.chew => 'Chew',
    ProductType.solid => 'Solid',
    ProductType.realFood => 'Real food',
  };
}

class InventoryRow extends StatelessWidget {
  final Product product;
  final int count;
  final ValueChanged<int> onChanged;

  const InventoryRow({
    super.key,
    required this.product,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = product.fructoseGrams > 0
        ? '${product.glucoseGrams.round()}:${product.fructoseGrams.round()}'
        : 'single';
    final brandName = [
      product.brand,
      product.name,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final typeLabel = product.type.shortLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _KindDot(type: product.type),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brandName,
                  style: BonkType.sans(size: 13, w: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${product.carbsPerServing.round()}g · $ratio · $typeLabel',
                  style: BonkType.mono(
                    size: 11,
                  ).copyWith(color: BonkTokens.ink3),
                ),
              ],
            ),
          ),
          BonkStepper(
            keyPrefix: 'inv.${product.id}',
            value: count,
            onChanged: onChanged,
            semanticLabel: '$brandName quantity',
          ),
        ],
      ),
    );
  }
}

class _KindDot extends StatelessWidget {
  final ProductType type;
  const _KindDot({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      ProductType.gel => BonkTokens.accent,
      ProductType.liquid => BonkTokens.ink2,
      ProductType.chew => BonkTokens.ink,
      ProductType.solid => BonkTokens.ink3,
      ProductType.realFood => BonkTokens.rule,
    };
    return Semantics(
      label: type.shortLabel,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
