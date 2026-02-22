import 'package:flutter/foundation.dart';
import 'dart:async';

class AppDebugger {
  static final AppDebugger _instance = AppDebugger._internal();
  factory AppDebugger() => _instance;
  AppDebugger._internal();

  final List<String> _logs = [];
  final StreamController<List<String>> _logStreamController =
      StreamController<List<String>>.broadcast();

  Stream<List<String>> get logStream => _logStreamController.stream;
  List<String> get currentLogs => List.unmodifiable(_logs);

  void log(String message) {
    final timestamp = DateTime.now().toString().split(' ').last.substring(0, 8);
    final formatted = '[$timestamp] $message';
    _logs.add(formatted);
    if (_logs.length > 500) _logs.removeAt(0);
    _logStreamController.add(_logs);
    if (kDebugMode) {
      print('DEBUG: $message');
    }
  }

  void clear() {
    _logs.clear();
    _logStreamController.add(_logs);
  }
}

final logger = AppDebugger();
