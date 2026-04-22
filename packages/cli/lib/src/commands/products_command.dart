// ABOUTME: ProductsCommand — 'fuel products list/show/add/edit/remove/reset'
// ABOUTME: subcommands that manage the merged built-in + user product library.
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:race_fueling_core/core.dart';

import '../cli/errors.dart';
import '../cli/exit_codes.dart';
import '../cli/tty.dart';
import '../prompts/interactive.dart';

class ProductsCommand extends Command<void> {
  ProductsCommand(
    StorageAdapter storage, {
    IsTtyProbe isTty = defaultIsTty,
    LineReader? readLine,
  }) {
    addSubcommand(_ProductsListCommand(storage));
    addSubcommand(_ProductsShowCommand(storage));
    addSubcommand(_ProductsAddCommand(storage));
    addSubcommand(_ProductsEditCommand(storage));
    addSubcommand(_ProductsRemoveCommand(storage));
    addSubcommand(
      _ProductsResetCommand(storage, isTty: isTty, readLine: readLine),
    );
  }

  @override
  final String name = 'products';

  @override
  final String description = 'Manage your nutrition product library';
}

/// Converts a human name to a URL-safe slug for product IDs.
String _slugify(String name) {
  final lower = name.toLowerCase();
  final hyphenated = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return hyphenated.replaceAll(RegExp(r'^-+|-+$'), '');
}

ProductType _parseType(String raw) {
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

/// Parses a numeric CLI flag. Returns null if the flag was not supplied.
/// Throws [UsageException] with an actionable message on parse failure.
double? _parseDoubleFlag(ArgResults results, String flag) {
  final raw = results[flag] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    throw UsageException(
      'Expected a number for --$flag, got "$raw"',
      'Pass --$flag <number>.',
    );
  }
  return parsed;
}

/// Result of looking up a product by user-supplied query.
sealed class _Match {
  const _Match();
}

class _MatchSingle extends _Match {
  const _MatchSingle(this.product);
  final Product product;
}

class _MatchNone extends _Match {
  const _MatchNone();
}

class _MatchMultiple extends _Match {
  const _MatchMultiple(this.candidates);
  final List<Product> candidates;
}

/// Looks up a product by query using the precedence rules from the spec:
/// exact ID → exact name (case-insensitive) → unique case-insensitive
/// substring. Returns [_MatchMultiple] when the substring match is ambiguous.
_Match _findByQuery(List<Product> products, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return const _MatchNone();

  for (final p in products) {
    if (p.id == query) return _MatchSingle(p);
  }
  for (final p in products) {
    if (p.name.toLowerCase() == q) return _MatchSingle(p);
  }
  final substringMatches =
      products.where((p) => p.name.toLowerCase().contains(q)).toList();
  if (substringMatches.isEmpty) return const _MatchNone();
  if (substringMatches.length == 1) return _MatchSingle(substringMatches.first);
  return _MatchMultiple(substringMatches);
}

void _writeCandidates(List<Product> candidates) {
  stderr.writeln('Did you mean one of:');
  final widest = candidates
      .map((p) => p.name.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  for (final p in candidates) {
    final paddedName = p.name.padRight(widest);
    stderr.writeln('  $paddedName  (id: ${p.id})');
  }
  stderr.writeln('');
  stderr.writeln('Re-run with the exact name in quotes.');
}

String _typeLabel(ProductType type) {
  return switch (type) {
    ProductType.gel => 'Gels',
    ProductType.liquid => 'Drink Mixes',
    ProductType.solid => 'Bars & Solids',
    ProductType.chew => 'Chews',
    ProductType.realFood => 'Real Food',
  };
}

/// Formats a numeric quantity without a trailing ".0" when the value is
/// integer-valued, so confirmation lines read "45g" instead of "45.0g".
String _numberLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Looks up a built-in by id. Used to tell override-of-built-in apart from a
/// plain user product when choosing confirmation wording.
bool _isOverrideOfBuiltIn(String id) {
  for (final p in builtInProducts) {
    if (p.id == id) return true;
  }
  return false;
}

/// Validates carb/caffeine/water ranges and glucose+fructose consistency
/// on the finalized product. The sum check runs unconditionally: Product's
/// constructor defaults glucose to carbs and fructose to 0, so a freshly
/// added product with no sugars given passes (glucose+fructose == carbs).
/// For edit, the merged product reflects inherited sugars, so the check
/// catches the case where the caller changes carbs without updating sugars.
String? _validateProduct(Product product) {
  if (product.carbsPerServing <= 0) {
    return '--carbs must be greater than 0, got ${product.carbsPerServing}.';
  }
  if (product.caffeineMg < 0) {
    return '--caffeine must be >= 0, got ${product.caffeineMg}.';
  }
  if (product.waterRequiredMl < 0) {
    return '--water must be >= 0, got ${product.waterRequiredMl}.';
  }
  final sum = product.glucoseGrams + product.fructoseGrams;
  if ((sum - product.carbsPerServing).abs() > 1.0) {
    return 'glucose + fructose ($sum g) must equal --carbs '
        '(${product.carbsPerServing} g) within 1 g tolerance.';
  }
  return null;
}

class _ProductsListCommand extends Command<void> {
  _ProductsListCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'list';

  @override
  final String description = 'List all available nutrition products';

  @override
  Future<void> run() async {
    await withFriendlyErrors(() async {
      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final grouped = <ProductType, List<Product>>{};
      for (final p in all) {
        grouped.putIfAbsent(p.type, () => []).add(p);
      }
      for (final type in ProductType.values) {
        final products = grouped[type];
        if (products == null || products.isEmpty) continue;
        stdout.writeln('${_typeLabel(type)}:');
        for (final p in products) {
          final tag = p.isBuiltIn ? '' : ' [custom]';
          stdout.writeln(
            '  ${p.name} — ${p.carbsPerServing}g carbs/serving$tag',
          );
        }
      }
    });
  }
}

class _ProductsShowCommand extends Command<void> {
  _ProductsShowCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'show';

  @override
  final String description = 'Show details of a specific product';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('show invoked without parsed arguments');
    }
    final query = results.rest.join(' ').trim();
    if (query.isEmpty) {
      throw UsageException(
        'Missing product query.',
        'Usage: fuel products show <name-or-id>',
      );
    }

    await withFriendlyErrors(() async {
      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final match = _findByQuery(all, query);
      switch (match) {
        case _MatchNone():
          exitWith(kExitUsage, 'No product matched: $query');
        case _MatchMultiple(:final candidates):
          _writeCandidates(candidates);
          exitCode = kExitUsage;
        case _MatchSingle(:final product):
          stdout.writeln('Name: ${product.name}');
          if (product.brand != null) {
            stdout.writeln('Brand: ${product.brand}');
          }
          stdout.writeln('Type: ${product.type.name}');
          stdout.writeln('Carbs/serving: ${product.carbsPerServing}g');
          stdout.writeln('  Glucose: ${product.glucoseGrams}g');
          stdout.writeln('  Fructose: ${product.fructoseGrams}g');
          if (product.caffeineMg > 0) {
            stdout.writeln('Caffeine: ${product.caffeineMg}mg');
          }
          if (product.waterRequiredMl > 0) {
            stdout.writeln('Water needed: ${product.waterRequiredMl}ml');
          }
          if (product.servingDescription != null) {
            stdout.writeln('Serving: ${product.servingDescription}');
          }
          stdout.writeln(
            'Source: ${product.isBuiltIn ? "built-in" : "custom"}',
          );
      }
    });
  }
}

class _ProductsAddCommand extends Command<void> {
  _ProductsAddCommand(this._storage) {
    argParser
      ..addOption('name', help: 'Product name.')
      ..addOption(
        'type',
        help: 'Product type (gel/liquid/solid/chew/real_food).',
      )
      ..addOption('carbs', help: 'Carbs per serving (g).')
      ..addOption('glucose', help: 'Glucose/maltodextrin grams.')
      ..addOption('fructose', help: 'Fructose grams.')
      ..addOption('caffeine', help: 'Caffeine milligrams.')
      ..addOption('water', help: 'Water required (ml).')
      ..addOption('serving', help: 'Serving description.')
      ..addOption('brand', help: 'Brand name.')
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing user product with the same derived ID.',
      );
  }

  final StorageAdapter _storage;

  @override
  final String name = 'add';

  @override
  final String description = 'Add a custom nutrition product';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('add invoked without parsed arguments');
    }

    final rawName = results['name'] as String?;
    final rawType = results['type'] as String?;
    if (rawName == null || rawName.trim().isEmpty) {
      throw UsageException(
        'Missing --name.',
        'Pass --name "<product name>".',
      );
    }
    if (rawType == null) {
      throw UsageException(
        'Missing --type.',
        'Pass --type <gel|liquid|solid|chew|real_food>.',
      );
    }
    final type = _parseType(rawType);

    final carbs = _parseDoubleFlag(results, 'carbs');
    if (carbs == null) {
      throw UsageException(
        'Missing --carbs.',
        'Pass --carbs <grams per serving>.',
      );
    }
    final glucose = _parseDoubleFlag(results, 'glucose');
    final fructose = _parseDoubleFlag(results, 'fructose');
    final caffeine = _parseDoubleFlag(results, 'caffeine');
    final water = _parseDoubleFlag(results, 'water');
    final force = results['force'] as bool;

    final slug = _slugify(rawName);
    if (slug.isEmpty) {
      throw UsageException(
        '--name must contain at least one alphanumeric character, got '
            '"$rawName".',
        'Pass a name like "My Mix 45".',
      );
    }
    final newId = 'user-$slug';

    final product = Product(
      id: newId,
      name: rawName,
      brand: results['brand'] as String?,
      type: type,
      carbsPerServing: carbs,
      glucoseGrams: glucose,
      fructoseGrams: fructose ?? 0.0,
      caffeineMg: caffeine ?? 0.0,
      waterRequiredMl: water ?? 0.0,
      servingDescription: results['serving'] as String?,
    );

    final validationError = _validateProduct(product);
    if (validationError != null) {
      exitWith(kExitUsage, validationError);
      return;
    }

    await withFriendlyErrors(() async {
      final existing = await _storage.loadUserProducts();
      final existingIds = {for (final p in existing) p.id};
      final builtInIds = {for (final p in builtInProducts) p.id};
      final collides =
          existingIds.contains(newId) || builtInIds.contains(newId);
      if (collides && !force) {
        exitWith(
          kExitUsage,
          'A product with id "$newId" already exists. Pass --force to '
          'overwrite or choose a different --name.',
        );
        return;
      }
      final updated = [
        ...existing.where((p) => p.id != newId),
        product,
      ];
      await _storage.saveUserProducts(updated);
      stdout.writeln(
        'Added "${product.name}" (custom ${product.type.name}, '
        '${_numberLabel(product.carbsPerServing)}g carbs).',
      );
    });
  }
}

class _ProductsEditCommand extends Command<void> {
  _ProductsEditCommand(this._storage) {
    argParser
      ..addOption('name', help: 'Rename the product.')
      ..addOption('brand', help: 'New brand name.')
      ..addOption('carbs', help: 'New carbs per serving (g).')
      ..addOption('glucose', help: 'New glucose grams.')
      ..addOption('fructose', help: 'New fructose grams.')
      ..addOption('caffeine', help: 'New caffeine milligrams.')
      ..addOption('water', help: 'New water required (ml).')
      ..addOption('serving', help: 'New serving description.');
  }

  final StorageAdapter _storage;

  @override
  final String name = 'edit';

  @override
  final String description = 'Edit a product (built-ins become user overrides)';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('edit invoked without parsed arguments');
    }
    final query = results.rest.join(' ').trim();
    if (query.isEmpty) {
      throw UsageException(
        'Missing product query.',
        'Usage: fuel products edit <name-or-id> [--carbs N ...]',
      );
    }

    final newCarbs = _parseDoubleFlag(results, 'carbs');
    final newGlucose = _parseDoubleFlag(results, 'glucose');
    final newFructose = _parseDoubleFlag(results, 'fructose');
    final newCaffeine = _parseDoubleFlag(results, 'caffeine');
    final newWater = _parseDoubleFlag(results, 'water');
    final newName = results['name'] as String?;
    final newBrand = results['brand'] as String?;
    final newServing = results['serving'] as String?;

    await withFriendlyErrors(() async {
      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final match = _findByQuery(all, query);

      final Product target;
      switch (match) {
        case _MatchNone():
          exitWith(kExitUsage, 'No product matched: $query');
          return;
        case _MatchMultiple(:final candidates):
          _writeCandidates(candidates);
          exitCode = kExitUsage;
          return;
        case _MatchSingle(:final product):
          target = product;
      }

      // copyWith cannot currently clear a field back to null — passing
      // null keeps the previous value. See TODO(clear-field) below.
      final Product updated;
      final bool wasBuiltInBeforeEdit = target.isBuiltIn;
      final bool wasExistingOverride =
          !target.isBuiltIn && _isOverrideOfBuiltIn(target.id);
      if (wasBuiltInBeforeEdit) {
        // The override keeps the built-in's id so mergeProducts shadows the
        // built-in by exact-id match. No CLI naming convention leaks into
        // core's merge logic.
        updated = target.copyWith(
          isBuiltIn: false,
          name: newName,
          brand: newBrand,
          carbsPerServing: newCarbs,
          glucoseGrams: newGlucose,
          fructoseGrams: newFructose,
          caffeineMg: newCaffeine,
          waterRequiredMl: newWater,
          servingDescription: newServing,
        );
      } else {
        updated = target.copyWith(
          name: newName,
          brand: newBrand,
          carbsPerServing: newCarbs,
          glucoseGrams: newGlucose,
          fructoseGrams: newFructose,
          caffeineMg: newCaffeine,
          waterRequiredMl: newWater,
          servingDescription: newServing,
        );
      }

      final validationError = _validateProduct(updated);
      if (validationError != null) {
        exitWith(kExitUsage, validationError);
        return;
      }

      final replaced = [
        ...userProducts.where((p) => p.id != updated.id),
        updated,
      ];
      await _storage.saveUserProducts(replaced);

      final String message;
      if (wasBuiltInBeforeEdit) {
        message = 'Override created for "${updated.name}".';
      } else if (wasExistingOverride) {
        message = 'Updated override for "${updated.name}".';
      } else {
        message = 'Updated "${updated.name}".';
      }
      stdout.writeln(message);
      // TODO(clear-field): Product.copyWith cannot clear optional fields
      // back to null. Editing away a brand or serving description is not
      // yet supported.
    });
  }
}

class _ProductsRemoveCommand extends Command<void> {
  _ProductsRemoveCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'remove';

  @override
  final String description = 'Remove a user product';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('remove invoked without parsed arguments');
    }
    final query = results.rest.join(' ').trim();
    if (query.isEmpty) {
      throw UsageException(
        'Missing product query.',
        'Usage: fuel products remove <name-or-id>',
      );
    }

    await withFriendlyErrors(() async {
      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final match = _findByQuery(all, query);
      switch (match) {
        case _MatchNone():
          exitWith(kExitUsage, 'No product matched: $query');
        case _MatchMultiple(:final candidates):
          _writeCandidates(candidates);
          exitCode = kExitUsage;
        case _MatchSingle(:final product):
          if (product.isBuiltIn) {
            exitWith(
              kExitUsage,
              "Cannot remove built-in product. Use 'fuel products edit' "
              'to override it.',
            );
            return;
          }
          final isRevert = _isOverrideOfBuiltIn(product.id);
          final updated =
              userProducts.where((p) => p.id != product.id).toList();
          await _storage.saveUserProducts(updated);
          if (isRevert) {
            stdout.writeln(
              'Reverted override — "${product.name}" restored to built-in.',
            );
          } else {
            stdout.writeln('Removed "${product.name}".');
          }
      }
    });
  }
}

class _ProductsResetCommand extends Command<void> {
  _ProductsResetCommand(
    this._storage, {
    required IsTtyProbe isTty,
    LineReader? readLine,
  })  : _isTty = isTty,
        _readLine = readLine {
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Skip the confirmation prompt.',
    );
  }

  final StorageAdapter _storage;
  final IsTtyProbe _isTty;
  final LineReader? _readLine;

  @override
  final String name = 'reset';

  @override
  final String description =
      'Remove all user products and restore built-in defaults';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('reset invoked without parsed arguments');
    }
    final yes = results['yes'] as bool;

    if (!yes) {
      if (!_isTty()) {
        exitWith(
          kExitNoInput,
          'Interactive input requires a TTY. Pass --yes to skip the '
          'confirmation prompt.',
        );
        return;
      }
      try {
        final confirmed = promptBool(
          'Remove all user products and restore built-in defaults?',
          defaultValue: false,
          readLine: _readLine,
        );
        if (!confirmed) {
          stdout.writeln('Reset cancelled.');
          return;
        }
      } on NoTerminalException {
        exitWith(
          kExitNoInput,
          'No input available. Pass --yes to skip the confirmation prompt.',
        );
        return;
      } on PromptAbortedException catch (e) {
        exitWith(kExitUsage, e.message);
        return;
      }
    }

    await withFriendlyErrors(() async {
      final existing = await _storage.loadUserProducts();
      await _storage.saveUserProducts(const []);
      if (existing.isEmpty) {
        stdout.writeln('No user products to clear.');
      } else {
        stdout.writeln('Cleared ${existing.length} user product(s).');
      }
    });
  }
}
