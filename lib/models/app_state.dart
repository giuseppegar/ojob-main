import 'package:flutter/foundation.dart';

enum AppMode {
  server('Server', 'Macchina principale - Elabora file e richieste'),
  remote('Remote', 'Controllo remoto - Visualizza dati e invia richieste'),
  standalone('Standalone', 'Modalità locale - Senza connessione al database');

  const AppMode(this.label, this.description);
  final String label;
  final String description;
}

class AppState extends ChangeNotifier {
  AppMode _currentMode = AppMode.server;
  bool _isDatabaseConnected = false;
  String _lastConnectionStatus = '';
  bool _isAutoKeyboardEnabled = false;
  bool _isWindowsTouchDevice = false;

  // Counter state
  DateTime? _manualCounterStartTime;
  int _manualPiecesAtStart = 0;
  int _manualPartsAtStart = 0;
  String _manualMachineAtStart = '';
  int _manualRunningSeconds = 0;
  bool _isCounterRunning = false;

  // Getters
  AppMode get currentMode => _currentMode;
  bool get isDatabaseConnected => _isDatabaseConnected;
  String get lastConnectionStatus => _lastConnectionStatus;
  bool get isAutoKeyboardEnabled => _isAutoKeyboardEnabled;
  bool get isWindowsTouchDevice => _isWindowsTouchDevice;

  DateTime? get manualCounterStartTime => _manualCounterStartTime;
  int get manualPiecesAtStart => _manualPiecesAtStart;
  int get manualPartsAtStart => _manualPartsAtStart;
  String get manualMachineAtStart => _manualMachineAtStart;
  int get manualRunningSeconds => _manualRunningSeconds;
  bool get isCounterRunning => _isCounterRunning;

  // Setters
  void setMode(AppMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  void setDatabaseConnection(bool connected) {
    if (_isDatabaseConnected != connected) {
      _isDatabaseConnected = connected;
      _lastConnectionStatus = connected ? 'connected' : 'disconnected';
      notifyListeners();
    }
  }

  void setAutoKeyboard(bool enabled) {
    _isAutoKeyboardEnabled = enabled;
    notifyListeners();
  }

  void setWindowsTouchDevice(bool isTouchDevice) {
    _isWindowsTouchDevice = isTouchDevice;
    notifyListeners();
  }

  void startManualCounter(DateTime startTime, int pieces, int parts, String machine) {
    _manualCounterStartTime = startTime;
    _manualPiecesAtStart = pieces;
    _manualPartsAtStart = parts;
    _manualMachineAtStart = machine;
    _manualRunningSeconds = 0;
    _isCounterRunning = true;
    notifyListeners();
  }

  void updateCounterTime(int seconds) {
    _manualRunningSeconds = seconds;
    notifyListeners();
  }

  void resetManualCounter() {
    _manualCounterStartTime = null;
    _manualPiecesAtStart = 0;
    _manualPartsAtStart = 0;
    _manualMachineAtStart = '';
    _manualRunningSeconds = 0;
    _isCounterRunning = false;
    notifyListeners();
  }

  void stopCounter() {
    _isCounterRunning = false;
    notifyListeners();
  }
}