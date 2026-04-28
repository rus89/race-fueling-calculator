// ABOUTME: Tests for the shared CLI error translation helpers.
// ABOUTME: Exercises exitWith and withFriendlyErrors for common domain errors.
import 'dart:io';

import 'package:test/test.dart';
import 'package:race_fueling_cli/src/cli/errors.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';

import '../support/capture.dart';

void main() {
  setUp(() {
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
  });

  group('exitWith', () {
    test('writes the message to stderr and sets exitCode', () async {
      final captured = await captureOutput(() async {
        exitWith(kExitUsage, 'usage blew up');
      });

      expect(captured.stderr, contains('usage blew up'));
      expect(captured.stdout, isEmpty);
      expect(exitCode, kExitUsage);
    });
  });

  group('withFriendlyErrors', () {
    test('returns true on success and leaves exitCode untouched', () async {
      late final bool result;
      final captured = await captureOutput(() async {
        result = await withFriendlyErrors(() async {
          // no-op
        });
      });

      expect(result, isTrue);
      expect(exitCode, 0);
      expect(captured.stderr, isEmpty);
    });

    test('translates FormatException to exit 65 with friendly message',
        () async {
      late final bool result;
      final captured = await captureOutput(() async {
        result = await withFriendlyErrors(() async {
          throw const FormatException('bad json');
        });
      });

      expect(result, isFalse);
      expect(exitCode, kExitData);
      expect(captured.stderr, contains('bad json'));
      expect(captured.stderr, isNot(contains('Invalid data')));
    });

    test('translates FileSystemException to exit 65 with the path', () async {
      late final bool result;
      final captured = await captureOutput(() async {
        result = await withFriendlyErrors(() async {
          throw const FileSystemException('read failed', '/tmp/missing');
        });
      });

      expect(result, isFalse);
      expect(exitCode, kExitData);
      expect(captured.stderr, contains('File error'));
      expect(captured.stderr, contains('/tmp/missing'));
    });

    test('translates AssertionError to exit 65', () async {
      late final bool result;
      final captured = await captureOutput(() async {
        result = await withFriendlyErrors(() async {
          assert(false, 'invariant');
        });
      });

      expect(result, isFalse);
      expect(exitCode, kExitData);
      expect(captured.stderr, contains('Invariant violated'));
    });
  });
}
