//export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'data_service.dart';

class ExportService {
  final DataService _data = DataService(); //Data access

  Future<File?> exportAllToCsv() async {
    final history = await _data.getAll(); //Load all inspections
    if (history.isEmpty) return null; //Return null when no data

    final buffer = StringBuffer(); //Build CSV in memory
    buffer.writeln('timestamp,label,confidence,productId,batchId,station,operatorId,imagePath'); //CSV header
    for (final it in history) {
      String esc(String? v) {
        final s = (v ?? '').replaceAll('"', '""'); //Escape quotes
        return '"$s"';
      }
      final ts = it['timestamp'] ?? '';
      final label = (it['label'] ?? '').toString();
      final conf = (it['confidence'] ?? '').toString();
      final pid = it['productId']?.toString();
      final bid = it['batchId']?.toString();
      final st = it['station']?.toString();
      final op = it['operatorId']?.toString();
      final img = it['imagePath']?.toString() ?? it['image']?.toString();
      buffer.writeln([esc(ts), esc(label), esc(conf), esc(pid), esc(bid), esc(st), esc(op), esc(img)].join(',')); //Append row
    }

    final dir = await getTemporaryDirectory(); //Temp directory
    final path = '${dir.path}/orivis_inspections.csv'; //CSV path
    final file = File(path); //File handle
    await file.writeAsString(buffer.toString()); //Write to disk
    return file; //Return created file
  }
}