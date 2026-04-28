// ABOUTME: Parses enum-valued CLI flags (Strategy, TimelineMode, ProductType)
// ABOUTME: with strict matching and UsageException error messages on mismatch.
import 'package:args/command_runner.dart';
import 'package:race_fueling_core/core.dart';

/// Parses a --strategy flag value into [Strategy]. Accepts steady / front-load
/// / back-load (hyphen or underscore). Throws [UsageException] on any other
/// value, including "custom" which requires curve segments unavailable to
/// the CLI.
Strategy parseStrategyFlag(String raw) {
  final normalized = raw.toLowerCase().replaceAll('_', '-');
  return switch (normalized) {
    'steady' => Strategy.steady,
    'front-load' => Strategy.frontLoad,
    'back-load' => Strategy.backLoad,
    'custom' => throw UsageException(
        'The custom strategy requires curve segments and is not available '
            'via the CLI.',
        'Use --strategy steady, front-load, or back-load.',
      ),
    _ => throw UsageException(
        '--strategy must be one of: steady, front-load, back-load',
        'Got "$raw".',
      ),
  };
}

/// Parses a --mode flag into [TimelineMode]. Throws [UsageException] on any
/// value other than "time" or "distance".
TimelineMode parseModeFlag(String raw) {
  return switch (raw.toLowerCase()) {
    'time' => TimelineMode.timeBased,
    'distance' => TimelineMode.distanceBased,
    _ => throw UsageException(
        '--mode must be one of: time, distance',
        'Got "$raw".',
      ),
  };
}

/// Parses a --type flag into [ProductType]. Throws [UsageException] on any
/// value outside the enum.
ProductType parseProductTypeFlag(String raw) {
  return switch (raw.toLowerCase()) {
    'gel' => ProductType.gel,
    'liquid' => ProductType.liquid,
    'solid' => ProductType.solid,
    'chew' => ProductType.chew,
    'real_food' => ProductType.realFood,
    _ => throw UsageException(
        '--type must be one of: gel, liquid, solid, chew, real_food',
        'Got "$raw".',
      ),
  };
}
