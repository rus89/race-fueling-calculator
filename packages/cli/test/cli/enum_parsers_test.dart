// ABOUTME: Tests for the shared enum flag parsers covering Strategy,
// ABOUTME: TimelineMode, and ProductType mappings and error messages.
import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/enum_parsers.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

void main() {
  group('parseStrategyFlag', () {
    test('maps steady/front-load/back-load to enum values', () {
      expect(parseStrategyFlag('steady'), Strategy.steady);
      expect(parseStrategyFlag('front-load'), Strategy.frontLoad);
      expect(parseStrategyFlag('back-load'), Strategy.backLoad);
    });

    test('accepts underscore form equivalently to hyphen form', () {
      expect(parseStrategyFlag('front_load'), Strategy.frontLoad);
      expect(parseStrategyFlag('back_load'), Strategy.backLoad);
    });

    test('rejects "custom" with an explanatory UsageException', () {
      expect(
        () => parseStrategyFlag('custom'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('custom'))
              .having((e) => e.message, 'message', contains('curve segments')),
        ),
      );
    });

    test('rejects unknown values listing the valid ones', () {
      expect(
        () => parseStrategyFlag('zzz'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('steady'))
              .having((e) => e.message, 'message', contains('front-load'))
              .having((e) => e.message, 'message', contains('back-load')),
        ),
      );
    });
  });

  group('parseModeFlag', () {
    test('maps time/distance to TimelineMode', () {
      expect(parseModeFlag('time'), TimelineMode.timeBased);
      expect(parseModeFlag('distance'), TimelineMode.distanceBased);
    });

    test('rejects unknown values listing the valid ones', () {
      expect(
        () => parseModeFlag('zzz'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('time'))
              .having((e) => e.message, 'message', contains('distance')),
        ),
      );
    });
  });

  group('parseProductTypeFlag', () {
    test('maps every product type name', () {
      expect(parseProductTypeFlag('gel'), ProductType.gel);
      expect(parseProductTypeFlag('liquid'), ProductType.liquid);
      expect(parseProductTypeFlag('solid'), ProductType.solid);
      expect(parseProductTypeFlag('chew'), ProductType.chew);
      expect(parseProductTypeFlag('real_food'), ProductType.realFood);
    });

    test('rejects unknown values listing the valid ones', () {
      expect(
        () => parseProductTypeFlag('zzz'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('gel'))
              .having((e) => e.message, 'message', contains('liquid'))
              .having((e) => e.message, 'message', contains('solid'))
              .having((e) => e.message, 'message', contains('chew'))
              .having((e) => e.message, 'message', contains('real_food')),
        ),
      );
    });
  });
}
