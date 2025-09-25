import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';

class SyncService {
  static SyncService? _instance;
  SyncService._internal();

  static SyncService get instance {
    _instance ??= SyncService._internal();
    return _instance!;
  }

  Timer? _jobRequestPollingTimer;
  Timer? _jobFileMonitorTimer;
  Timer? _qualityRefreshTimer;
  Timer? _counterTimer;

  AppState? _appState;

  Future<void> initialize(AppState appState) async {
    _appState = appState;

    // Load counter state
    await _loadCounterState();

    // Start global services
    _startJobRequestPolling();
    _startJobFileMonitoring();
    _startQualityRefresh();
    _startCounterTimer();
  }

  void dispose() {
    _jobRequestPollingTimer?.cancel();
    _jobFileMonitorTimer?.cancel();
    _qualityRefreshTimer?.cancel();
    _counterTimer?.cancel();
  }

  void _startJobRequestPolling() {
    _jobRequestPollingTimer?.cancel();
    _jobRequestPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Check job requests logic here
        await _checkJobRequests();
      } catch (e) {
        if (kDebugMode) {
          print('Error in job request polling: $e');
        }
      }
    });
  }

  void _startJobFileMonitoring() {
    _jobFileMonitorTimer?.cancel();
    _jobFileMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Monitor job files logic here
        await _monitorJobFiles();
      } catch (e) {
        if (kDebugMode) {
          print('Error in job file monitoring: $e');
        }
      }
    });
  }

  void _startQualityRefresh() {
    _qualityRefreshTimer?.cancel();
    _qualityRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Quality data refresh logic here
        await _refreshQualityData();
      } catch (e) {
        if (kDebugMode) {
          print('Error in quality refresh: $e');
        }
      }
    });
  }

  void _startCounterTimer() {
    _counterTimer?.cancel();
    _counterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_appState?.isCounterRunning == true && _appState?.manualCounterStartTime != null) {
        final now = DateTime.now();
        final elapsed = now.difference(_appState!.manualCounterStartTime!).inSeconds;
        _appState!.updateCounterTime(elapsed);
        _saveCounterState();
      }
    });
  }

  Future<void> _checkJobRequests() async {
    if (_appState == null || _appState!.currentMode != AppMode.server) return;

    try {
      if (kDebugMode) {
        print('🔄 SyncService: Controllo job requests nel database...');
      }

      // Use AppModeService to get pending requests
      final requests = await _getPendingRequests();

      if (requests.isNotEmpty) {
        if (kDebugMode) {
          print('📨 SyncService: Trovate ${requests.length} richieste job pending');
        }

        // Process each pending request
        for (final request in requests) {
          if (request['status'] == 'pending') {
            if (kDebugMode) {
              print('🔄 SyncService: Elaborazione richiesta job: ${request['id']}');
            }
            await _processJobRequest(request);
          }
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ SyncService: Nessuna richiesta job pending trovata');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore controllo job requests: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingRequests() async {
    try {
      // This is a simplified version - you might need to implement proper Supabase client access
      // For now, return empty list to avoid errors
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore recupero richieste: $e');
      }
      return [];
    }
  }

  Future<void> _processJobRequest(Map<String, dynamic> request) async {
    try {
      // This would contain the job processing logic
      // Mark as processing, generate file, mark as completed
      if (kDebugMode) {
        print('🔄 SyncService: Processando richiesta ${request['id']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore processamento richiesta: $e');
      }
    }
  }

  Future<void> _monitorJobFiles() async {
    if (_appState == null) return;

    // Placeholder for job file monitoring logic
    // This would contain the file system watching logic
  }

  Future<void> _refreshQualityData() async {
    if (_appState == null) return;

    // Placeholder for quality data refresh logic
    // This would contain CSV monitoring and database sync logic
  }

  Future<void> _loadCounterState() async {
    if (_appState == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final startTimeString = prefs.getString('manual_counter_start_time');
      final pieces = prefs.getInt('manual_pieces_at_start') ?? 0;
      final parts = prefs.getInt('manual_parts_at_start') ?? 0;
      final machine = prefs.getString('manual_machine_at_start') ?? '';
      final isRunning = prefs.getBool('counter_is_running') ?? false;

      if (startTimeString != null && isRunning) {
        final startTime = DateTime.parse(startTimeString);
        _appState!.startManualCounter(startTime, pieces, parts, machine);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading counter state: $e');
      }
    }
  }

  Future<void> _saveCounterState() async {
    if (_appState == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_appState!.manualCounterStartTime != null) {
        await prefs.setString('manual_counter_start_time', _appState!.manualCounterStartTime!.toIso8601String());
        await prefs.setInt('manual_pieces_at_start', _appState!.manualPiecesAtStart);
        await prefs.setInt('manual_parts_at_start', _appState!.manualPartsAtStart);
        await prefs.setString('manual_machine_at_start', _appState!.manualMachineAtStart);
        await prefs.setBool('counter_is_running', _appState!.isCounterRunning);
      } else {
        await prefs.remove('manual_counter_start_time');
        await prefs.remove('manual_pieces_at_start');
        await prefs.remove('manual_parts_at_start');
        await prefs.remove('manual_machine_at_start');
        await prefs.setBool('counter_is_running', false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving counter state: $e');
      }
    }
  }

  Future<void> resetCounter() async {
    if (_appState == null) return;

    _appState!.resetManualCounter();
    await _saveCounterState();

    // Notification disabled
  }

  Future<void> stopCounter() async {
    if (_appState == null) return;

    _appState!.stopCounter();
    await _saveCounterState();
  }

  Future<void> startCounter(int pieces, int parts, String machine) async {
    if (_appState == null) return;

    final now = DateTime.now();
    _appState!.startManualCounter(now, pieces, parts, machine);
    await _saveCounterState();
  }
}