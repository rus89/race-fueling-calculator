// ABOUTME: Tests for interactive prompt helpers — parseDuration, retry logic,
// ABOUTME: range validation, and injection-based read/write seams.
import 'dart:collection';

import 'package:race_fueling_cli/src/prompts/interactive.dart';
import 'package:test/test.dart';

void main() {
  group('parseDuration', () {
    test('accepts "3h" as 3 hours', () {
      expect(parseDuration('3h'), const Duration(hours: 3));
    });

    test('accepts "3h30m" as 3h30m', () {
      expect(parseDuration('3h30m'), const Duration(hours: 3, minutes: 30));
    });

    test('accepts "90m" as 90 minutes', () {
      expect(parseDuration('90m'), const Duration(minutes: 90));
    });

    test('accepts "1:30" as 1 hour 30 minutes', () {
      expect(parseDuration('1:30'), const Duration(hours: 1, minutes: 30));
    });

    test('accepts "2:45:00" as 2 hours 45 minutes', () {
      expect(parseDuration('2:45:00'), const Duration(hours: 2, minutes: 45));
    });

    test('is whitespace-tolerant', () {
      expect(parseDuration('  3h30m  '), const Duration(hours: 3, minutes: 30));
    });

    test('returns null for empty string', () {
      expect(parseDuration(''), isNull);
    });

    test('returns null for gibberish', () {
      expect(parseDuration('banana'), isNull);
    });

    test('returns null for "1:30:45:00" (too many segments)', () {
      expect(parseDuration('1:30:45:00'), isNull);
    });

    test('returns null for "abc:def"', () {
      expect(parseDuration('abc:def'), isNull);
    });

    test('returns null when minutes >= 60 in colon form', () {
      expect(parseDuration('1:60'), isNull);
    });

    test('returns null when seconds >= 60 in colon form', () {
      expect(parseDuration('1:30:60'), isNull);
    });

    test('returns null for negative values in colon form', () {
      expect(parseDuration('-1:30'), isNull);
    });
  });

  group('promptString', () {
    test('returns the trimmed input when non-empty', () {
      final inputs = Queue<String>()..add('hello');
      final out = StringBuffer();

      final result = promptString(
        'Name',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 'hello');
    });

    test('returns default when input is empty', () {
      final inputs = Queue<String>()..add('');
      final out = StringBuffer();

      final result = promptString(
        'Name',
        defaultValue: 'Anon',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 'Anon');
    });

    test('returns default on EOF (readLine returns null)', () {
      final out = StringBuffer();

      final result = promptString(
        'Name',
        defaultValue: 'Anon',
        readLine: () => null,
        out: out,
      );

      expect(result, 'Anon');
    });

    test('returns empty string when input and default both absent (EOF)', () {
      final out = StringBuffer();

      final result = promptString(
        'Name',
        readLine: () => null,
        out: out,
      );

      expect(result, '');
    });
  });

  group('promptDouble', () {
    test('accepts a valid number on the first try', () {
      final inputs = Queue<String>()..add('75');
      final out = StringBuffer();

      final result = promptDouble(
        'Gut tolerance (g/hr)',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 75.0);
    });

    test('returns default when input is empty and default is set', () {
      final inputs = Queue<String>()..add('');
      final out = StringBuffer();

      final result = promptDouble(
        'Gut tolerance',
        defaultValue: 60.0,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 60.0);
    });

    test('retries on parse failure and eventually succeeds', () {
      final inputs = Queue<String>()
        ..add('banana')
        ..add('still bad')
        ..add('90');
      final out = StringBuffer();

      final result = promptDouble(
        'Gut tolerance',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 90.0);
      expect(out.toString(), contains('not a valid number'));
    });

    test('throws PromptAbortedException after 3 failed attempts', () {
      final inputs = Queue<String>()
        ..add('bad1')
        ..add('bad2')
        ..add('bad3');
      final out = StringBuffer();

      expect(
        () => promptDouble(
          'Gut tolerance',
          readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
          out: out,
        ),
        throwsA(isA<PromptAbortedException>()),
      );
    });

    test('returns null on EOF (readLine returns null)', () {
      final out = StringBuffer();

      final result = promptDouble(
        'Gut tolerance',
        readLine: () => null,
        out: out,
      );

      expect(result, isNull);
    });

    test('rejects values outside [min, max] and retries', () {
      final inputs = Queue<String>()
        ..add('300')
        ..add('75');
      final out = StringBuffer();

      final result = promptDouble(
        'Gut tolerance',
        min: 1,
        max: 200,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 75.0);
      expect(out.toString(), contains('between 1'));
    });
  });

  group('promptInt', () {
    test('accepts a valid integer', () {
      final inputs = Queue<String>()..add('42');
      final out = StringBuffer();

      final result = promptInt(
        'Age',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 42);
    });

    test('throws PromptAbortedException after 3 failures', () {
      final inputs = Queue<String>()
        ..add('x')
        ..add('y')
        ..add('z');
      final out = StringBuffer();

      expect(
        () => promptInt(
          'Age',
          readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
          out: out,
        ),
        throwsA(isA<PromptAbortedException>()),
      );
    });

    test('rejects values outside [min, max] and retries', () {
      final inputs = Queue<String>()
        ..add('999')
        ..add('-1')
        ..add('42');
      final out = StringBuffer();

      final result = promptInt(
        'Age',
        min: 0,
        max: 120,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 42);
      expect(out.toString(), contains('between 0'));
    });
  });

  group('promptDuration (interactive)', () {
    test('accepts a valid duration on the first try', () {
      final inputs = Queue<String>()..add('3h30m');
      final out = StringBuffer();

      final result = promptDuration(
        'Race duration',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, const Duration(hours: 3, minutes: 30));
    });

    test('retries on parse failure', () {
      final inputs = Queue<String>()
        ..add('banana')
        ..add('2:45:00');
      final out = StringBuffer();

      final result = promptDuration(
        'Race duration',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, const Duration(hours: 2, minutes: 45));
    });

    test('throws PromptAbortedException after 3 parse failures', () {
      final inputs = Queue<String>()
        ..add('banana')
        ..add('kiwi')
        ..add('mango');
      final out = StringBuffer();

      expect(
        () => promptDuration(
          'Race duration',
          readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
          out: out,
        ),
        throwsA(isA<PromptAbortedException>()),
      );
    });
  });

  group('promptBool', () {
    test('accepts "y" as true', () {
      final inputs = Queue<String>()..add('y');
      final out = StringBuffer();

      final result = promptBool(
        'Continue?',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, isTrue);
    });

    test('accepts "YES" as true (case-insensitive)', () {
      final inputs = Queue<String>()..add('YES');
      final out = StringBuffer();

      final result = promptBool(
        'Continue?',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, isTrue);
    });

    test('accepts "n" as false', () {
      final inputs = Queue<String>()..add('n');
      final out = StringBuffer();

      final result = promptBool(
        'Continue?',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, isFalse);
    });

    test('empty input returns default', () {
      final inputs = Queue<String>()..add('');
      final out = StringBuffer();

      final result = promptBool(
        'Continue?',
        defaultValue: true,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, isTrue);
    });

    test('throws PromptAbortedException after 3 invalid answers', () {
      final inputs = Queue<String>()
        ..add('maybe')
        ..add('huh')
        ..add('dunno');
      final out = StringBuffer();

      expect(
        () => promptBool(
          'Continue?',
          readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
          out: out,
        ),
        throwsA(isA<PromptAbortedException>()),
      );
    });
  });

  group('promptChoice', () {
    test('selects option by number', () {
      final inputs = Queue<String>()..add('2');
      final out = StringBuffer();

      final result = promptChoice<String>(
        'Pick one',
        ['apple', 'banana', 'cherry'],
        describe: (s) => s,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 'banana');
    });

    test('re-prompts on invalid number and succeeds', () {
      final inputs = Queue<String>()
        ..add('99')
        ..add('1');
      final out = StringBuffer();

      final result = promptChoice<String>(
        'Pick one',
        ['apple', 'banana'],
        describe: (s) => s,
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 'apple');
    });

    test('never silently picks option 1 on nonsense input', () {
      final inputs = Queue<String>()
        ..add('banana')
        ..add('foo')
        ..add('bar');
      final out = StringBuffer();

      expect(
        () => promptChoice<String>(
          'Pick one',
          ['apple', 'banana'],
          describe: (s) => s,
          readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
          out: out,
        ),
        throwsA(isA<PromptAbortedException>()),
      );
    });

    test('returns default on EOF when default is provided', () {
      final out = StringBuffer();

      final result = promptChoice<String>(
        'Pick one',
        ['apple', 'banana'],
        describe: (s) => s,
        defaultOption: 'banana',
        readLine: () => null,
        out: out,
      );

      expect(result, 'banana');
    });

    test('returns default on empty input when default is provided', () {
      final inputs = Queue<String>()..add('');
      final out = StringBuffer();

      final result = promptChoice<String>(
        'Pick one',
        ['apple', 'banana'],
        describe: (s) => s,
        defaultOption: 'apple',
        readLine: () => inputs.isEmpty ? null : inputs.removeFirst(),
        out: out,
      );

      expect(result, 'apple');
    });
  });
}
