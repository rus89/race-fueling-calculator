// ABOUTME: Shared test helper that captures stdout and stderr via IOOverrides.
// ABOUTME: Used by command tests to assert on in-process output without subprocess.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CapturedOutput {
  final String stdout;
  final String stderr;

  CapturedOutput({required this.stdout, required this.stderr});
}

/// Captures writes to `stdout` and `stderr` made within [action].
///
/// Works by installing an [IOOverrides] scope that redirects the global
/// `stdout` and `stderr` to in-memory buffers. Only writes performed via
/// the overridden `IOOverrides.current` accessors are captured — direct
/// writes to the original `stdioType` file descriptors are not.
Future<CapturedOutput> captureOutput(
  Future<void> Function() action,
) async {
  final outBuffer = StringBuffer();
  final errBuffer = StringBuffer();

  await IOOverrides.runZoned(
    () async {
      await action();
    },
    stdout: () => _BufferedStdout(outBuffer),
    stderr: () => _BufferedStdout(errBuffer),
  );

  return CapturedOutput(
    stdout: outBuffer.toString(),
    stderr: errBuffer.toString(),
  );
}

class _BufferedStdout implements Stdout {
  _BufferedStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  void writeln([Object? object = '']) {
    _buffer.write(object);
    _buffer.write('\n');
  }

  @override
  void writeAll(Iterable objects, [String sep = '']) {
    var first = true;
    for (final o in objects) {
      if (!first) _buffer.write(sep);
      _buffer.write(o);
      first = false;
    }
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
  }

  @override
  void add(List<int> data) {
    _buffer.write(utf8.decode(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future.value();

  @override
  Future<void> flush() async {}

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => this;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  int get terminalColumns => 80;

  @override
  int get terminalLines => 24;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
