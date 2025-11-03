//data_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'logging_service.dart';

class DataService {
  static const _key = 'orivis_results'; //Prefs key for inspections list
  static const _backupFileName = 'inspections_backup.json'; //Backup file name

  Future<File> _backupFile() async {
    final dir = await getApplicationSupportDirectory(); //App support directory
    final f = File('${dir.path}/$_backupFileName'); //Backup file path
    if (!await f.exists()) {
      await f.create(recursive: true); //Create file if missing
    }
    return f;
  }

  Future<void> _persistSafely(List<String> list) async {
    try {
      final f = await _backupFile(); //Write backup first
      await f.writeAsString(jsonEncode(list), flush: true);
    } catch (e) {
      await LoggingService.instance.log('Backup write failed: $e', level: 'ERROR'); //Log backup failure
    }
    final prefs = await SharedPreferences.getInstance(); //Then write prefs
    await prefs.setStringList(_key, list);
  }

  Future<void> saveResult(
    String label,
    double conf,
    String path, {
    required String productId,
    required String batchId,
    required String station,
    String? operatorId,
    int? inferenceMs,
    String? modelFile,
    String? appVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance(); //Load current list
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode({
      'label': label, //Class label
      'confidence': conf, //Confidence score
      'imagePath': path, //Path to image file
      'productId': productId, //Product ID
      'batchId': batchId, //Batch ID
      'station': station, //Station name
      'operatorId': operatorId, //Operator identifier
      'timestamp': DateTime.now().toIso8601String(), //Creation time
      if (inferenceMs != null) 'inferenceMs': inferenceMs, //Inference time
      if (modelFile != null) 'modelFile': modelFile, //Model file name
      if (appVersion != null) 'appVersion': appVersion, //App version stamp
    }));
    await _persistSafely(list); //Persist with backup
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance(); //Read current list
    List<String> list = [];
    try {
      list = prefs.getStringList(_key) ?? []; //Load from prefs
    } catch (e) {
      await LoggingService.instance.log('SharedPreferences read failed: $e', level: 'ERROR'); //Log prefs failure
      list = [];
    }
    try {
      return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList(); //Decode items
    } catch (e) {
      await LoggingService.instance.log('Corrupted pref data detected; attempting recovery: $e', level: 'ERROR'); //Detect corruption
      try {
        final f = await _backupFile(); //Recover from backup
        if (await f.exists()) {
          final raw = await f.readAsString();
          final backupList = (jsonDecode(raw) as List).cast<String>();
          await prefs.setStringList(_key, backupList);
          return backupList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
        }
      } catch (e2) {
        await LoggingService.instance.log('Backup recovery failed: $e2', level: 'ERROR'); //Log recovery failure
      }
      return [];
    }
  }

  Future<void> delete(int index) async {
    final prefs = await SharedPreferences.getInstance(); //Load list
    final list = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < list.length) {
      list.removeAt(index); //Remove item by index
      await _persistSafely(list); //Persist with backup
    }
  }

  Future<void> update(int index, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance(); //Load list
    final list = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < list.length) {
      list[index] = jsonEncode(item); //Update item
      await _persistSafely(list); //Persist with backup
    }
  }

  Future<void> insertAt(int index, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance(); //Load list
    final list = prefs.getStringList(_key) ?? [];
    final safeIndex = index.clamp(0, list.length); //Clamp index
    list.insert(safeIndex, jsonEncode(item)); //Insert item
    await _persistSafely(list); //Persist with backup
  }

  Future<void> clearAll() async {
    await _persistSafely(<String>[]); //Clear list safely
  }

  Future<int> deleteOlderThan(DateTime cutoffDate) async {
    final prefs = await SharedPreferences.getInstance(); //Load list
    final list = prefs.getStringList(_key) ?? [];
    int deleted = 0; //Deleted counter
    final retained = <String>[]; //Items to keep

    for (final json in list) {
      try {
        final item = jsonDecode(json) as Map<String, dynamic>; //Decode entry
        final tsStr = item['timestamp'] ?? item['time']; //Support legacy key
        if (tsStr == null) {
          retained.add(json);
          continue;
        }
        final dt = DateTime.parse(tsStr.toString()); //Parse timestamp
        if (dt.isBefore(cutoffDate)) {
          final imgPath = item['imagePath'] ?? item['image']; //Image path
          if (imgPath != null && imgPath.toString().isNotEmpty) {
            try {
              final f = File(imgPath.toString()); //Image file
              if (f.existsSync()) {
                await f.delete(); //Delete image if exists
              }
            } catch (_) {
            }
          }
          deleted++; //Count deletion
        } else {
          retained.add(json); //Keep recent entries
        }
      } catch (_) {
        retained.add(json); //Keep malformed entries
      }
    }

    await _persistSafely(retained); //Persist retained items
    return deleted; //Return count
  }
}