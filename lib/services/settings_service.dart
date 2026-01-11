//settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static const _keyThreshold = 'orivis_threshold'; //Store confidence threshold
  static const _keyPrefillEnabled = 'orivis_prefill_enabled'; //Store prefill toggle
  static const _keyDefaults = 'orivis_defaults'; //Store form defaults
  static const _keyHaptics = 'orivis_haptics_enabled'; //Store haptics toggle
  static const _keySwipeHintShown = 'orivis_swipe_hint_shown'; //Store swipe hint
  static const _keyRetentionPolicy = 'orivis_retention_policy'; //Store retention policy

  ThemeMode _themeMode = ThemeMode.system;

  Future<double> get() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    return p.getDouble(_keyThreshold) ?? 0.1; //Return threshold
  }

  Future<void> set(double val) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setDouble(_keyThreshold, val); //Persist threshold
  }

  Future<bool> getPrefillEnabled() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    return p.getBool(_keyPrefillEnabled) ?? true; //Prefill default true
  }

  Future<void> setPrefillEnabled(bool v) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setBool(_keyPrefillEnabled, v); //Persist toggle
  }

  Future<Map<String, String>> getDefaults() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    final json = p.getString(_keyDefaults); //Read JSON
    if (json == null || json.isEmpty) return {}; //No defaults
    try {
      final map = Map<String, dynamic>.from((await Future.value(jsonDecode(json))) as Map<String, dynamic>);
      return map.map((k, v) => MapEntry(k, (v ?? '').toString())); //Convert to string map
    } catch (_) {
      return {}; //On parse failure
    }
  }

  Future<void> setDefaults(Map<String, String> values) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setString(_keyDefaults, jsonEncode(values)); //Persist JSON
  }

  Future<bool> getHapticsEnabled() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    return p.getBool(_keyHaptics) ?? true; //Haptics default true
  }

  Future<void> setHapticsEnabled(bool v) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setBool(_keyHaptics, v); //Persist toggle
  }

  Future<bool> getSwipeHintShown() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    return p.getBool(_keySwipeHintShown) ?? false; //Default not shown
  }

  Future<void> setSwipeHintShown(bool v) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setBool(_keySwipeHintShown, v); //Persist flag
  }

  Future<String> getRetentionPolicy() async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    return p.getString(_keyRetentionPolicy) ?? 'forever'; //Default forever
  }

  Future<void> setRetentionPolicy(String v) async {
    final p = await SharedPreferences.getInstance(); //Load prefs
    await p.setString(_keyRetentionPolicy, v); //Persist policy
  }

  Future<ThemeMode> themeMode() async => _themeMode;

  Future<void> updateThemeMode(ThemeMode theme) async {
    _themeMode = theme;
  }
}