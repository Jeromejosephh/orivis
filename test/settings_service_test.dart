import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orivis/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('threshold set/get round-trips', () async {
    final s = SettingsService();
    await s.set(0.42);
    final v = await s.get();
    expect(v, closeTo(0.42, 0.0001));
  });

  test('toggles set/get round-trips', () async {
    final s = SettingsService();
    await s.setPrefillEnabled(false);
    await s.setHapticsEnabled(false);
    expect(await s.getPrefillEnabled(), isFalse);
    expect(await s.getHapticsEnabled(), isFalse);
  });

  test('retention policy set/get round-trips', () async {
    final s = SettingsService();
    await s.setRetentionPolicy('30d');
    expect(await s.getRetentionPolicy(), '30d');
    await s.setRetentionPolicy('1yr');
    expect(await s.getRetentionPolicy(), '1yr');
    await s.setRetentionPolicy('forever');
    expect(await s.getRetentionPolicy(), 'forever');
  });
}
