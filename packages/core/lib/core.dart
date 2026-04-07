// ABOUTME: Barrel export for the race_fueling_core package.
// ABOUTME: Re-exports all public models, engine functions, and storage interfaces.
library;

export 'src/models/warning.dart';
export 'src/models/product.dart';
export 'src/models/athlete_profile.dart';
export 'src/models/race_config.dart';
export 'src/models/fueling_plan.dart';

export 'src/engine/plan_engine.dart';
export 'src/engine/timeline_builder.dart' show TimeSlot;
export 'src/engine/environmental.dart' show EnvironmentalAdjustments;
