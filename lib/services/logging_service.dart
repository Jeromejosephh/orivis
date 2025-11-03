//logging_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoggingService {
  LoggingService._(); //Private constructor
  static final instance = LoggingService._(); //Singleton instance

  static const _logFileName = 'logs/orivis.log'; //Log file relative path
  static const _maxSizeBytes = 1024 * 1024; //Rotate at ~1MB

  Future<File> _logFile() async {
    final dir = await getApplicationSupportDirectory(); //App support dir
    final f = File('${dir.path}/$_logFileName'); //Compose file path
    if (!await f.parent.exists()) { await f.parent.create(recursive: true); } //Ensure folder
    if (!await f.exists()) { await f.create(recursive: true); } //Ensure file
    return f; //Return handle
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    try {
      final f = await _logFile(); //Ensure file exists
      try {
        if (await f.length() > _maxSizeBytes) {
          final rotated = File('${f.path}.1'); //Rotate old file
          if (await rotated.exists()) { await rotated.delete(); }
          await f.rename(rotated.path);
          await f.create(recursive: true);
        }
      } catch (_) {}
      final ts = DateTime.now().toIso8601String(); //Timestamp
      await f.writeAsString('[$ts][$level] $message\n', mode: FileMode.append, flush: true); //Append entry
    } catch (_) {
    }
  }

  Future<File?> exportLogFile() async {
    try {
      final f = await _logFile(); //Get handle
      if (await f.exists()) return f; //Return file if exists
    } catch (_) {}
    return null; //Return null when unavailable
  }

  Future<void> clear() async {
    try {
      final f = await _logFile(); //Get handle
      if (await f.exists()) {
        await f.writeAsString('', flush: true); //Truncate file
      }
    } catch (_) {}
  }
}