import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  static Future<bool> requestCameraPermission() async =>
      (await ph.Permission.camera.request()).isGranted;

  static Future<bool> requestPhotosPermission() async {
    if (Platform.isAndroid) {
      final photos = await ph.Permission.photos.request(); // Android 13+
      if (photos.isGranted) return true;
      final storage = await ph.Permission.storage.request(); // Pre-Android 13 fallback
      return storage.isGranted;
    }
    return (await ph.Permission.photos.request()).isGranted;
  }

  static Future<bool> ensureCameraPrompt() async {
    final status = await ph.Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) return false;
    return (await ph.Permission.camera.request()).isGranted;
  }

  static Future<bool> ensurePhotosPrompt() async {
    if (await requestPhotosPermission()) return true;
    final status = Platform.isAndroid
        ? await ph.Permission.storage.status
        : await ph.Permission.photos.status;
    return status.isGranted || status.isLimited;
  }

  static Future<bool> isCameraGranted() async =>
      (await ph.Permission.camera.status).isGranted;

  static Future<bool> isPhotosGranted() async {
    if (Platform.isAndroid) {
      final photos = await ph.Permission.photos.status;
      final storage = await ph.Permission.storage.status;
      return photos.isGranted || storage.isGranted;
    }
    return (await ph.Permission.photos.status).isGranted;
  }

  static Future<bool> openAppSettings() async => ph.openAppSettings();

  static Future<ph.PermissionStatus> cameraStatus() async =>
      await ph.Permission.camera.status;
}
