import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
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
      final supabase = Supabase.instance.client;

      if (kDebugMode) {
        print('🔍 SyncService: Esecuzione query job_requests...');
      }

      final response = await supabase
          .from('job_requests')
          .select()
          .eq('status', 'pending')
          .order('requested_at', ascending: true)
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('✅ SyncService: Query completata, ${response.length} risultati');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore recupero richieste: $e');
        if (e.toString().contains('timeout')) {
          print('⚠️ SyncService: Timeout connessione database - controllare configurazione');
        }
      }
      return [];
    }
  }

  Future<void> _processJobRequest(Map<String, dynamic> request) async {
    try {
      if (kDebugMode) {
        print('🔄 SyncService: Processando richiesta ${request['id']}');
      }

      // Mark as processing
      await _markRequestProcessing(request['id']);

      // Generate job file
      final success = await _generateJobFile(
        request['article_code'],
        request['lot'],
        request['pieces']
      );

      if (success) {
        // Mark as completed
        await _markRequestCompleted(request['id']);
        if (kDebugMode) {
          print('✅ SyncService: Job remoto completato: ${request['article_code']}');
        }
      } else {
        // Mark as failed
        await _markRequestFailed(request['id'], 'Errore generazione file');
        if (kDebugMode) {
          print('❌ SyncService: Job request fallito: ${request['id']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore processamento richiesta: $e');
      }
      await _markRequestFailed(request['id'], e.toString());
    }
  }

  Future<bool> _markRequestProcessing(String requestId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('job_requests')
          .update({'status': 'processing', 'processed_at': DateTime.now().toIso8601String()})
          .eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore marking processing: $e');
      }
      return false;
    }
  }

  Future<bool> _markRequestCompleted(String requestId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('job_requests')
          .update({'status': 'completed'})
          .eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore marking completed: $e');
      }
      return false;
    }
  }

  Future<bool> _markRequestFailed(String requestId, String errorMessage) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('job_requests')
          .update({'status': 'failed', 'error_message': errorMessage})
          .eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Errore marking failed: $e');
      }
      return false;
    }
  }

  Future<bool> _generateJobFile(String articleCode, String lot, int pieces) async {
    bool isAccessingSecureResource = false;

    try {
      // Prepare content
      final String content = '$articleCode\t$lot\t$pieces';

      // Validate TAB format
      final tabCount = '\t'.allMatches(content).length;
      if (tabCount != 2) {
        if (kDebugMode) {
          print('❌ SyncService: Invalid format: TAB count ($tabCount/2)');
        }
        return false;
      }

      final String fileName = 'Job_Schedule.txt';
      String? finalPath;

      // Get saved path or use Documents as fallback
      final savedPath = await _getSaveLocationPath();

      if (savedPath != null && savedPath.isNotEmpty) {
        finalPath = '$savedPath/$fileName';

        // Handle macOS secure bookmarks if available
        if (_isMacOS() && await _hasSecureBookmark()) {
          try {
            isAccessingSecureResource = await _startSecureBookmarkAccess();
            if (!isAccessingSecureResource) {
              if (kDebugMode) {
                print('❌ SyncService: Failed to start accessing secure resource');
              }
              return false;
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ SyncService: Error with secure bookmark: $e');
            }
            return false;
          }
        }
      } else {
        // Use Documents directory as fallback
        try {
          final directory = await getApplicationDocumentsDirectory();
          finalPath = '${directory.path}/$fileName';
        } catch (e) {
          if (kDebugMode) {
            print('❌ SyncService: Error getting documents directory: $e');
          }
          return false;
        }
      }


      // Write file with flush to ensure it's written immediately
      final file = File(finalPath);
      await file.writeAsString(content, flush: true);

      // Save to history
      final String historyEntry = '$articleCode - $lot - $pieces';
      await _saveToHistory(historyEntry);

      // Save to database if possible
      await _saveToDatabase(articleCode, lot, pieces);

      if (kDebugMode) {
        print('✅ SyncService: Job file generated successfully: $finalPath');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncService: Error generating job file: $e');
      }
      return false;
    } finally {
      // Stop accessing secure resource on macOS if it was started
      if (_isMacOS() && isAccessingSecureResource) {
        await _stopSecureBookmarkAccess();
      }
    }
  }

  Future<String?> _getSaveLocationPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('saved_path');
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToDatabase(String articleCode, String lot, int pieces) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('job_schedules').insert({
        'article_code': articleCode,
        'lot': lot,
        'pieces': pieces,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Non critical error, file is still generated
      if (kDebugMode) {
        print('⚠️ SyncService: Errore salvataggio database: $e');
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

  // Helper methods for platform detection
  bool _isMacOS() {
    try {
      return Platform.isMacOS;
    } catch (e) {
      // On web, Platform is not available, assume false
      return false;
    }
  }

  // Secure bookmark helper methods
  Future<bool> _hasSecureBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmark = prefs.getString('secure_bookmark');
      return bookmark != null && bookmark.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _startSecureBookmarkAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkData = prefs.getString('secure_bookmark');
      if (bookmarkData == null) return false;

      final secureBookmarks = SecureBookmarks();
      final resolvedUrl = await secureBookmarks.resolveBookmark(bookmarkData);
      return await secureBookmarks.startAccessingSecurityScopedResource(resolvedUrl);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ SyncService: Error starting secure bookmark access: $e');
      }
      return false;
    }
  }

  Future<void> _stopSecureBookmarkAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkData = prefs.getString('secure_bookmark');
      if (bookmarkData == null) return;

      final secureBookmarks = SecureBookmarks();
      final resolvedUrl = await secureBookmarks.resolveBookmark(bookmarkData);
      await secureBookmarks.stopAccessingSecurityScopedResource(resolvedUrl);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ SyncService: Error stopping secure bookmark access: $e');
      }
    }
  }

  // Save to history method
  Future<void> _saveToHistory(String entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('job_history') ?? [];
      history.insert(0, entry);
      if (history.length > 50) {
        history = history.take(50).toList();
      }
      await prefs.setStringList('job_history', history);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ SyncService: Error saving to history: $e');
      }
    }
  }

}