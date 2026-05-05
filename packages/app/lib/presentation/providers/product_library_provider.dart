// ABOUTME: Provides the merged product library — built-ins + user overrides.
// ABOUTME: User overrides are deferred to a future version; for now built-ins only.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';

final productLibraryProvider = Provider<List<Product>>(
  (ref) => List.unmodifiable(builtInProducts),
);
