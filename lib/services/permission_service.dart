import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  static Future<bool> requestCameraPermission() async =>
      (await ph.Permission.camera.request()).isGranted;

  static Future<bool> requestPhotosPermission() async =>
      (await ph.Permission.photos.request()).isGranted;

  static Future<bool> isCameraGranted() async =>
      (await ph.Permission.camera.status).isGranted;

  static Future<bool> isPhotosGranted() async =>
      (await ph.Permission.photos.status).isGranted;

  static Future<bool> openAppSettings() async => ph.openAppSettings();
}
