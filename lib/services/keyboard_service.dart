import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class KeyboardService {
  static KeyboardService? _instance;
  KeyboardService._internal();

  static KeyboardService get instance {
    _instance ??= KeyboardService._internal();
    return _instance!;
  }

  bool _isWindowsTouchDevice = false;
  bool _autoKeyboardEnabled = false;

  bool get isWindowsTouchDevice => _isWindowsTouchDevice;
  bool get autoKeyboardEnabled => _autoKeyboardEnabled;

  Future<void> initialize() async {
    if (Platform.isWindows) {
      await _detectWindowsTouchDevice();
    }
  }

  Future<void> _detectWindowsTouchDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final windowsInfo = await deviceInfo.windowsInfo;

      // Check if the device supports touch
      // This is a basic detection - in a real app you might want more sophisticated detection
      _isWindowsTouchDevice = windowsInfo.numberOfCores > 0; // Placeholder logic

      // For more accurate detection, you could use win32 APIs
      if (Platform.isWindows) {
        try {
          // Try to detect touch capability through system metrics
          final result = await Process.run('powershell', [
            '-Command',
            '(Get-CimInstance -Class Win32_SystemEnclosure).ChassisTypes -contains 30 -or (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes -contains 30'
          ]);

          if (result.exitCode == 0 && result.stdout.toString().trim().toLowerCase() == 'true') {
            _isWindowsTouchDevice = true;
          } else {
            // Fallback: check for tablet mode or touch screen
            final touchResult = await Process.run('powershell', [
              '-Command',
              'Get-WmiObject -Class Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes'
            ]);

            if (touchResult.exitCode == 0) {
              final chassisTypes = touchResult.stdout.toString();
              // Chassis type 30 = Tablet, 31 = Convertible
              _isWindowsTouchDevice = chassisTypes.contains('30') || chassisTypes.contains('31');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error detecting Windows touch device: $e');
          }
          // Fallback to false for safety
          _isWindowsTouchDevice = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing keyboard service: $e');
      }
      _isWindowsTouchDevice = false;
    }
  }

  void setAutoKeyboardEnabled(bool enabled) {
    _autoKeyboardEnabled = enabled;
  }

  Future<void> showVirtualKeyboard() async {
    if (!Platform.isWindows || !_isWindowsTouchDevice || !_autoKeyboardEnabled) {
      return;
    }

    try {
      // Show Windows on-screen keyboard
      await Process.start('osk.exe', [], runInShell: true);
    } catch (e) {
      if (kDebugMode) {
        print('Error showing virtual keyboard: $e');
      }
    }
  }

  Future<void> hideVirtualKeyboard() async {
    if (!Platform.isWindows || !_isWindowsTouchDevice || !_autoKeyboardEnabled) {
      return;
    }

    try {
      // Close Windows on-screen keyboard
      await Process.run('taskkill', ['/f', '/im', 'osk.exe'], runInShell: true);
    } catch (e) {
      // Ignore errors when closing keyboard (it might not be open)
      if (kDebugMode) {
        print('Note: Could not close virtual keyboard (might not be open): $e');
      }
    }
  }
}