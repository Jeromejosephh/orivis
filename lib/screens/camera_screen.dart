//camera_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/inference_service.dart';
import 'result_screen.dart';
import '../services/logging_service.dart';
import '../services/permission_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final infer = InferenceService(); //Create inference service instance
  bool loading = true; //Track model load state
  String? err; //Hold model load error message

  @override
  void initState() {
    super.initState();
    _safeLoad(); //Start loading the AI model
  }

  Future<void> _safeLoad() async {
    try {
      await infer.load(); //Load model and labels
      if (!mounted) return; //Guard against disposed widget
      setState(() { loading = false; err = null; }); //Model ready
      await LoggingService.instance.log('Model loaded successfully'); //Log success
    } catch (e) {
      await LoggingService.instance.log('Model load failed: $e', level: 'ERROR'); //Log failure
      setState(() { loading = false; err = 'Model load failed: $e'; }); //Show error state
    }
  }

  Future<void> _choose(ImageSource src) async {
    try {
      // Request appropriate permission
      bool permissionGranted = false;
      String permissionDeniedMessage = '';

      if (src == ImageSource.camera) {
        permissionGranted = await PermissionService.requestCameraPermission();
        if (!permissionGranted) {
          permissionDeniedMessage = 'Camera access is required to capture images.\n\nPlease enable camera permissions in Settings.';
        }
      } else {
        permissionGranted = await PermissionService.requestPhotosPermission();
        if (!permissionGranted) {
          permissionDeniedMessage = 'Photo library access is required to select images.\n\nPlease enable photo library permissions in Settings.';
        }
      }

      // Show permission denied dialog if needed
      if (!permissionGranted) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Denied'),
            content: Text(permissionDeniedMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  PermissionService.openAppSettings();
                  Navigator.pop(ctx);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }

      final picker = ImagePicker();
      final x = await picker.pickImage(source: src); //Pick image from source
      if (x == null) return; //User cancelled selection
      final file = File(x.path); //Create a File handle

      late Map<String, dynamic> res; //Prepare result container
      try {
        res = await infer.classify(file); //Run on-device inference
      } catch (e) {
        await LoggingService.instance.log('Inference error: $e', level: 'ERROR'); //Log inference error
        if (!mounted) return; //Guard before dialog
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Inference Failed'),
            content: Text('The AI model encountered an error while analyzing the image.\n\nDetails: $e\n\nWould you like to retry?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retry')),
            ],
          ),
        ) ?? false;
        if (retry) {
          return _choose(src); //Retry with the same source
        }
        return; //Stop if user cancels
      }

      if (!mounted) return; //Guard after async
      await LoggingService.instance.log('Navigating to ResultScreen'); //Log navigation intent
      if (!mounted) return; //Guard again before push
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(image: file, result: res)),
      ); //Open result screen and wait until it closes
    } on PlatformException catch (e) {
      if (!mounted) return; //Guard before UI update
      String msg; //Translate camera errors to helpful text
      switch (e.code) {
        case 'camera_access_denied':
          msg = 'Camera permission denied. Please allow Camera in App Settings.';
          break;
        case 'camera_unavailable':
          msg = 'Camera unavailable. On emulators, enable a virtual camera or use Gallery.';
          break;
        default:
          msg = 'Camera error (${e.code}). If on emulator, set Back/Front camera to Emulated/Virtual Scene and cold boot.';
      }
      await LoggingService.instance.log('Camera PlatformException ${e.code}: $msg', level: 'ERROR'); //Log platform error
      if (!mounted) return; //Guard before snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); //Notify user
    } catch (e) {
      if (!mounted) return; //Guard on generic error
      await LoggingService.instance.log('Camera generic error: $e', level: 'ERROR'); //Log unexpected error
      if (!mounted) return; //Guard before snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); //Notify user
    }
  }

  @override
  void dispose() {
    infer.dispose(); //Release interpreter resources
    super.dispose(); //Dispose state
  }

  @override
  Widget build(BuildContext c) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 68,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inspect', style: Theme.of(c).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontFamily: 'SF Pro Display',
              )),
              Text('Capture or pick a photo', style: Theme.of(c).textTheme.bodySmall?.copyWith(
                color: Theme.of(c).colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              )),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator()), //Show loading spinner
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 68,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inspect', style: Theme.of(c).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontFamily: 'SF Pro Display',
              )),
              Text('Capture or pick a photo', style: Theme.of(c).textTheme.bodySmall?.copyWith(
                color: Theme.of(c).colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              )),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(err!, textAlign: TextAlign.center), //Display model load error
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () { setState(() { loading = true; err = null; }); _safeLoad(); }, //Retry model load
                child: const Text('Retry model load'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inspect', style: Theme.of(c).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              fontFamily: 'SF Pro Display',
            )),
            Text('Capture or pick a photo', style: Theme.of(c).textTheme.bodySmall?.copyWith(
              color: Theme.of(c).colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            )),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, //Center action buttons
          children: [
            // Primary action first: capture from camera
            SizedBox(
              width: 260,
              child: FilledButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Use Camera'),
                onPressed: () => _choose(ImageSource.camera), //Capture from camera
              ),
            ),
            const SizedBox(height: 12),
            // Secondary action: pick from gallery
            SizedBox(
              width: 260,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
                onPressed: () => _choose(ImageSource.gallery), //Pick from gallery
              ),
            ),
          ],
        ),
      ),
    );
  }
}