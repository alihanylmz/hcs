import 'dart:developer' as developer;

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  void debug(
    String event, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      AppLogLevel.debug,
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void info(String event, {Map<String, Object?>? data}) {
    _write(AppLogLevel.info, event, data: data);
  }

  void warning(
    String event, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      AppLogLevel.warning,
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String event, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      AppLogLevel.error,
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _write(
    AppLogLevel level,
    String event, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      _formatMessage(event, data),
      name: scope,
      level: _toDeveloperLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _formatMessage(String event, Map<String, Object?>? data) {
    if (data == null || data.isEmpty) {
      return event;
    }

    final details = data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    return '$event | $details';
  }

  int _toDeveloperLevel(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return 500;
      case AppLogLevel.info:
        return 800;
      case AppLogLevel.warning:
        return 900;
      case AppLogLevel.error:
        return 1000;
    }
  }
}
