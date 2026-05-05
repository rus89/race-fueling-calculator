// ABOUTME: One row in the aid stations list — time/distance toggle, refill
// ABOUTME: chips, and a close button that removes the station.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/domain.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'seg_control.dart';
import 'text_input.dart';

class AidStationRow extends StatelessWidget {
  final AidStation station;
  final List<Product> library;
  final ValueChanged<AidStation> onChanged;
  final VoidCallback onRemove;

  const AidStationRow({
    super.key,
    required this.station,
    required this.library,
    required this.onChanged,
    required this.onRemove,
  });

  bool get _isDistance => station.distanceKm != null;

  @override
  Widget build(BuildContext context) {
    // The toggle-clear path stores 0 / 0.0 in the active unit so the user
    // gets a fresh, empty input box and re-types from scratch. Render those
    // sentinel zeros as empty strings so the user is not asked to delete a
    // "0" before typing.
    final String markValue;
    if (_isDistance) {
      final km = station.distanceKm!;
      markValue = km == 0.0 ? '' : km.toStringAsFixed(km % 1 == 0 ? 0 : 1);
    } else {
      final m = station.timeMinutes ?? 0;
      markValue = m == 0 ? '' : '$m';
    }
    final unitLabel = _isDistance ? 'km' : 'min';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BonkSegControl<bool>(
                  value: _isDistance,
                  options: const [(false, 'Time'), (true, 'Distance')],
                  // Clears the inactive unit's value on toggle (Q2=C).
                  // copyWith cannot clear timeMinutes / distanceKm to null,
                  // so the toggle constructs a fresh AidStation.
                  onChanged: (toDistance) {
                    onChanged(
                      AidStation(
                        timeMinutes: toDistance ? null : 0,
                        distanceKm: toDistance ? 0.0 : null,
                        refill: station.refill,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove aid station',
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: BonkTextInput(
                  value: markValue,
                  monoFont: true,
                  labelText: _isDistance ? 'Distance' : 'Time',
                  keyboardType: TextInputType.number,
                  inputFormatters: _isDistance
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ]
                      : [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    if (_isDistance) {
                      final km = double.tryParse(v);
                      if (km != null) {
                        onChanged(station.copyWith(distanceKm: km));
                      }
                    } else {
                      final m = int.tryParse(v);
                      if (m != null) {
                        onChanged(station.copyWith(timeMinutes: m));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Text(
                  unitLabel,
                  style: BonkType.mono(
                    size: 11,
                  ).copyWith(color: BonkTokens.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in station.refill)
                _RefillChip(
                  product: _findProduct(id),
                  onRemove: () {
                    onChanged(
                      station.copyWith(
                        refill: station.refill.where((x) => x != id).toList(),
                      ),
                    );
                  },
                ),
              _AddProductButton(
                library: library,
                excluded: station.refill,
                onPick: (id) {
                  onChanged(station.copyWith(refill: [...station.refill, id]));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Product? _findProduct(String id) {
    for (final p in library) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class _RefillChip extends StatelessWidget {
  final Product? product;
  final VoidCallback onRemove;
  const _RefillChip({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final label = product == null
        ? 'unknown'
        : ([
            product!.brand,
            product!.name,
          ].where((s) => s != null && s.isNotEmpty).join(' '));
    return Container(
      decoration: BoxDecoration(
        color: BonkTokens.paper,
        border: Border.all(color: BonkTokens.rule),
        borderRadius: BorderRadius.circular(BonkTokens.r),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: BonkType.sans(size: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // 24×24 hit area enforces WCAG 2.5.8 minimum without making the
          // chip itself oversized. IconButton's default 48×48 padding would
          // inflate the chip — the constraints crop it back to chip-scale.
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            iconSize: 14,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Remove $label from refills',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddProductButton extends StatelessWidget {
  final List<Product> library;
  final List<String> excluded;
  final ValueChanged<String> onPick;
  const _AddProductButton({
    required this.library,
    required this.excluded,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final available = library.where((p) => !excluded.contains(p.id)).toList();
    if (available.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: BonkTokens.rule2),
          borderRadius: BorderRadius.circular(BonkTokens.rSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'All products added',
          style: BonkType.sans(size: 11.5).copyWith(color: BonkTokens.ink3),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Add refill product',
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final p in available)
          PopupMenuItem<String>(
            value: p.id,
            child: Text(
              [
                p.brand,
                p.name,
              ].where((s) => s != null && s.isNotEmpty).join(' '),
              style: BonkType.sans(size: 12),
            ),
          ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: BonkTokens.bg2,
          border: Border.all(color: BonkTokens.rule),
          borderRadius: BorderRadius.circular(BonkTokens.r),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '+ refill',
          style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink2),
        ),
      ),
    );
  }
}
