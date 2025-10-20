import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service per la gestione dei dati in modalità standalone (solo locale)
/// Salva tutti i dati in SharedPreferences senza connessione a Supabase
class LocalDatabaseService {
  static const String _jobHistoryKey = 'local_job_history';
  static const String _qualityHistoryKey = 'local_quality_history';
  static const String _rejectDetailsKey = 'local_reject_details';

  // Singleton pattern
  static LocalDatabaseService? _instance;
  LocalDatabaseService._internal();

  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._internal();
    return _instance!;
  }

  // ==================== JOB SCHEDULES ====================

  /// Salva un job schedule in locale
  Future<bool> saveJobSchedule(String articleCode, String lot, int pieces) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getJobHistory();

      final newEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'article_code': articleCode,
        'lot': lot,
        'pieces': pieces,
        'created_at': DateTime.now().toIso8601String(),
      };

      history.insert(0, newEntry);

      // Mantieni solo gli ultimi 100 record
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }

      final jsonString = jsonEncode(history);
      await prefs.setString(_jobHistoryKey, jsonString);

      if (kDebugMode) {
        print('✅ LocalDB: Job schedule salvato: $articleCode');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore salvataggio job schedule: $e');
      }
      return false;
    }
  }

  /// Recupera lo storico dei job schedules
  Future<List<Map<String, dynamic>>> getJobHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_jobHistoryKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return List<Map<String, dynamic>>.from(
        decoded.map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore recupero job history: $e');
      }
      return [];
    }
  }

  /// Elimina un job schedule
  Future<bool> deleteJobSchedule(String id) async {
    try {
      final history = await getJobHistory();
      history.removeWhere((item) => item['id'] == id);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(history);
      await prefs.setString(_jobHistoryKey, jsonString);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore eliminazione job schedule: $e');
      }
      return false;
    }
  }

  // ==================== QUALITY MONITORING ====================

  /// Salva un record di quality monitoring
  Future<bool> saveQualityMonitoring({
    required String articleCode,
    required String lot,
    required int pieces,
    required int parts,
    required int goodPieces,
    required int scrapPieces,
    required String machine,
    required int elapsedSeconds,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getQualityHistory();

      final newEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'article_code': articleCode,
        'lot': lot,
        'pieces': pieces,
        'parts': parts,
        'good_pieces': goodPieces,
        'scrap_pieces': scrapPieces,
        'machine': machine,
        'elapsed_seconds': elapsedSeconds,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
        'reject_details': [], // Array vuoto, verrà popolato separatamente
      };

      history.insert(0, newEntry);

      // Mantieni solo gli ultimi 100 record
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }

      final jsonString = jsonEncode(history);
      await prefs.setString(_qualityHistoryKey, jsonString);

      if (kDebugMode) {
        print('✅ LocalDB: Quality monitoring salvato: $articleCode');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore salvataggio quality monitoring: $e');
      }
      return false;
    }
  }

  /// Recupera lo storico di quality monitoring
  Future<List<Map<String, dynamic>>> getQualityHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_qualityHistoryKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      final history = List<Map<String, dynamic>>.from(
        decoded.map((item) => Map<String, dynamic>.from(item))
      );

      // Popola i reject_details per ogni entry
      for (var entry in history) {
        final qualityId = entry['id'];
        entry['reject_details'] = await getRejectDetailsForQuality(qualityId);
      }

      return history;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore recupero quality history: $e');
      }
      return [];
    }
  }

  /// Elimina un record di quality monitoring
  Future<bool> deleteQualityMonitoring(String id) async {
    try {
      final history = await getQualityHistory();
      history.removeWhere((item) => item['id'] == id);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(history);
      await prefs.setString(_qualityHistoryKey, jsonString);

      // Elimina anche i reject_details associati
      await _deleteRejectDetailsForQuality(id);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore eliminazione quality monitoring: $e');
      }
      return false;
    }
  }

  // ==================== REJECT DETAILS ====================

  /// Salva i dettagli degli scarti
  Future<bool> saveRejectDetails({
    required String qualityMonitoringId,
    required String rejectType,
    required int quantity,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allRejects = await _getAllRejectDetails();

      final newEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'quality_monitoring_id': qualityMonitoringId,
        'reject_type': rejectType,
        'quantity': quantity,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
      };

      allRejects.add(newEntry);

      // Mantieni solo gli ultimi 500 record
      if (allRejects.length > 500) {
        allRejects.removeRange(0, allRejects.length - 500);
      }

      final jsonString = jsonEncode(allRejects);
      await prefs.setString(_rejectDetailsKey, jsonString);

      if (kDebugMode) {
        print('✅ LocalDB: Reject details salvato: $rejectType');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore salvataggio reject details: $e');
      }
      return false;
    }
  }

  /// Recupera i reject details per uno specifico quality monitoring
  Future<List<Map<String, dynamic>>> getRejectDetailsForQuality(String qualityMonitoringId) async {
    try {
      final allRejects = await _getAllRejectDetails();
      return allRejects
          .where((reject) => reject['quality_monitoring_id'] == qualityMonitoringId)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore recupero reject details: $e');
      }
      return [];
    }
  }

  /// Recupera tutti i reject details (privato)
  Future<List<Map<String, dynamic>>> _getAllRejectDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_rejectDetailsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return List<Map<String, dynamic>>.from(
        decoded.map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore recupero reject details: $e');
      }
      return [];
    }
  }

  /// Elimina i reject details per uno specifico quality monitoring (privato)
  Future<bool> _deleteRejectDetailsForQuality(String qualityMonitoringId) async {
    try {
      final allRejects = await _getAllRejectDetails();
      allRejects.removeWhere((reject) => reject['quality_monitoring_id'] == qualityMonitoringId);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(allRejects);
      await prefs.setString(_rejectDetailsKey, jsonString);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore eliminazione reject details: $e');
      }
      return false;
    }
  }

  // ==================== UTILITY ====================

  /// Cancella tutti i dati locali
  Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jobHistoryKey);
      await prefs.remove(_qualityHistoryKey);
      await prefs.remove(_rejectDetailsKey);

      if (kDebugMode) {
        print('✅ LocalDB: Tutti i dati locali cancellati');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore cancellazione dati: $e');
      }
      return false;
    }
  }

  /// Ottieni statistiche sui dati locali
  Future<Map<String, int>> getStatistics() async {
    try {
      final jobHistory = await getJobHistory();
      final qualityHistory = await getQualityHistory();
      final rejectDetails = await _getAllRejectDetails();

      return {
        'job_schedules': jobHistory.length,
        'quality_records': qualityHistory.length,
        'reject_details': rejectDetails.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore recupero statistiche: $e');
      }
      return {
        'job_schedules': 0,
        'quality_records': 0,
        'reject_details': 0,
      };
    }
  }

  /// Esporta tutti i dati in formato JSON (per backup)
  Future<String?> exportAllData() async {
    try {
      final jobHistory = await getJobHistory();
      final qualityHistory = await getQualityHistory();
      final rejectDetails = await _getAllRejectDetails();

      final export = {
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0',
        'job_schedules': jobHistory,
        'quality_monitoring': qualityHistory,
        'reject_details': rejectDetails,
      };

      return jsonEncode(export);
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore esportazione dati: $e');
      }
      return null;
    }
  }

  /// Importa dati da un backup JSON
  Future<bool> importAllData(String jsonData) async {
    try {
      final Map<String, dynamic> imported = jsonDecode(jsonData);

      final prefs = await SharedPreferences.getInstance();

      // Importa job schedules
      if (imported.containsKey('job_schedules')) {
        await prefs.setString(_jobHistoryKey, jsonEncode(imported['job_schedules']));
      }

      // Importa quality monitoring
      if (imported.containsKey('quality_monitoring')) {
        await prefs.setString(_qualityHistoryKey, jsonEncode(imported['quality_monitoring']));
      }

      // Importa reject details
      if (imported.containsKey('reject_details')) {
        await prefs.setString(_rejectDetailsKey, jsonEncode(imported['reject_details']));
      }

      if (kDebugMode) {
        print('✅ LocalDB: Dati importati con successo');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocalDB: Errore importazione dati: $e');
      }
      return false;
    }
  }
}
