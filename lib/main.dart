import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path_lib;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// App Mode Enum for Server/Remote functionality
enum AppMode {
  server('Server', 'Macchina principale - Elabora file e richieste'),
  remote('Remote', 'Controllo remoto - Visualizza dati e invia richieste');

  const AppMode(this.label, this.description);
  final String label;
  final String description;
}

// Job Request class for remote communication
class JobRequest {
  final String id;
  final String articleCode;
  final String lot;
  final int pieces;
  final String status;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? errorMessage;

  JobRequest({
    required this.id,
    required this.articleCode,
    required this.lot,
    required this.pieces,
    required this.status,
    this.requestedBy,
    required this.requestedAt,
    this.processedAt,
    this.errorMessage,
  });

  factory JobRequest.fromJson(Map<String, dynamic> json) {
    return JobRequest(
      id: json['id'],
      articleCode: json['article_code'],
      lot: json['lot'],
      pieces: json['pieces'],
      status: json['status'],
      requestedBy: json['requested_by'],
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'article_code': articleCode,
      'lot': lot,
      'pieces': pieces,
      'requested_by': requestedBy,
    };
  }
}

class MasterArticle {
  final String id;
  final String code;
  final String description;
  final DateTime createdAt;

  MasterArticle({
    required this.id,
    required this.code,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MasterArticle.fromJson(Map<String, dynamic> json) {
    return MasterArticle(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class RejectDetail {
  final String station;
  final String code;
  final String description;
  final DateTime timestamp;
  final String progressivo;

  RejectDetail({
    required this.station,
    required this.code,
    required this.description,
    required this.timestamp,
    required this.progressivo,
  });
}

class QualityData {
  final int totalPieces;
  final int goodPieces;
  final int rejectedPieces;
  final List<Reject> rejects;
  final List<RejectDetail> latestRejects;
  final DateTime lastUpdate;

  QualityData({
    required this.totalPieces,
    required this.goodPieces,
    required this.rejectedPieces,
    required this.rejects,
    required this.latestRejects,
    required this.lastUpdate,
  });

  double get rejectionRate => totalPieces > 0 ? (rejectedPieces / totalPieces) * 100 : 0;
  double get acceptanceRate => totalPieces > 0 ? (goodPieces / totalPieces) * 100 : 0;
}

class Reject {
  final String reason;
  final int count;
  final DateTime timestamp;

  Reject({
    required this.reason,
    required this.count,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'count': count,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Reject.fromJson(Map<String, dynamic> json) {
    return Reject(
      reason: json['reason'],
      count: json['count'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

enum PopupAction { saveAsMaster, manage, selectArticle }

class PopupChoice {
  final PopupAction action;
  final MasterArticle? article;

  PopupChoice(this.action, [this.article]);
}

// Database service classes
class DatabaseService {
  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase non inizializzato: $e');
      return null;
    }
  }

  // Test database connection and ensure tables exist
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔄 DatabaseService: Test connessione database...');

      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ DatabaseService: Supabase non inizializzato');
        return false;
      }

      // Test basic connection
      await supabase.auth.getUser();
      debugPrint('✅ DatabaseService: Connessione base OK');

      // Test quality_monitoring table
      try {
        await supabase.from('quality_monitoring').select('id').limit(1);
        debugPrint('✅ DatabaseService: Tabella quality_monitoring accessibile');
      } catch (e) {
        debugPrint('❌ DatabaseService: Errore accesso tabella quality_monitoring: $e');
        return false;
      }

      // Test reject_details table
      try {
        await supabase.from('reject_details').select('id').limit(1);
        debugPrint('✅ DatabaseService: Tabella reject_details accessibile');
      } catch (e) {
        debugPrint('❌ DatabaseService: Errore accesso tabella reject_details: $e');
        return false;
      }

      debugPrint('✅ DatabaseService: Test connessione completato con successo');
      return true;
    } catch (e) {
      debugPrint('❌ DatabaseService: Errore test connessione: $e');
      return false;
    }
  }

  // Save job schedule to database
  static Future<bool> saveJob({
    required String articleCode,
    required String lot,
    required int pieces,
    required String filePath,
  }) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ DatabaseService: Supabase non inizializzato per saveJob');
        return false;
      }

      await supabase.from('job_schedules').insert({
        'article_code': articleCode,
        'lot': lot,
        'pieces': pieces,
        'file_path': filePath,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error saving job: $e');
      return false;
    }
  }

  // Save quality monitoring data to database
  static Future<bool> saveQualityData({
    required QualityData data,
    required String monitoringPath,
  }) async {
    try {
      debugPrint('🔄 DatabaseService: Inizio salvataggio dati qualità...');

      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ DatabaseService: Supabase non inizializzato per saveQualityData');
        return false;
      }

      // Check Supabase connection first
      try {
        await supabase.auth.getUser();
        debugPrint('✅ DatabaseService: Connessione Supabase OK');
      } catch (authError) {
        debugPrint('⚠️ DatabaseService: Auth check failed (expected for anonymous access): $authError');
        // Continue anyway since we're using anonymous access
      }

      // Save main quality record
      debugPrint('🔄 DatabaseService: Inserimento record principale...');
      final qualityResponse = await supabase.from('quality_monitoring').insert({
        'monitoring_path': monitoringPath,
        'total_pieces': data.totalPieces,
        'good_pieces': data.goodPieces,
        'rejected_pieces': data.rejectedPieces,
        'timestamp': DateTime.now().toIso8601String(),
      }).select().single();

      final qualityId = qualityResponse['id'];
      debugPrint('✅ DatabaseService: Record principale salvato con ID: $qualityId');

      // Save reject details
      if (data.latestRejects.isNotEmpty) {
        debugPrint('🔄 DatabaseService: Salvataggio ${data.latestRejects.length} dettagli scarti...');
        final rejectData = data.latestRejects.map((reject) => {
          'quality_monitoring_id': qualityId,
          'station': reject.station,
          'code': reject.code,
          'description': reject.description,
          'progressivo': reject.progressivo,
          'timestamp': reject.timestamp.toIso8601String(),
        }).toList();

        await supabase.from('reject_details').insert(rejectData);
        debugPrint('✅ DatabaseService: Dettagli scarti salvati');
      } else {
        debugPrint('ℹ️ DatabaseService: Nessun dettaglio scarto da salvare');
      }

      debugPrint('✅ DatabaseService: Salvataggio completato con successo');
      return true;
    } catch (e) {
      debugPrint('❌ DatabaseService: Errore durante il salvataggio: $e');
      if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        debugPrint('💡 DatabaseService: Suggerimento - Verifica che le tabelle quality_monitoring e reject_details esistano nel database');
      }
      return false;
    }
  }

  // Get job history
  static Future<List<Map<String, dynamic>>> getJobHistory() async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per getJobHistory');
        return [];
      }

      final response = await supabase
          .from('job_schedules')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting job history: $e');
      return [];
    }
  }

  // Get quality monitoring history
  static Future<List<Map<String, dynamic>>> getQualityHistory() async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per getQualityHistory');
        return [];
      }

      final response = await supabase
          .from('quality_monitoring')
          .select('*, reject_details(*)')
          .order('timestamp', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting quality history: $e');
      return [];
    }
  }
}

// App Mode Service for managing Server/Remote functionality
class SupabaseConfigService {
  // Get stored Supabase URL from SharedPreferences
  static Future<String> getSupabaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_url') ?? dotenv.env['SUPABASE_URL'] ?? 'http://192.168.1.225:8000';
  }

  // Get stored Supabase Anon Key from SharedPreferences
  static Future<String> getSupabaseAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_anon_key') ?? dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  // Save Supabase URL to SharedPreferences
  static Future<bool> setSupabaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', url);
      debugPrint('✅ URL Supabase salvato: $url');
      return true;
    } catch (e) {
      debugPrint('❌ Errore salvataggio URL Supabase: $e');
      return false;
    }
  }

  // Save Supabase Anon Key to SharedPreferences
  static Future<bool> setSupabaseAnonKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_anon_key', key);
      debugPrint('✅ Chiave Supabase salvata');
      return true;
    } catch (e) {
      debugPrint('❌ Errore salvataggio chiave Supabase: $e');
      return false;
    }
  }

  // Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

class AppModeService {
  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase non inizializzato: $e');
      return null;
    }
  }

  // Get current app mode from SharedPreferences
  static Future<AppMode> getCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('app_mode') ?? 'server';
    return AppMode.values.firstWhere(
      (mode) => mode.name == modeString,
      orElse: () => AppMode.server,
    );
  }

  // Set app mode in SharedPreferences
  static Future<bool> setMode(AppMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_mode', mode.name);
      debugPrint('✅ AppModeService: Modalità cambiata in ${mode.label}');
      return true;
    } catch (e) {
      debugPrint('❌ AppModeService: Errore salvataggio modalità: $e');
      return false;
    }
  }

  // Submit job request (for remote apps)
  static Future<bool> submitJobRequest({
    required String articleCode,
    required String lot,
    required int pieces,
    String? requestedBy,
  }) async {
    try {
      debugPrint('🔄 AppModeService: Invio richiesta job...');

      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per submitJobRequest');
        return false;
      }

      await supabase.from('job_requests').insert({
        'article_code': articleCode,
        'lot': lot,
        'pieces': pieces,
        'requested_by': requestedBy ?? 'Remote App',
        'status': 'pending',
      });

      debugPrint('✅ AppModeService: Richiesta job inviata con successo');
      return true;
    } catch (e) {
      debugPrint('❌ AppModeService: Errore invio richiesta: $e');
      return false;
    }
  }

  // Get pending job requests (for server app)
  static Future<List<JobRequest>> getPendingRequests() async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per getPendingRequests');
        return [];
      }

      final response = await supabase
          .from('job_requests')
          .select()
          .eq('status', 'pending')
          .order('requested_at', ascending: true);

      return List<JobRequest>.from(
        response.map((item) => JobRequest.fromJson(item))
      );
    } catch (e) {
      debugPrint('❌ AppModeService: Errore recupero richieste: $e');
      return [];
    }
  }

  // Mark job request as processing
  static Future<bool> markRequestProcessing(String requestId) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per markRequestProcessing');
        return false;
      }

      await supabase
          .from('job_requests')
          .update({
            'status': 'processing',
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      debugPrint('✅ AppModeService: Richiesta $requestId in elaborazione');
      return true;
    } catch (e) {
      debugPrint('❌ AppModeService: Errore aggiornamento richiesta: $e');
      return false;
    }
  }

  // Mark job request as completed
  static Future<bool> markRequestCompleted(String requestId) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per markRequestCompleted');
        return false;
      }

      await supabase
          .from('job_requests')
          .update({
            'status': 'completed',
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      debugPrint('✅ AppModeService: Richiesta $requestId completata');
      return true;
    } catch (e) {
      debugPrint('❌ AppModeService: Errore completamento richiesta: $e');
      return false;
    }
  }

  // Mark job request as failed
  static Future<bool> markRequestFailed(String requestId, String errorMessage) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('❌ AppModeService: Supabase non inizializzato per markRequestFailed');
        return false;
      }

      await supabase
          .from('job_requests')
          .update({
            'status': 'failed',
            'processed_at': DateTime.now().toIso8601String(),
            'error_message': errorMessage,
          })
          .eq('id', requestId);

      debugPrint('❌ AppModeService: Richiesta $requestId fallita: $errorMessage');
      return true;
    } catch (e) {
      debugPrint('❌ AppModeService: Errore aggiornamento fallimento: $e');
      return false;
    }
  }

  // Listen for real-time changes in job_requests (for server app)
  static Stream<List<JobRequest>> listenToPendingRequests() {
    final supabase = _supabase;
    if (supabase == null) {
      debugPrint('❌ AppModeService: Supabase non inizializzato per listenToPendingRequests');
      return Stream.value([]);
    }

    return supabase
        .from('job_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('requested_at', ascending: true)
        .map((data) => List<JobRequest>.from(
          data.map((item) => JobRequest.fromJson(item))
        ));
  }

  // Listen for real-time changes in quality_monitoring (for remote apps)
  static Stream<List<Map<String, dynamic>>> listenToQualityData() {
    final supabase = _supabase;
    if (supabase == null) {
      debugPrint('❌ AppModeService: Supabase non inizializzato per listenToQualityData');
      return Stream.value([]);
    }

    return supabase
        .from('quality_monitoring')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(50);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Avvio applicazione...');

  // Load environment variables with error handling
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ File .env caricato');
  } catch (e) {
    debugPrint('⚠️ Errore caricamento .env: $e');
    debugPrint('📱 App continua senza configurazione database');
  }

  // Initialize Supabase with timeout and error handling
  try {
    // Usa le impostazioni salvate dall'utente o fallback al .env
    final supabaseUrl = await SupabaseConfigService.getSupabaseUrl();
    final supabaseKey = await SupabaseConfigService.getSupabaseAnonKey();

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      ).timeout(const Duration(seconds: 5));
      debugPrint('✅ Supabase inizializzato: $supabaseUrl');
    } else {
      debugPrint('⚠️ Configurazione Supabase mancante');
    }
  } catch (e) {
    debugPrint('⚠️ Errore inizializzazione Supabase: $e');
    debugPrint('📱 App continua in modalità offline');
  }

  debugPrint('🎯 Avvio interfaccia utente...');
  runApp(const JobScheduleApp());
}

class JobScheduleApp extends StatelessWidget {
  const JobScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Schedule Generator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          tertiary: const Color(0xFF06B6D4),
          surface: const Color(0xFFF8FAFC),
          surfaceContainerHighest: const Color(0xFFFAFAFA),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E293B),
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: Colors.grey.shade300),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      home: const MainTabView(),
    );
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> with TickerProviderStateMixin {
  late TabController _tabController;
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase non inizializzato: $e');
      return null;
    }
  }
  AppMode _currentMode = AppMode.server;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    final mode = await AppModeService.getCurrentMode();
    if (mounted) {
      setState(() {
        _currentMode = mode;
      });
    }
  }

  Future<void> _testDatabaseConnection() async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Supabase non inizializzato'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Test connection by attempting to access the auth endpoint
      await supabase.auth.getUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Connessione al database riuscita!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Check if it's an AuthSessionMissing error (which means server is reachable)
      if (e.toString().contains('AuthSessionMissing') ||
          e.toString().contains('No session available')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Server Supabase raggiungibile! (Nessun login richiesto)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Real connection error
        if (mounted) {
          String errorMsg = e.toString();
          if (errorMsg.contains('SocketException')) {
            errorMsg = 'Errore di connessione SSL/Network';
          } else if (errorMsg.contains('Connection refused')) {
            errorMsg = 'Server non raggiungibile';
          } else {
            errorMsg = 'Errore: ${errorMsg.split(':').first}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDatabaseConfigDialog() async {
    if (!mounted) return;

    final urlController = TextEditingController();
    final keyController = TextEditingController();

    // Carica i valori attuali
    final currentUrl = await SupabaseConfigService.getSupabaseUrl();
    final currentKey = await SupabaseConfigService.getSupabaseAnonKey();

    if (!mounted) return;

    urlController.text = currentUrl;
    keyController.text = currentKey;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.wrench(), color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Configurazione Database'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configura l\'URL e la chiave del database Supabase:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL Supabase',
                  hintText: 'http://192.168.1.225:8000',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Chiave Anonima',
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Nota:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Riavvia l\'app dopo aver modificato la configurazione per applicare le modifiche.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              final url = urlController.text.trim();
              final key = keyController.text.trim();

              if (url.isEmpty || key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ URL e chiave sono obbligatori'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (!SupabaseConfigService.isValidUrl(url)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ URL non valido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Salva le configurazioni
              final urlSaved = await SupabaseConfigService.setSupabaseUrl(url);
              final keySaved = await SupabaseConfigService.setSupabaseAnonKey(key);

              if (!context.mounted) return;

              if (urlSaved && keySaved) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Errore nel salvataggio della configurazione'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configurazione database salvata. Riavvia l\'app per applicare le modifiche.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showAppModeSettings() async {
    final selectedMode = await showDialog<AppMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.gear(), color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Modalità Applicazione'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleziona la modalità di funzionamento dell\'applicazione:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...AppMode.values.map((mode) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: _currentMode == mode ? 3 : 1,
                color: _currentMode == mode
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : null,
                child: ListTile(
                  title: Text(
                    mode.label,
                    style: TextStyle(
                      fontWeight: _currentMode == mode ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    mode.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  leading: Icon(
                    _currentMode == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () {
                    Navigator.of(context).pop(mode);
                  },
                ),
              ),
            )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.info(), size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Riavvia l\'app dopo aver cambiato modalità per applicare tutte le modifiche.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != _currentMode) {
      final success = await AppModeService.setMode(selectedMode);
      if (success && mounted) {
        setState(() {
          _currentMode = selectedMode;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Modalità cambiata in ${selectedMode.label}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Riavvia',
              onPressed: () {
                // Note: In a real app, you might want to restart the app here
                // For now, we just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('💡 Riavvia l\'app manualmente per applicare tutte le modifiche'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Errore nel salvare la modalità'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIcons.fileText(),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Job Schedule'),
          ],
        ),
        actions: [
          // Combina i due badge in un popup menu per salvare spazio
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                _showAppModeSettings();
              } else if (value == 'configure_db') {
                _showDatabaseConfigDialog();
              } else if (value == 'test_db') {
                _testDatabaseConnection();
              }
            },
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge combinato più compatto
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentMode == AppMode.server
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentMode == AppMode.server
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.cloudCheck(),
                        size: 12,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _currentMode == AppMode.server
                            ? PhosphorIcons.desktop()
                            : PhosphorIcons.deviceMobile(),
                        size: 12,
                        color: _currentMode == AppMode.server
                            ? Colors.blue.shade600
                            : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _currentMode.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _currentMode == AppMode.server
                              ? Colors.blue.shade600
                              : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(PhosphorIcons.caretDown(), size: 12),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.gear(), size: 16),
                    const SizedBox(width: 8),
                    const Text('Impostazioni'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'configure_db',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.wrench(), size: 16),
                    const SizedBox(width: 8),
                    const Text('Configura Database'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'test_db',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.database(), size: 16),
                    const SizedBox(width: 8),
                    const Text('Test Database'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(_currentMode == AppMode.server
                  ? PhosphorIcons.fileText()
                  : PhosphorIcons.paperPlaneRight()),
              text: _currentMode == AppMode.server ? 'Genera File' : 'Richiedi Job',
            ),
            Tab(
              icon: Icon(PhosphorIcons.chartLine()),
              text: 'Monitoraggio',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _currentMode == AppMode.server
              ? ((){
                  debugPrint('🏠 MainTabView - Creating JobScheduleHomePage for server mode');
                  return const JobScheduleHomePage();
                }())
              : ((){
                  debugPrint('📱 MainTabView - Creating RemoteJobRequestPage for remote mode');
                  return const RemoteJobRequestPage();
                }()),
          _currentMode == AppMode.server
              ? ((){
                  debugPrint('📊 MainTabView - Creating QualityMonitoringPage for server mode');
                  return const QualityMonitoringPage();
                }())
              : ((){
                  debugPrint('📈 MainTabView - Creating RemoteQualityDashboard for remote mode');
                  return const RemoteQualityDashboard();
                }()),
        ],
      ),
    );
  }
}

class JobScheduleHomePage extends StatefulWidget {
  const JobScheduleHomePage({super.key});

  @override
  State<JobScheduleHomePage> createState() => _JobScheduleHomePageState();
}

class _JobScheduleHomePageState extends State<JobScheduleHomePage> {
  final TextEditingController _codiceArticoloController = TextEditingController();
  final TextEditingController _lottoController = TextEditingController();
  final TextEditingController _numeroPezziController = TextEditingController();
  
  String _selectedPath = '';
  List<String> _history = [];
  List<MasterArticle> _masterArticles = [];
  bool _isLoading = false;
  String? _secureBookmarkData;

  // Remote job request listener variables
  StreamSubscription<List<JobRequest>>? _jobRequestSubscription;
  AppMode _currentMode = AppMode.server;

  // Automatic job file monitoring
  Timer? _jobFileMonitorTimer;
  final Set<String> _processedJobFiles = {}; // Track processed files to avoid duplicates

  // Simple job request polling every 30 seconds
  Timer? _jobRequestPollingTimer;
  final Set<String> _processedJobRequestIds = {}; // Track processed requests to avoid duplicates

  // Helper methods for platform detection that work on web
  bool _isMacOS() {
    try {
      return Platform.isMacOS;
    } catch (e) {
      // On web, Platform is not available, assume false
      return false;
    }
  }

  bool _isDesktopPlatform() {
    try {
      return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    } catch (e) {
      // On web, assume it's a desktop-like environment
      return true;
    }
  }

  String? _getHomeDirectory() {
    try {
      return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    } catch (e) {
      // On web, return null
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCurrentMode();
    _startJobFileMonitoring();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('job_history') ?? [];
      _selectedPath = prefs.getString('saved_path') ?? '';
      _secureBookmarkData = prefs.getString('secure_bookmark');
    });

    // Se abbiamo un bookmark salvato, proviamo a risolverlo
    await _restoreSecureBookmark();
    await _loadMasterArticles();
  }

  Future<void> _loadMasterArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesJson = prefs.getStringList('master_articles') ?? [];

      final loadedArticles = <MasterArticle>[];
      for (final jsonStr in articlesJson) {
        try {
          final article = MasterArticle.fromJson(jsonDecode(jsonStr));
          loadedArticles.add(article);
        } catch (e) {
          // Salta gli articoli corrotti nel JSON, ma continua con gli altri
          // Log ignorato per non usare print in produzione
        }
      }

      setState(() {
        _masterArticles = loadedArticles;
        _masterArticles.sort((a, b) => a.code.compareTo(b.code));
      });
    } catch (e) {
      // In caso di errore critico nel caricamento, inizializza lista vuota
      setState(() {
        _masterArticles = [];
      });
      _showSnackBar('⚠️ Errore caricamento articoli master', const Color(0xFFEA580C));
    }
  }

  Future<void> _loadCurrentMode() async {
    final mode = await AppModeService.getCurrentMode();
    if (mounted) {
      setState(() {
        _currentMode = mode;
      });

      // Start listening for job requests and file monitoring only in server mode
      if (_currentMode == AppMode.server) {
        _startJobRequestListener();
        _startJobFileMonitoring();
      } else {
        // Stop file monitoring and job request polling in remote mode
        _jobFileMonitorTimer?.cancel();
        _jobRequestPollingTimer?.cancel();
      }
    }
  }

  void _startJobRequestListener() {
    _jobRequestSubscription?.cancel();
    _jobRequestPollingTimer?.cancel();

    if (_currentMode == AppMode.server) {
      // Simple polling every 30 seconds to check for job requests
      _startJobRequestPolling();
      debugPrint('🔄 Avviato controllo job requests ogni 30 secondi');
    }
  }

  void _startJobRequestPolling() {
    _jobRequestPollingTimer?.cancel();
    _jobRequestPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted || _currentMode != AppMode.server) {
        timer.cancel();
        return;
      }

      try {
        debugPrint('🔄 Controllo job requests nel database...');
        final requests = await AppModeService.getPendingRequests();

        if (mounted && requests.isNotEmpty) {
          debugPrint('📨 Trovate ${requests.length} richieste job pending');

          setState(() {
            // Requests loaded but not stored locally
          });

          // Process only new requests we haven't processed before
          for (final request in requests) {
            if (request.status == 'pending' && !_processedJobRequestIds.contains(request.id)) {
              debugPrint('🔄 Elaborazione nuova richiesta job: ${request.id}');
              _processedJobRequestIds.add(request.id);
              await _processJobRequest(request);
            }
          }
        } else {
          debugPrint('ℹ️ Nessuna richiesta job pending trovata');
        }
      } catch (e) {
        debugPrint('❌ Errore controllo job requests: $e');
      }
    });

    // Do an immediate check when starting
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted && _currentMode == AppMode.server) {
        try {
          debugPrint('🔄 Controllo iniziale job requests...');
          final requests = await AppModeService.getPendingRequests();
          if (mounted && requests.isNotEmpty) {
            debugPrint('📨 Controllo iniziale: trovate ${requests.length} richieste');
            setState(() {
              // Requests loaded but not stored locally
            });
            for (final request in requests) {
              if (request.status == 'pending' && !_processedJobRequestIds.contains(request.id)) {
                _processedJobRequestIds.add(request.id);
                await _processJobRequest(request);
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Errore controllo iniziale: $e');
        }
      }
    });
  }

  Future<void> _processJobRequest(JobRequest request) async {
    try {
      debugPrint('🔄 Processing job request: ${request.id}');

      // Mark as processing
      await AppModeService.markRequestProcessing(request.id);

      // Generate the job file automatically
      final success = await _generateJobFileFromRequest(
        request.articleCode,
        request.lot,
        request.pieces,
      );

      if (success) {
        // Mark as completed
        await AppModeService.markRequestCompleted(request.id);
        debugPrint('✅ Job request completed: ${request.id}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Job remoto completato: ${request.articleCode}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Mark as failed
        await AppModeService.markRequestFailed(request.id, 'Errore generazione file');
        debugPrint('❌ Job request failed: ${request.id}');
      }
    } catch (e) {
      debugPrint('❌ Error processing job request: $e');
      await AppModeService.markRequestFailed(request.id, e.toString());
    }
  }

  Future<bool> _generateJobFileFromRequest(String articleCode, String lot, int pieces) async {
    bool isAccessingSecureResource = false;

    try {
      // Prepare content
      final String content = '$articleCode\t$lot\t$pieces';

      // Validate TAB format
      final tabCount = '\t'.allMatches(content).length;
      if (tabCount != 2) {
        debugPrint('❌ Invalid format: TAB count ($tabCount/2)');
        return false;
      }

      final String fileName = 'Job_Schedule.txt';
      String finalPath;

      // Use saved path if available, otherwise use current directory
      if (_selectedPath.isNotEmpty) {
        finalPath = '$_selectedPath/$fileName';

        // Su macOS, gestisci i secure bookmarks per i permessi di scrittura
        if (_isMacOS() && _secureBookmarkData != null) {
          try {
            final secureBookmarks = SecureBookmarks();
            final resolvedUrl = await secureBookmarks.resolveBookmark(_secureBookmarkData!);

            // Avvia l'accesso sicuro alla risorsa
            isAccessingSecureResource = await secureBookmarks.startAccessingSecurityScopedResource(resolvedUrl);

            if (!isAccessingSecureResource) {
              debugPrint('❌ Failed to start accessing secure resource');
              return false;
            }

            debugPrint('✅ Secure bookmark access started for automatic file generation');
          } catch (e) {
            debugPrint('❌ Error with secure bookmark: $e');
            return false;
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        finalPath = '${directory.path}/$fileName';
      }

      // Write file
      final file = File(finalPath);
      await file.writeAsString(content, flush: true);

      // Save to history
      final String historyEntry = '$articleCode - $lot - $pieces';
      await _saveToHistory(historyEntry);

      // Save to database
      await DatabaseService.saveJob(
        articleCode: articleCode,
        lot: lot,
        pieces: pieces,
        filePath: finalPath,
      );

      debugPrint('✅ Job file generated successfully: $finalPath');
      return true;
    } catch (e) {
      debugPrint('❌ Error generating job file: $e');
      return false;
    } finally {
      // Su macOS, ferma l'accesso alla risorsa sicura se era stata avviata
      if (_isMacOS() && isAccessingSecureResource && _secureBookmarkData != null) {
        try {
          final secureBookmarks = SecureBookmarks();
          final resolvedUrl = await secureBookmarks.resolveBookmark(_secureBookmarkData!);
          await secureBookmarks.stopAccessingSecurityScopedResource(resolvedUrl);
          debugPrint('✅ Stopped secure bookmark access');
        } catch (e) {
          debugPrint('⚠️ Error stopping secure bookmark access: $e');
        }
      }
    }
  }

  Future<void> _saveToHistory(String entry) async {
    final prefs = await SharedPreferences.getInstance();
    _history.insert(0, entry);
    if (_history.length > 50) {
      _history = _history.take(50).toList();
    }
    await prefs.setStringList('job_history', _history);
  }

  Future<void> _savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_path', path);

    // Salva anche il secure bookmark per macOS
    await _saveSecureBookmark(path);
  }

  Future<void> _saveSecureBookmark(String path) async {
    if (!_isMacOS()) return;

    try {
      final secureBookmarks = SecureBookmarks();
      final directory = Directory(path);
      final bookmark = await secureBookmarks.bookmark(directory);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_bookmark', bookmark);
      _secureBookmarkData = bookmark;
    } catch (e) {
      // Se non riusciamo a creare il bookmark, continua comunque
      // Log l'errore ma continua senza fallire
    }
  }

  Future<void> _restoreSecureBookmark() async {
    if (!_isMacOS() || _secureBookmarkData == null) return;

    try {
      final secureBookmarks = SecureBookmarks();
      final resolvedUrl = await secureBookmarks.resolveBookmark(_secureBookmarkData!);

      // Verifica che il percorso esista ancora
      final directory = Directory(resolvedUrl.path);
      if (await directory.exists()) {
        setState(() {
          _selectedPath = resolvedUrl.path;
        });

        // Aggiorna anche il percorso salvato in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_path', resolvedUrl.path);
      }
    } catch (e) {
      // Se il bookmark non è più valido, rimuovilo
      await _clearSecureBookmark();
    }
  }

  Future<void> _clearSecureBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_bookmark');
    _secureBookmarkData = null;
  }

  Future<void> _clearSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_path');
    await _clearSecureBookmark();
    setState(() {
      _selectedPath = '';
    });
    _showSnackBar('✅ Percorso salvato rimosso', const Color(0xFF059669));
  }

  Future<void> _saveMasterArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final articlesJson = _masterArticles
          .map((article) => jsonEncode(article.toJson()))
          .toList();

      final success = await prefs.setStringList('master_articles', articlesJson);
      if (!success) {
        throw Exception('Impossibile salvare su SharedPreferences');
      }
    } catch (e) {
      // Rilancia l'eccezione per permettere ai metodi chiamanti di gestirla
      throw Exception('Errore salvataggio articoli master: ${e.toString()}');
    }
  }

  Future<void> _addMasterArticle(String code, String description) async {
    try {
      final article = MasterArticle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        code: code.trim(),
        description: description.trim(),
        createdAt: DateTime.now(),
      );

      // Aggiungi prima alla lista locale
      _masterArticles.add(article);
      _masterArticles.sort((a, b) => a.code.compareTo(b.code));

      // Salva su SharedPreferences
      await _saveMasterArticles();

      // Aggiorna l'interfaccia solo dopo il salvataggio riuscito
      setState(() {});
      _showSnackBar('✅ Articolo aggiunto: ${article.code}', const Color(0xFF059669));
    } catch (e) {
      // In caso di errore, rimuovi l'articolo dalla lista locale
      _masterArticles.removeWhere((a) => a.code == code.trim());
      _showSnackBar('❌ Errore salvataggio articolo: ${e.toString()}', const Color(0xFFDC2626));
    }
  }

  Future<void> _updateMasterArticle(String id, String code, String description) async {
    final index = _masterArticles.indexWhere((article) => article.id == id);
    if (index != -1) {
      try {
        final updatedArticle = MasterArticle(
          id: id,
          code: code.trim(),
          description: description.trim(),
          createdAt: _masterArticles[index].createdAt,
        );

        // Aggiorna la lista locale
        _masterArticles[index] = updatedArticle;
        _masterArticles.sort((a, b) => a.code.compareTo(b.code));

        // Salva su SharedPreferences
        await _saveMasterArticles();

        // Aggiorna l'interfaccia solo dopo il salvataggio riuscito
        setState(() {});
        _showSnackBar('✅ Articolo aggiornato: ${updatedArticle.code}', const Color(0xFF059669));
      } catch (e) {
        // In caso di errore, ripristina l'articolo originale
        final originalIndex = _masterArticles.indexWhere((article) => article.id == id);
        if (originalIndex != -1) {
          // Trova l'articolo originale dalla lista (potrebbe essere cambiata l'indicizzazione)
          await _loadMasterArticles(); // Ricarica dalla memoria
        }
        _showSnackBar('❌ Errore aggiornamento articolo: ${e.toString()}', const Color(0xFFDC2626));
      }
    }
  }

  Future<void> _deleteMasterArticle(String id) async {
    try {
      final articleIndex = _masterArticles.indexWhere((article) => article.id == id);
      if (articleIndex == -1) {
        _showSnackBar('❌ Articolo non trovato', const Color(0xFFDC2626));
        return;
      }

      // Salva l'articolo per il rollback in caso di errore
      final deletedArticle = _masterArticles[articleIndex];

      // Rimuovi dalla lista locale
      _masterArticles.removeAt(articleIndex);

      // Salva su SharedPreferences
      await _saveMasterArticles();

      // Aggiorna l'interfaccia solo dopo il salvataggio riuscito
      setState(() {});
      _showSnackBar('🗑️ Articolo eliminato: ${deletedArticle.code}', const Color(0xFFEA580C));
    } catch (e) {
      // In caso di errore, ricarica gli articoli dalla memoria
      await _loadMasterArticles();
      setState(() {});
      _showSnackBar('❌ Errore eliminazione articolo: ${e.toString()}', const Color(0xFFDC2626));
    }
  }

  void _selectMasterArticle(MasterArticle article) {
    setState(() {
      _codiceArticoloController.text = article.code;
    });
    _showSnackBar('📋 Articolo selezionato: ${article.code}', const Color(0xFF059669));
  }

  Future<void> _selectSaveLocation() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona cartella di destinazione',
      );
      
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        setState(() {
          _selectedPath = selectedDirectory;
        });
        await _savePath(selectedDirectory);
        _showSnackBar('✅ Percorso selezionato e salvato', const Color(0xFF059669));
      } else {
        _showSnackBar('ℹ️ Selezione annullata', const Color(0xFF64748B));
      }
    } catch (e) {
      // Fallback: usa la directory Downloads
      try {
        Directory? downloadsDir;
        
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
          if (homeDir != null) {
            downloadsDir = Directory('$homeDir/Downloads');
          }
        } else {
          downloadsDir = await getDownloadsDirectory();
        }
        
        if (downloadsDir != null && await downloadsDir.exists()) {
          setState(() {
            _selectedPath = downloadsDir!.path;
          });
          await _savePath(downloadsDir.path);
          _showSnackBar('✅ Cartella Downloads selezionata e salvata', const Color(0xFF059669));
        } else {
          _showSnackBar('❌ Impossibile selezionare cartella', const Color(0xFFDC2626));
        }
      } catch (fallbackError) {
        _showSnackBar('❌ Errore selezione cartella: ${e.toString()}', const Color(0xFFDC2626));
      }
    }
  }

  Future<void> _generateJobFile() async {
    // Validation
    if (_codiceArticoloController.text.trim().isEmpty ||
        _lottoController.text.trim().isEmpty ||
        _numeroPezziController.text.trim().isEmpty) {
      _showSnackBar('⚠️ Inserisci tutti i campi richiesti', const Color(0xFFEA580C));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare content
      final String codice = _codiceArticoloController.text.trim();
      final String lotto = _lottoController.text.trim();
      final String pezzi = _numeroPezziController.text.trim();
      final String content = '$codice\t$lotto\t$pezzi';

      // Debug: verifica che i TAB siano presenti
      final tabCount = '\t'.allMatches(content).length;
      if (tabCount != 2) {
        _showSnackBar('⚠️ Errore formato: TAB mancanti ($tabCount/2)', const Color(0xFFEA580C));
        return;
      }
      final String fileName = 'Job_Schedule.txt';
      
      String finalPath;
      
      // Determine save location
      
      // Verifica se il percorso salvato esiste e ha permessi di scrittura
      bool pathExists = false;
      bool hasWritePermission = false;

      if (_selectedPath.isNotEmpty) {
        // Su macOS, se abbiamo un secure bookmark, proviamo prima a ripristinarlo
        if (_isMacOS() && _secureBookmarkData != null) {
          try {
            final secureBookmarks = SecureBookmarks();
            final resolvedUrl = await secureBookmarks.resolveBookmark(_secureBookmarkData!);

            // Avvia l'accesso sicuro alla risorsa
            final startedAccessing = await secureBookmarks.startAccessingSecurityScopedResource(resolvedUrl);

            if (startedAccessing) {
              final directory = Directory(resolvedUrl.path);
              pathExists = await directory.exists();

              if (pathExists) {
                // Aggiorna il percorso con quello risolto dal bookmark
                if (_selectedPath != resolvedUrl.path) {
                  setState(() {
                    _selectedPath = resolvedUrl.path;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('saved_path', resolvedUrl.path);
                }

                // Testa i permessi di scrittura
                try {
                  final testFile = File('$_selectedPath/.test_write_permission');
                  await testFile.writeAsString('test');
                  await testFile.delete();
                  hasWritePermission = true;
                } catch (e) {
                  hasWritePermission = false;
                }
              }
            }
          } catch (e) {
            // Se il bookmark non è più valido, cancellalo
            await _clearSecureBookmark();
          }
        }

        // Fallback per sistemi non-macOS o se il bookmark non ha funzionato
        if (!pathExists) {
          final directory = Directory(_selectedPath);
          pathExists = await directory.exists();

          if (pathExists) {
            // Testa i permessi di scrittura
            try {
              final testFile = File('$_selectedPath/.test_write_permission');
              await testFile.writeAsString('test');
              await testFile.delete();
              hasWritePermission = true;
            } catch (e) {
              hasWritePermission = false;
            }
          }
        }

        if (!pathExists || !hasWritePermission) {
          // Percorso salvato non esiste più o non ha permessi, resettalo
          setState(() {
            _selectedPath = '';
          });
          await _savePath('');
          await _clearSecureBookmark();
          if (!pathExists) {
            _showSnackBar('⚠️ Percorso salvato non più valido, seleziona nuovo percorso', const Color(0xFFEA580C));
          } else {
            _showSnackBar('⚠️ Nessun permesso di scrittura su percorso salvato, seleziona nuovamente', const Color(0xFFEA580C));
          }
        }
      }
      
      if (_selectedPath.isEmpty || !pathExists || !hasWritePermission) {
        try {
          String? defaultPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Seleziona dove salvare il file',
          );
          
          if (defaultPath == null || defaultPath.isEmpty) {
            // Fallback: usa Downloads directory
            Directory? downloadsDir;

            if (_isDesktopPlatform()) {
              final homeDir = _getHomeDirectory();
              if (homeDir != null) {
                downloadsDir = Directory('$homeDir/Downloads');
              }
            } else {
              downloadsDir = await getDownloadsDirectory();
            }
            
            if (downloadsDir != null && await downloadsDir.exists()) {
              defaultPath = downloadsDir.path;
              _showSnackBar('ℹ️ Salvato in Downloads (fallback)', const Color(0xFF059669));
            } else {
              setState(() {
                _isLoading = false;
              });
              _showSnackBar('❌ Impossibile determinare cartella di salvataggio', const Color(0xFFDC2626));
              return;
            }
          }
          finalPath = '$defaultPath/$fileName';
        } catch (e) {
          // Fallback diretto a Downloads in caso di errore
          try {
            Directory? downloadsDir;
            if (_isDesktopPlatform()) {
              final homeDir = _getHomeDirectory();
              if (homeDir != null) {
                downloadsDir = Directory('$homeDir/Downloads');
              }
            } else {
              downloadsDir = await getDownloadsDirectory();
            }
            
            if (downloadsDir != null && await downloadsDir.exists()) {
              finalPath = '${downloadsDir.path}/$fileName';
              _showSnackBar('ℹ️ Salvato in Downloads (fallback)', const Color(0xFF059669));
            } else {
              setState(() {
                _isLoading = false;
              });
              _showSnackBar('❌ Impossibile salvare il file', const Color(0xFFDC2626));
              return;
            }
          } catch (fallbackError) {
            setState(() {
              _isLoading = false;
            });
            _showSnackBar('❌ Errore critico: impossibile salvare', const Color(0xFFDC2626));
            return;
          }
        }
      } else {
        finalPath = '$_selectedPath/$fileName';
        _showSnackBar('💾 Usando percorso salvato', const Color(0xFF059669));
      }
      
      // Write file
      final file = File(finalPath);
      await file.writeAsString(content, flush: true);

      // Su macOS, ferma l'accesso alla risorsa sicura se era stata avviata
      if (_isMacOS() && _secureBookmarkData != null) {
        try {
          final secureBookmarks = SecureBookmarks();
          final resolvedUrl = await secureBookmarks.resolveBookmark(_secureBookmarkData!);
          await secureBookmarks.stopAccessingSecurityScopedResource(resolvedUrl);
        } catch (e) {
          // Ignora errori nel fermare l'accesso
        }
      }
      
      // Verify file was written and content is correct
      if (await file.exists()) {
        // Verifica che il contenuto sia stato scritto correttamente
        final savedContent = await file.readAsString();
        final savedTabCount = '\t'.allMatches(savedContent).length;

        if (savedTabCount != 2) {
          _showSnackBar('⚠️ File salvato ma formato TAB scorretto ($savedTabCount/2)', const Color(0xFFEA580C));
        } else {
          // Add to history
          final historyEntry = '${DateTime.now().toString().split('.')[0]} - $content';
          await _saveToHistory(historyEntry);

          // Save to database
          final dbSaved = await DatabaseService.saveJob(
            articleCode: _codiceArticoloController.text.trim(),
            lot: _lottoController.text.trim(),
            pieces: int.tryParse(_numeroPezziController.text.trim()) ?? 0,
            filePath: finalPath,
          );

          setState(() {});

          if (dbSaved) {
            _showSnackBar('✅ File "$fileName" salvato e sincronizzato con database!', const Color(0xFF059669));
          } else {
            _showSnackBar('✅ File "$fileName" salvato (database non disponibile)', const Color(0xFFEA580C));
          }
          _clearFields();
        }
      } else {
        throw Exception('File non trovato dopo la scrittura');
      }
      
    } catch (e) {
      _showSnackBar('❌ Errore salvataggio: ${e.toString()}', const Color(0xFFDC2626));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearFields() {
    _codiceArticoloController.clear();
    _lottoController.clear();
    _numeroPezziController.clear();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int delay,
    TextInputType? keyboardType,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeField() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codiceArticoloController,
                  decoration: InputDecoration(
                    labelText: 'Codice Articolo',
                    hintText: 'es. PXO7471-250905',
                    prefixIcon: Icon(
                      PhosphorIcons.tag(),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: PopupMenuButton<PopupChoice?>(
                  icon: Icon(
                    PhosphorIcons.package(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Articoli Master',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) {
                    if (_masterArticles.isEmpty) {
                      return [
                        // Se c'è del testo nel campo, mostra l'opzione di salvataggio rapido
                        if (_codiceArticoloController.text.trim().isNotEmpty)
                          PopupMenuItem<PopupChoice?>(
                            value: PopupChoice(PopupAction.saveAsMaster),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIcons.floppyDisk(),
                                  size: 16,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Salva come Master'),
                                      Text(
                                        '"${_codiceArticoloController.text.trim()}"',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_codiceArticoloController.text.trim().isNotEmpty)
                          const PopupMenuDivider(),
                        PopupMenuItem<PopupChoice?>(
                          enabled: false,
                          child: Text(
                            'Nessun articolo master',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        PopupMenuItem<PopupChoice?>(
                          value: PopupChoice(PopupAction.manage),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.plus(),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text('Aggiungi primo articolo'),
                            ],
                          ),
                        ),
                      ];
                    }

                    return [
                      // Opzione per salvare il codice corrente come master
                      if (_codiceArticoloController.text.trim().isNotEmpty)
                        PopupMenuItem<PopupChoice?>(
                          value: PopupChoice(PopupAction.saveAsMaster),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.floppyDisk(),
                                size: 16,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Salva come Master'),
                                    Text(
                                      '"${_codiceArticoloController.text.trim()}"',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_codiceArticoloController.text.trim().isNotEmpty)
                        const PopupMenuDivider(),
                      PopupMenuItem<PopupChoice?>(
                        value: PopupChoice(PopupAction.manage),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.gear(),
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Gestisci articoli'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      ..._masterArticles.map((article) => PopupMenuItem<PopupChoice?>(
                        value: PopupChoice(PopupAction.selectArticle, article),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.package(),
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    article.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (article.description.isNotEmpty)
                                    Text(
                                      article.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ];
                  },
                  onSelected: (choice) {
                    if (choice?.action == PopupAction.saveAsMaster) {
                      // Salva il testo corrente come nuovo articolo master
                      final currentCode = _codiceArticoloController.text.trim();
                      if (currentCode.isNotEmpty) {
                        _showQuickSaveMasterDialog(currentCode);
                      }
                    } else if (choice?.action == PopupAction.manage) {
                      // Apri il dialog di gestione
                      _showMasterArticlesDialog();
                    } else if (choice?.action == PopupAction.selectArticle && choice?.article != null) {
                      // Seleziona l'articolo
                      _selectMasterArticle(choice!.article!);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_masterArticles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _masterArticles.take(3).map((article) {
                return GestureDetector(
                  onTap: () => _selectMasterArticle(article),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.package(),
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.code,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      PhosphorIcons.clockCounterClockwise(),
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cronologia File',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${_history.length} file generati',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      PhosphorIcons.x(),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: _history.isEmpty
                    ? Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.fileX(),
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nessun file generato ancora',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _history.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIcons.fileText(),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _history[index],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMasterArticlesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      PhosphorIcons.package(),
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Articoli Master',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${_masterArticles.length} articoli salvati',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddArticleDialog(),
                    icon: Icon(
                      PhosphorIcons.plus(),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Aggiungi articolo',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      PhosphorIcons.x(),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: _masterArticles.isEmpty
                    ? Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.package(),
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nessun articolo master ancora',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _showAddArticleDialog(),
                                icon: Icon(PhosphorIcons.plus()),
                                label: const Text('Aggiungi primo articolo'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _masterArticles.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final article = _masterArticles[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.package(),
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        article.code,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (article.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          article.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _selectMasterArticle(article);
                                    Navigator.pop(context);
                                  },
                                  icon: Icon(
                                    PhosphorIcons.check(),
                                    color: Colors.green.shade600,
                                    size: 18,
                                  ),
                                  tooltip: 'Usa questo articolo',
                                ),
                                IconButton(
                                  onPressed: () => _showEditArticleDialog(article),
                                  icon: Icon(
                                    PhosphorIcons.pencil(),
                                    color: Colors.orange.shade600,
                                    size: 18,
                                  ),
                                  tooltip: 'Modifica',
                                ),
                                IconButton(
                                  onPressed: () => _confirmDeleteArticle(article),
                                  icon: Icon(
                                    PhosphorIcons.trash(),
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  tooltip: 'Elimina',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickSaveMasterDialog(String prefilledCode) {
    final TextEditingController codeController = TextEditingController(text: prefilledCode);
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              PhosphorIcons.floppyDisk(),
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 12),
            const Text('Salva come Master'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Codice Articolo',
                hintText: 'es. PXO7471-250905',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                hintText: 'es. Flangia standard 250mm',
              ),
              autofocus: true, // Focus sulla descrizione per inserimento rapido
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                await _addMasterArticle(
                  codeController.text.trim(),
                  descriptionController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: Icon(PhosphorIcons.floppyDisk(), size: 16),
            label: const Text('Salva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddArticleDialog() {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              PhosphorIcons.plus(),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Nuovo Articolo Master'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Codice Articolo',
                hintText: 'es. PXO7471-250905',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                hintText: 'es. Flangia standard 250mm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                await _addMasterArticle(
                  codeController.text.trim(),
                  descriptionController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _showEditArticleDialog(MasterArticle article) {
    final TextEditingController codeController = TextEditingController(text: article.code);
    final TextEditingController descriptionController = TextEditingController(text: article.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              PhosphorIcons.pencil(),
              color: Colors.orange.shade600,
            ),
            const SizedBox(width: 12),
            const Text('Modifica Articolo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Codice Articolo',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                await _updateMasterArticle(
                  article.id,
                  codeController.text.trim(),
                  descriptionController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteArticle(MasterArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              PhosphorIcons.warning(),
              color: Colors.red.shade600,
            ),
            const SizedBox(width: 12),
            const Text('Conferma Eliminazione'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Sei sicuro di voler eliminare l\'articolo '),
              TextSpan(
                text: article.code,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteMasterArticle(article.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            PhosphorIcons.files(),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Genera File Job Schedule',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Inserisci i dati per generare il file con formato: [CODICE]→[LOTTO]→[PEZZI] (separati da TAB)',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  FadeInRight(
                                    delay: const Duration(milliseconds: 200),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.shade200,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          PhosphorIcons.clockCounterClockwise(),
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        onPressed: _showHistoryDialog,
                                        tooltip: 'Cronologia',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildCodeField(),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _lottoController,
                      label: 'Lotto',
                      hint: 'es. 310',
                      icon: PhosphorIcons.hash(),
                      delay: 300,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _numeroPezziController,
                      label: 'Numero Pezzi',
                      hint: 'es. 15',
                      icon: PhosphorIcons.listNumbers(),
                      delay: 400,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            PhosphorIcons.folderOpen(),
                            color: Theme.of(context).colorScheme.tertiary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Percorso di Salvataggio',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedPath.isEmpty 
                                ? PhosphorIcons.folder() 
                                : PhosphorIcons.folderSimple(),
                            color: _selectedPath.isEmpty 
                                ? Colors.grey.shade400 
                                : Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedPath.isEmpty 
                                  ? 'Seleziona cartella (opzionale)' 
                                  : _selectedPath,
                              style: TextStyle(
                                color: _selectedPath.isEmpty 
                                    ? Colors.grey.shade500 
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: _selectedPath.isEmpty 
                                    ? FontWeight.w400 
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _selectSaveLocation,
                            icon: Icon(PhosphorIcons.folderOpen()),
                            label: const Text('Scegli Cartella'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_selectedPath.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearSavedPath,
                              icon: Icon(
                                PhosphorIcons.x(),
                                size: 18,
                              ),
                              label: const Text('Reset'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: Colors.orange.shade700,
                                side: BorderSide(color: Colors.orange.shade300),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateJobFile,
                  icon: _isLoading 
                      ? SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(PhosphorIcons.downloadSimple()),
                  label: Text(_isLoading ? 'Generazione in corso...' : 'Genera File Job Schedule'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 700),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearFields,
                  icon: Icon(PhosphorIcons.eraser()),
                  label: const Text('Pulisci Campi'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_history.isNotEmpty)
              FadeInUp(
                delay: const Duration(milliseconds: 800),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                        Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIcons.clockCounterClockwise(),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ultimo file generato',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _history.first,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showHistoryDialog,
                        icon: Icon(
                          PhosphorIcons.arrowRight(),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        tooltip: 'Vedi cronologia completa',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }

  // Start automatic job file monitoring every 30 seconds
  void _startJobFileMonitoring() {
    // Cancel existing timer first
    _jobFileMonitorTimer?.cancel();

    if (_currentMode == AppMode.server && mounted) {
      _jobFileMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted) {
          _checkForJobFiles();
        } else {
          timer.cancel();
        }
      });
      debugPrint('🔄 Started automatic job file monitoring (every 30 seconds)');
    }
  }

  // Check for Job_Schedule.txt files in the selected directory
  Future<void> _checkForJobFiles() async {
    if (_selectedPath.isEmpty || !mounted) return;

    try {
      final directory = Directory(_selectedPath);
      if (!await directory.exists()) return;

      final files = await directory.list().toList();
      final jobFiles = files.whereType<File>()
          .where((file) => path_lib.basename(file.path).toLowerCase() == 'job_schedule.txt')
          .toList();

      for (final file in jobFiles) {
        final filePath = file.path;
        final fileKey = '$filePath-${await file.lastModified()}';

        // Skip if already processed
        if (_processedJobFiles.contains(fileKey)) continue;

        debugPrint('📄 Found new job file: $filePath');
        await _processJobFile(file);
        _processedJobFiles.add(fileKey);
      }
    } catch (e) {
      debugPrint('❌ Error checking for job files: $e');
    }
  }

  // Process a found Job_Schedule.txt file
  Future<void> _processJobFile(File jobFile) async {
    if (!mounted) return;

    try {
      final content = await jobFile.readAsString();
      final lines = content.trim().split('\n');

      if (lines.isEmpty) return;

      // Parse the first line (should be: ARTICLE_CODE\tLOT\tPIECES)
      final firstLine = lines.first.trim();
      final parts = firstLine.split('\t');

      if (parts.length >= 3) {
        final articleCode = parts[0].trim();
        final lot = parts[1].trim();
        final piecesStr = parts[2].trim();

        final pieces = int.tryParse(piecesStr);
        if (pieces != null && pieces > 0) {
          debugPrint('🚀 Auto-processing job: $articleCode - $lot - $pieces pieces');

          // Fill the form fields only if widget is still mounted
          if (mounted) {
            setState(() {
              _codiceArticoloController.text = articleCode;
              _lottoController.text = lot;
              _numeroPezziController.text = piecesStr;
            });
          }

          // Process the job automatically
          await _generateJobFile();

          // Move processed file to a 'processed' subdirectory
          await _moveProcessedFile(jobFile);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ File job processato automaticamente: $articleCode'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing job file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore nel processare il file job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Move processed file to avoid reprocessing
  Future<void> _moveProcessedFile(File jobFile) async {
    try {
      final directory = jobFile.parent;
      final processedDir = Directory(path_lib.join(directory.path, 'processed'));

      if (!await processedDir.exists()) {
        await processedDir.create();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = path_lib.join(processedDir.path, 'job_schedule_$timestamp.txt');
      await jobFile.rename(newPath);

      debugPrint('📁 Moved processed file to: $newPath');
    } catch (e) {
      debugPrint('⚠️ Could not move processed file: $e');
      // Don't fail the whole process if we can't move the file
    }
  }

  @override
  void dispose() {
    _jobRequestSubscription?.cancel();
    _jobFileMonitorTimer?.cancel();
    _jobRequestPollingTimer?.cancel();
    _codiceArticoloController.dispose();
    _lottoController.dispose();
    _numeroPezziController.dispose();
    super.dispose();
  }
}

class QualityMonitoringPage extends StatefulWidget {
  const QualityMonitoringPage({super.key});

  @override
  State<QualityMonitoringPage> createState() => _QualityMonitoringPageState();
}

class _QualityMonitoringPageState extends State<QualityMonitoringPage> {
  String _monitoringPath = '';
  String? _monitoringBookmarkData;
  QualityData? _currentData;
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  String? _currentFileName;
  bool _isLoading = false;
  DateTime? _lastFileModified;

  // Manual counter variables
  int _manualGoodPieces = 0;
  int _manualRejectedPieces = 0;
  DateTime? _manualCounterStartTime;

  // Baseline values when manual counter was reset
  int _baselineGoodPieces = 0;
  int _baselineRejectedPieces = 0;

  @override
  void initState() {
    super.initState();
    _loadMonitoringPath();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    super.dispose();
  }

  bool _isMacOS() {
    return Platform.isMacOS;
  }

  Future<void> _loadMonitoringPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monitoringPath = prefs.getString('monitoring_path') ?? '';
      _monitoringBookmarkData = prefs.getString('monitoring_bookmark');
    });

    // Se abbiamo un bookmark salvato, proviamo a risolverlo
    await _restoreMonitoringBookmark();

    if (_monitoringPath.isNotEmpty) {
      _startMonitoring();
    }
  }

  Future<void> _saveMonitoringPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monitoring_path', path);

    // Salva anche il secure bookmark per macOS
    await _saveMonitoringBookmark(path);
  }

  Future<void> _saveMonitoringBookmark(String path) async {
    if (!_isMacOS()) return;

    try {
      final secureBookmarks = SecureBookmarks();
      final directory = Directory(path);
      final bookmark = await secureBookmarks.bookmark(directory);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('monitoring_bookmark', bookmark);
      _monitoringBookmarkData = bookmark;
      // Bookmark salvato con successo
    } catch (e) {
      // Errore salvataggio bookmark: continua senza fallire
    }
  }

  Future<void> _restoreMonitoringBookmark() async {
    if (!_isMacOS() || _monitoringBookmarkData == null) return;

    try {
      final secureBookmarks = SecureBookmarks();
      final resolvedUrl = await secureBookmarks.resolveBookmark(_monitoringBookmarkData!);

      final bool startedAccessing = await secureBookmarks.startAccessingSecurityScopedResource(resolvedUrl);
      if (startedAccessing) {
        // Bookmark ripristinato con successo
        setState(() {
          _monitoringPath = resolvedUrl.path;
        });

        // Aggiorna il percorso salvato in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('monitoring_path', resolvedUrl.path);
      }
    } catch (e) {
      // Errore ripristino bookmark: rimuovo bookmark non valido
      // Se il bookmark non è più valido, rimuovilo
      await _clearMonitoringBookmark();
    }
  }

  Future<void> _clearMonitoringBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('monitoring_bookmark');
    _monitoringBookmarkData = null;
  }

  Future<void> _selectMonitoringFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona cartella CSV di monitoraggio',
      );

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        setState(() {
          _monitoringPath = selectedDirectory;
        });
        await _saveMonitoringPath(selectedDirectory);
        _showSnackBar('✅ Cartella monitoraggio selezionata', const Color(0xFF059669));
        _startMonitoring();
      } else {
        _showSnackBar('ℹ️ Selezione annullata', const Color(0xFF64748B));
      }
    } catch (e) {
      _showSnackBar('❌ Errore selezione cartella: ${e.toString()}', const Color(0xFFDC2626));
    }
  }

  void _startMonitoring() async {
    if (_monitoringPath.isEmpty) return;

    setState(() {
      _isMonitoring = true;
    });

    // Test database connection when starting monitoring
    final dbConnected = await DatabaseService.testConnection();
    if (dbConnected) {
      _showSnackBar('🔄 Monitoraggio avviato - Database connesso', const Color(0xFF059669));
    } else {
      _showSnackBar('🔄 Monitoraggio avviato - Database non disponibile', const Color(0xFFEA580C));
    }

    _loadLatestCSVData();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadLatestCSVData();
    });
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
    _showSnackBar('⏸️ Monitoraggio fermato', const Color(0xFFEA580C));
  }

  void _resetManualCounter() {
    setState(() {
      // Salva i valori attuali come baseline
      _baselineGoodPieces = _currentData?.goodPieces ?? 0;
      _baselineRejectedPieces = _currentData?.rejectedPieces ?? 0;
      _manualCounterStartTime = DateTime.now();

      // I valori manuali partiranno da 0 (verranno calcolati nella prossima lettura)
      _manualGoodPieces = 0;
      _manualRejectedPieces = 0;
    });
    _showSnackBar('🔄 Contatore manuale azzerato', const Color(0xFF059669));
  }

  int get _manualTotalPieces => _manualGoodPieces + _manualRejectedPieces;

  // Test database save functionality
  void _testDatabaseSave() async {
    if (_currentData == null) {
      _showSnackBar('⚠️ Nessun dato da testare', const Color(0xFFEA580C));
      return;
    }

    _showSnackBar('🔄 Test salvataggio database...', const Color(0xFF059669));

    try {
      final success = await DatabaseService.saveQualityData(
        data: _currentData!,
        monitoringPath: _monitoringPath,
      );

      if (success) {
        _showSnackBar('✅ Test database completato con successo', const Color(0xFF059669));
      } else {
        _showSnackBar('❌ Test database fallito', const Color(0xFFDC2626));
      }
    } catch (e) {
      _showSnackBar('❌ Errore test database: ${e.toString()}', const Color(0xFFDC2626));
    }
  }

  Future<void> _loadLatestCSVData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Controlla se il percorso di monitoraggio è valido
      if (_monitoringPath.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final directory = Directory(_monitoringPath);
      if (!await directory.exists()) {
        _showSnackBar('❌ Cartella non esistente o non accessibile', const Color(0xFFDC2626));
        _stopMonitoring();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Test di accesso alla directory
      try {
        directory.listSync();
      } catch (e) {
        _showSnackBar('❌ Accesso negato alla cartella. Seleziona nuovamente la cartella.', const Color(0xFFDC2626));
        _stopMonitoring();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final csvFiles = directory
          .listSync()
          .where((file) => file.path.toLowerCase().endsWith('.csv'))
          .map((file) => file as File)
          .toList();

      if (csvFiles.isEmpty) {
        setState(() {
          _currentData = null;
          _currentFileName = null;
        });
        return;
      }

      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latestFile = csvFiles.first;
      final fileName = path_lib.basename(latestFile.path);
      final fileModified = latestFile.lastModifiedSync();

      // Controlla se il file è cambiato (nome diverso o data modifica diversa)
      bool fileChanged = false;

      if (_currentFileName != fileName) {
        fileChanged = true;
        setState(() {
          _currentFileName = fileName;
        });
      }

      if (_lastFileModified == null || _lastFileModified != fileModified) {
        fileChanged = true;
        _lastFileModified = fileModified;
      }


      // Aggiorna i dati solo se il file è cambiato
      if (fileChanged) {
        final content = await _readFileWithFallbackEncoding(latestFile);
        final data = _parseCSVData(content);

        setState(() {
          _currentData = data;

          // Aggiorna i contatori manuali se il reset è stato fatto
          if (_manualCounterStartTime != null) {
            _manualGoodPieces = data.goodPieces - _baselineGoodPieces;
            _manualRejectedPieces = data.rejectedPieces - _baselineRejectedPieces;

            // Assicurati che non vadano negativi (in caso di reset con dati già presenti)
            if (_manualGoodPieces < 0) _manualGoodPieces = 0;
            if (_manualRejectedPieces < 0) _manualRejectedPieces = 0;
          }
        });

        // Save to database (fire and forget - non blocca l'UI)
        _saveQualityDataToDatabase(data);
      }

    } catch (e) {
      _showSnackBar('⚠️ Errore lettura CSV: ${e.toString()}', const Color(0xFFEA580C));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  QualityData _parseCSVData(String csvContent) {
    final List<List<dynamic>> rows = const CsvToListConverter(fieldDelimiter: ';').convert(csvContent);

    if (rows.isEmpty) {
      return QualityData(
        totalPieces: 0,
        goodPieces: 0,
        rejectedPieces: 0,
        rejects: [],
        latestRejects: [],
        lastUpdate: DateTime.now(),
      );
    }

    // Trova gli indici delle colonne nel header
    final header = rows[0];
    int? stazioneIndex, esitoIndex, codiceScatoIndex, descrizioneIndex, progressivoIndex, dataOraIndex;

    for (int i = 0; i < header.length; i++) {
      final colName = header[i].toString().toLowerCase();
      if (colName.contains('stazione') && !colName.contains('id')) {
        stazioneIndex = i;
      } else if (colName.contains('esito')) {
        esitoIndex = i;
      } else if (colName.contains('codice') && colName.contains('scarto')) {
        codiceScatoIndex = i;
      } else if (colName.contains('descrizione') && colName.contains('scarto')) {
        descrizioneIndex = i;
      } else if (colName.contains('progressivo')) {
        progressivoIndex = i;
      } else if (colName.contains('data') && colName.contains('ora')) {
        dataOraIndex = i;
      }
    }


    int totalPieces = 0;
    int goodPieces = 0;
    int rejectedPieces = 0;
    final Map<String, Reject> rejectDetails = {};
    final List<RejectDetail> latestRejectsList = [];

    // Analizza ogni riga dei dati
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < header.length) continue;

      try {
        // Controlla l'esito e la stazione
        final esito = esitoIndex != null ? row[esitoIndex].toString().trim() : '';
        final stazione = stazioneIndex != null ? row[stazioneIndex].toString().trim() : '';

        // Debug per le prime 3 righe

        // Pezzi buoni: conta solo dalla stazione "Periferico" con esito "buono"
        if (stazione.toLowerCase().contains('periferico') && esito.toLowerCase() == 'buono') {
          goodPieces++;
        }

        // Scarti: conta solo con esito "scarto" (ignora tutto il resto)
        if (esito.toLowerCase() == 'scarto') {
          rejectedPieces++;
        }

        // Raccogli tutti gli scarti (da tutte le stazioni)
        if (esito.toLowerCase() == 'scarto') {

          // Raccoglie dettagli dello scarto
          final codiceScarto = codiceScatoIndex != null ? row[codiceScatoIndex].toString().trim() : '';
          final descrizioneScarto = descrizioneIndex != null ? row[descrizioneIndex].toString().trim() : '';
          final progressivo = progressivoIndex != null ? row[progressivoIndex].toString().trim() : '';
          final dataOra = dataOraIndex != null ? row[dataOraIndex].toString().trim() : '';

          // Aggiunge ai dettagli degli ultimi scarti (massimo 10)
          DateTime timestamp = DateTime.now();
          if (dataOra.isNotEmpty) {
            try {
              // Cerca di parsare la data nel formato DD/MM/YYYY HH:mm:ss
              final parts = dataOra.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length >= 2) {
                  timestamp = DateTime(
                    int.parse(dateParts[2]), // year
                    int.parse(dateParts[1]), // month
                    int.parse(dateParts[0]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                    timeParts.length > 2 ? int.parse(timeParts[2]) : 0, // second
                  );
                }
              }
            } catch (e) {
              // Se il parsing fallisce, usa il timestamp corrente
              timestamp = DateTime.now();
            }
          }

          latestRejectsList.add(RejectDetail(
            station: stazione,
            code: codiceScarto.isNotEmpty ? codiceScarto : 'N/A',
            description: descrizioneScarto.isNotEmpty && descrizioneScarto != '0' ? descrizioneScarto : 'N/A',
            timestamp: timestamp,
            progressivo: progressivo.isNotEmpty ? progressivo : 'N/A',
          ));

          String rejectKey = stazione;
          if (codiceScarto.isNotEmpty) {
            rejectKey += ' (Codice: $codiceScarto)';
          }
          if (descrizioneScarto.isNotEmpty && descrizioneScarto != '0') {
            rejectKey += ' - $descrizioneScarto';
          }

          if (rejectKey.isEmpty) rejectKey = 'Scarto sconosciuto';

          if (rejectDetails.containsKey(rejectKey)) {
            final existing = rejectDetails[rejectKey]!;
            rejectDetails[rejectKey] = Reject(
              reason: existing.reason,
              count: existing.count + 1,
              timestamp: DateTime.now(),
            );
          } else {
            rejectDetails[rejectKey] = Reject(
              reason: rejectKey,
              count: 1,
              timestamp: DateTime.now(),
            );
          }
        }
      } catch (e) {
        // Se non riesce a parsare una riga, continua con la prossima
        continue;
      }
    }

    // Converte la mappa in lista e ordina per conteggio
    final rejects = rejectDetails.values.toList();
    rejects.sort((a, b) => b.count.compareTo(a.count));

    // Ordina gli scarti dettagliati per timestamp (più recenti prima) e prende solo gli ultimi 10
    latestRejectsList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestRejects = latestRejectsList.take(10).toList();


    // Calcola il totale come somma di pezzi buoni e scarti
    totalPieces = goodPieces + rejectedPieces;

    return QualityData(
      totalPieces: totalPieces,
      goodPieces: goodPieces,
      rejectedPieces: rejectedPieces,
      rejects: rejects,
      latestRejects: latestRejects,
      lastUpdate: DateTime.now(),
    );
  }

  Future<String> _readFileWithFallbackEncoding(File file) async {
    try {
      // Prova prima con UTF-8
      return await file.readAsString();
    } catch (e) {
      try {
        // Fallback: leggi come bytes e prova Latin-1
        final bytes = await file.readAsBytes();
        return latin1.decode(bytes);
      } catch (e2) {
        try {
          // Ultimo tentativo: rimuovi caratteri non validi
          final bytes = await file.readAsBytes();
          return utf8.decode(bytes, allowMalformed: true);
        } catch (e3) {
          throw Exception('Impossibile leggere il file con nessun encoding supportato');
        }
      }
    }
  }

  // Funzione per salvare i dati di qualità nel database (asincrona non bloccante)
  void _saveQualityDataToDatabase(QualityData data) async {
    try {
      debugPrint('🔄 Tentativo salvataggio dati: ${data.totalPieces} totali, ${data.goodPieces} buoni, ${data.rejectedPieces} scarti');

      final saved = await DatabaseService.saveQualityData(
        data: data,
        monitoringPath: _monitoringPath,
      );

      if (saved) {
        debugPrint('✅ Dati salvati con successo nel database');
        // Feedback visivo discreto di successo
        if (mounted) {
          _showSnackBar('💾 Dati sincronizzati', const Color(0xFF059669));
        }
      } else {
        debugPrint('❌ Errore salvataggio dati nel database');
        if (mounted) {
          _showSnackBar('⚠️ Dati qualità non sincronizzati con database', const Color(0xFFEA580C));
        }
      }
    } catch (e) {
      // Log error but don't show snackbar to avoid UI spam
      debugPrint('Error saving quality data to database: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          PhosphorIcons.chartLine(),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monitoraggio Qualità Real-Time',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Monitora i file CSV generati dalla macchina di controllo',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (_isMonitoring) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ATTIVO',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _monitoringPath.isEmpty
                              ? PhosphorIcons.folder()
                              : PhosphorIcons.folderSimple(),
                          color: _monitoringPath.isEmpty
                              ? Colors.grey.shade400
                              : Theme.of(context).colorScheme.tertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _monitoringPath.isEmpty
                                ? 'Seleziona cartella CSV'
                                : _monitoringPath,
                            style: TextStyle(
                              color: _monitoringPath.isEmpty
                                  ? Colors.grey.shade500
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _monitoringPath.isEmpty
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _selectMonitoringFolder,
                          icon: Icon(PhosphorIcons.folderOpen()),
                          label: const Text('Scegli Cartella'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _monitoringPath.isEmpty
                              ? null
                              : (_isMonitoring ? _stopMonitoring : _startMonitoring),
                          icon: Icon(_isMonitoring ? PhosphorIcons.pause() : PhosphorIcons.play()),
                          label: Text(_isMonitoring ? 'Stop' : 'Start'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: _isMonitoring
                                ? Colors.orange.shade600
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetManualCounter,
                          icon: Icon(PhosphorIcons.arrowCounterClockwise()),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentData != null ? _testDatabaseSave : null,
                          icon: Icon(PhosphorIcons.database()),
                          label: const Text('Test DB'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_currentData != null) ...[
            const SizedBox(height: 24),

            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: PhosphorIcons.package(),
                      title: 'Pezzi Totali',
                      value: _currentData!.totalPieces.toString(),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: PhosphorIcons.checkCircle(),
                      title: 'Pezzi Buoni',
                      value: _currentData!.goodPieces.toString(),
                      color: Colors.green,
                      subtitle: '${_currentData!.acceptanceRate.toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: PhosphorIcons.xCircle(),
                      title: 'Scarti',
                      value: _currentData!.rejectedPieces.toString(),
                      color: Colors.red,
                      subtitle: '${_currentData!.rejectionRate.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
            ),

            // Manual Counter Section
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.shade100.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.timer(),
                          color: Colors.purple.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Contatore Manuale',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_manualCounterStartTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Avviato ${_manualCounterStartTime!.hour.toString().padLeft(2, '0')}:${_manualCounterStartTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: PhosphorIcons.package(),
                            title: 'Totale Manuale',
                            value: _manualTotalPieces.toString(),
                            color: Colors.purple.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: PhosphorIcons.checkCircle(),
                            title: 'Buoni Manuale',
                            value: _manualGoodPieces.toString(),
                            color: Colors.green.shade600,
                            subtitle: _manualTotalPieces > 0
                                ? '${((_manualGoodPieces / _manualTotalPieces) * 100).toStringAsFixed(1)}%'
                                : '0.0%',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: PhosphorIcons.xCircle(),
                            title: 'Scarti Manuale',
                            value: _manualRejectedPieces.toString(),
                            color: Colors.red.shade600,
                            subtitle: _manualTotalPieces > 0
                                ? '${((_manualRejectedPieces / _manualTotalPieces) * 100).toStringAsFixed(1)}%'
                                : '0.0%',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_currentData!.rejects.isNotEmpty) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              PhosphorIcons.warning(),
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Motivi Scarto',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _currentData!.rejects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reject = _currentData!.rejects[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      reject.count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reject.reason,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Sezione Ultimi 10 Scarti
            if (_currentData!.latestRejects.isNotEmpty) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              PhosphorIcons.clock(),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ultimi 10 Scarti',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _currentData!.latestRejects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reject = _currentData!.latestRejects[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Pezzo ${reject.progressivo}',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${reject.timestamp.day.toString().padLeft(2, '0')}/${reject.timestamp.month.toString().padLeft(2, '0')}/${reject.timestamp.year} ${reject.timestamp.hour.toString().padLeft(2, '0')}:${reject.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.warning(),
                                      color: Colors.orange.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Codice: ${reject.code}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                if (reject.description != 'N/A') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    reject.description,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade100,
                      Colors.grey.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.clock(),
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ultimo aggiornamento',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_currentData!.lastUpdate.hour.toString().padLeft(2, '0')}:${_currentData!.lastUpdate.minute.toString().padLeft(2, '0')}:${_currentData!.lastUpdate.second.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_currentFileName != null) ...[
                      Icon(
                        PhosphorIcons.fileText(),
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _currentFileName!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          if (_currentData == null && _isMonitoring) ...[
            const SizedBox(height: 40),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Caricamento dati...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          PhosphorIcons.fileX(),
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nessun file CSV trovato',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verifica che ci siano file CSV nella cartella selezionata',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Remote Job Request Page - For requesting jobs from remote devices
class RemoteJobRequestPage extends StatefulWidget {
  const RemoteJobRequestPage({super.key});

  @override
  State<RemoteJobRequestPage> createState() => _RemoteJobRequestPageState();
}

class _RemoteJobRequestPageState extends State<RemoteJobRequestPage> {
  final TextEditingController _articleCodeController = TextEditingController();
  final TextEditingController _lotController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRecentRequests();
  }

  Future<void> _loadRecentRequests() async {
    try {
      await AppModeService.getPendingRequests();
      if (mounted) {
        setState(() {
          // Recent requests loaded but not stored locally
        });
      }
    } catch (e) {
      debugPrint('Errore caricamento richieste: $e');
    }
  }

  Future<void> _submitJobRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await AppModeService.submitJobRequest(
        articleCode: _articleCodeController.text.trim(),
        lot: _lotController.text.trim(),
        pieces: int.parse(_piecesController.text.trim()),
        requestedBy: 'Remote App',
      );

      if (mounted) {
        if (success) {
          _articleCodeController.clear();
          _lotController.clear();
          _piecesController.clear();
          _loadRecentRequests();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Richiesta job inviata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Errore nell\'invio della richiesta'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIcons.paperPlaneRight(),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Richiesta Job Remota',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Invia richiesta alla macchina principale',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 200),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.fileText(), color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Dettagli Job', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _articleCodeController,
                          decoration: InputDecoration(
                            labelText: 'Codice Articolo',
                            hintText: 'Es: PXO7471-250905',
                            prefixIcon: Icon(PhosphorIcons.barcode()),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci il codice articolo';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _lotController,
                          decoration: InputDecoration(
                            labelText: 'Lotto',
                            hintText: 'Es: 310',
                            prefixIcon: Icon(PhosphorIcons.package()),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci il lotto';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _piecesController,
                          decoration: InputDecoration(
                            labelText: 'Numero Pezzi',
                            hintText: 'Es: 15',
                            prefixIcon: Icon(PhosphorIcons.hash()),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci il numero di pezzi';
                            }
                            final pieces = int.tryParse(value.trim());
                            if (pieces == null || pieces <= 0) {
                              return 'Inserisci un numero valido maggiore di 0';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitJobRequest,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(PhosphorIcons.paperPlaneRight()),
                                      const SizedBox(width: 8),
                                      const Text('Invia Richiesta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _articleCodeController.dispose();
    _lotController.dispose();
    _piecesController.dispose();
    super.dispose();
  }
}

// Remote Quality Dashboard - For viewing real-time data
class RemoteQualityDashboard extends StatefulWidget {
  const RemoteQualityDashboard({super.key});

  @override
  State<RemoteQualityDashboard> createState() => _RemoteQualityDashboardState();
}

class _RemoteQualityDashboardState extends State<RemoteQualityDashboard> {
  List<Map<String, dynamic>> _qualityData = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadQualityData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadQualityData();
    });
  }

  Future<void> _loadQualityData() async {
    try {
      final data = await DatabaseService.getQualityHistory();
      if (mounted) {
        setState(() {
          // Show only the latest record
          _qualityData = data.isNotEmpty ? [data.first] : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Errore caricamento dati qualità: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQualityData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(PhosphorIcons.chartLine(), color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monitoraggio Remoto',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Dati in tempo reale',
                                    style: TextStyle(fontSize: 14, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _loadQualityData,
                              icon: Icon(PhosphorIcons.arrowClockwise(), color: Colors.white),
                              tooltip: 'Aggiorna',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_qualityData.isEmpty)
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(PhosphorIcons.database(), size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text('Nessun dato disponibile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                const SizedBox(height: 8),
                                Text('I dati appariranno qui quando disponibili', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...(_qualityData.map((data) => FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(PhosphorIcons.chartLineUp(), color: Theme.of(context).colorScheme.primary, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Monitoraggio Qualità', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            Text('${data['monitoring_path'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: _buildStatCard('Totali', '${data['total_pieces'] ?? 0}', Colors.blue)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildStatCard('Buoni', '${data['good_pieces'] ?? 0}', Colors.green)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildStatCard('Scarti', '${data['rejected_pieces'] ?? 0}', Colors.red)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )).toList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
