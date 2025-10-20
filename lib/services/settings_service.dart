import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/app_state.dart';
import 'keyboard_service.dart';

class SettingsService {
  static SettingsService? _instance;
  SettingsService._internal();

  static SettingsService get instance {
    _instance ??= SettingsService._internal();
    return _instance!;
  }

  static const String _keyAutoKeyboard = 'auto_keyboard_enabled';
  static const String _keySupabaseUrl = 'supabase_url';
  static const String _keySupabaseAnonKey = 'supabase_anon_key';
  static const String _keyAppMode = 'app_mode';

  Future<void> loadSettings(AppState appState) async {
    final prefs = await SharedPreferences.getInstance();

    // Load auto keyboard setting
    final autoKeyboard = prefs.getBool(_keyAutoKeyboard) ?? false;
    appState.setAutoKeyboard(autoKeyboard);
    KeyboardService.instance.setAutoKeyboardEnabled(autoKeyboard);

    // Load app mode
    final modeString = prefs.getString(_keyAppMode) ?? 'remote';
    final mode = modeString == 'remote' ? AppMode.remote : AppMode.server;
    appState.setMode(mode);
  }

  Future<void> setAutoKeyboardEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoKeyboard, enabled);
    KeyboardService.instance.setAutoKeyboardEnabled(enabled);
  }

  Future<bool> getAutoKeyboardEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoKeyboard) ?? false;
  }

  Future<void> setSupabaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySupabaseUrl, url);
  }

  Future<String> getSupabaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySupabaseUrl) ??
           dotenv.env['SUPABASE_URL'] ??
           'https://garofalohouse.ddns.net:8443';
  }

  Future<void> setSupabaseAnonKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySupabaseAnonKey, key);
  }

  Future<String> getSupabaseAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySupabaseAnonKey) ??
           dotenv.env['SUPABASE_ANON_KEY'] ??
           'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MzIxMjQwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';
  }

  Future<void> setAppMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppMode, mode == AppMode.remote ? 'remote' : 'server');
  }

  Future<AppMode> getAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_keyAppMode) ?? 'remote';
    return modeString == 'remote' ? AppMode.remote : AppMode.server;
  }

  // Force reset to local database configuration
  Future<void> resetToLocalDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySupabaseUrl);
    await prefs.remove(_keySupabaseAnonKey);
  }

  // Complete reset - clears ALL app data (including SharedPreferences)
  // Use this when you want to start fresh as if the app was just installed
  Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}