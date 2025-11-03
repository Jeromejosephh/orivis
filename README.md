# Orivis

Orivis is a Flutter app for on-device image inspection using a TensorFlow Lite model. It runs fully offline, lets you capture or pick photos, classifies them, and saves inspection records with metadata. A retention policy and manual cleanup help manage storage.

## Features

- On-device inference with TFLite (no network required)
- Camera and gallery input
- Thresholding and simple result UI
- History with search, filters, share, and delete with undo
- Safe persistence with backup and corruption recovery
- Storage retention policy (30 days / 1 year / forever)
- Local logging with export and clear options
- About screen showing app version and model info
- **Model Diagnostics tool** for testing preprocessing and debugging predictions

## Screenshots

Place screenshots in `assets/screenshots/` and reference them below. Example layout:

<p>
	<img src="assets/screenshots/home.png" alt="Home" width="260" />
	<img src="assets/screenshots/inspect.png" alt="Inspect/Result" width="260" />
	<img src="assets/screenshots/settings.png" alt="Settings" width="260" />
	<img src="assets/screenshots/about.png" alt="About" width="260" />
</p>

## Getting started

Prerequisites:
- Flutter (stable channel)
- A device or emulator (iOS/Android)

Install dependencies and run:

```bash
flutter pub get
flutter run
```

Run checks locally:

```bash
flutter analyze
flutter test
```

## Model and labels

- Model: `assets/models/orivis_mnv3_q.tflite`
- Labels: `assets/models/labels.txt`

**Important:** This model expects **raw pixel values [0-255]** as input, not normalized values. The inference code in `lib/services/inference_service.dart` uses raw pixel values directly without normalization.

If you retrain or replace the model, ensure the preprocessing matches:
- Check what normalization your training pipeline uses
- Update `inference_service.dart` if needed
- Use the **Model Diagnostics tool** (Settings > Support & Diagnostics) to verify preprocessing is correct

Document the dataset and training steps under `training/`.

## Troubleshooting

### Model Diagnostics Tool

If the model is misclassifying obvious defects:

1. Go to **Settings > Support & Diagnostics > Model Diagnostics**
2. Pick a test image
3. The tool tests 4 different preprocessing schemes and shows which one works
4. If the wrong normalization is being used, update `inference_service.dart` accordingly

See `DIAGNOSTIC_GUIDE.md` for detailed instructions.

## Privacy

- All inference happens on-device.
- Images are stored locally for inspection history only.
- You control retention from Settings; you can clear saved data anytime.

## Project structure (partial)

- `lib/` — app source (screens, services)
- `assets/` — model and labels
- `training/` — model training scripts
- `DIAGNOSTIC_GUIDE.md` — how to use the Model Diagnostics tool
- `DIAGNOSTIC_SUMMARY.md` — technical details of the diagnostic system

## CI

This repo includes a basic GitHub Actions workflow that runs `flutter analyze` and `flutter test` on pushes and pull requests to `main`/`master`.

## App icon and splash

Provide a 1024x1024 PNG at `assets/app_icon.png`.

- Generate icons:
	- flutter pub run flutter_launcher_icons
- Generate splash:
	- flutter pub run flutter_native_splash:create

You can customize colors and images in `pubspec.yaml` under the `flutter_icons` and `flutter_native_splash` sections.

## License

MIT — see `LICENSE`.

