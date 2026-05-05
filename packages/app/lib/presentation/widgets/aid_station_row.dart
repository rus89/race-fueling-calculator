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
    final markValue = _isDistance
        ? (station.distanceKm!).toStringAsFixed(
            station.distanceKm! % 1 == 0 ? 0 : 1,
          )
        : '${station.timeMinutes ?? 0}';
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
                  onChanged: (toDistance) {
                    if (toDistance) {
                      onChanged(
                        AidStation(
                          distanceKm:
                              station.distanceKm ??
                              ((station.timeMinutes ?? 0) / 3.0),
                          refill: station.refill,
                        ),
                      );
                    } else {
                      onChanged(
                        AidStation(
                          timeMinutes:
                              station.timeMinutes ??
                              ((station.distanceKm ?? 0) * 3).round(),
                          refill: station.refill,
                        ),
                      );
                    }
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
                        onChanged(
                          AidStation(distanceKm: km, refill: station.refill),
                        );
                      }
                    } else {
                      final m = int.tryParse(v);
                      if (m != null) {
                        onChanged(
                          AidStation(timeMinutes: m, refill: station.refill),
                        );
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
                    final next = [...station.refill]..remove(id);
                    onChanged(
                      AidStation(
                        timeMinutes: station.timeMinutes,
                        distanceKm: station.distanceKm,
                        refill: next,
                      ),
                    );
                  },
                ),
              _AddProductButton(
                library: library,
                excluded: station.refill,
                onPick: (id) {
                  final next = [...station.refill, id];
                  onChanged(
                    AidStation(
                      timeMinutes: station.timeMinutes,
                      distanceKm: station.distanceKm,
                      refill: next,
                    ),
                  );
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
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(BonkTokens.rSm),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12),
            ),
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
      return const SizedBox.shrink();
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
