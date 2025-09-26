import 'package:shared_preferences/shared_preferences.dart';

enum FilterPeriod {
  currentWeek,    // Settimana corrente (lunedì-domenica)
  lastWeek,       // Settimana scorsa
  currentMonth,   // Mese corrente
  lastMonth,      // Mese scorso
  custom,         // Range personalizzato
  all            // Tutti i dati
}

class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  DateRange({required this.startDate, required this.endDate});

  @override
  String toString() {
    return 'DateRange(start: ${startDate.toIso8601String()}, end: ${endDate.toIso8601String()})';
  }
}

class FilterService {
  static final FilterService _instance = FilterService._internal();
  factory FilterService() => _instance;
  FilterService._internal();

  static const String _keyFilterPeriod = 'filter_period';
  static const String _keyCustomStartDate = 'custom_start_date';
  static const String _keyCustomEndDate = 'custom_end_date';

  FilterPeriod _currentPeriod = FilterPeriod.currentWeek;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  FilterPeriod get currentPeriod => _currentPeriod;

  /// Inizializza il servizio caricando le preferenze salvate
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Carica il periodo salvato
    final periodIndex = prefs.getInt(_keyFilterPeriod);
    if (periodIndex != null && periodIndex < FilterPeriod.values.length) {
      _currentPeriod = FilterPeriod.values[periodIndex];
    }

    // Carica le date personalizzate
    final startDateString = prefs.getString(_keyCustomStartDate);
    if (startDateString != null) {
      _customStartDate = DateTime.tryParse(startDateString);
    }

    final endDateString = prefs.getString(_keyCustomEndDate);
    if (endDateString != null) {
      _customEndDate = DateTime.tryParse(endDateString);
    }
  }

  /// Imposta il periodo di filtro
  Future<void> setFilterPeriod(FilterPeriod period) async {
    _currentPeriod = period;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFilterPeriod, period.index);
  }

  /// Imposta un range personalizzato
  Future<void> setCustomRange(DateTime startDate, DateTime endDate) async {
    _customStartDate = startDate;
    _customEndDate = endDate;
    _currentPeriod = FilterPeriod.custom;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFilterPeriod, FilterPeriod.custom.index);
    await prefs.setString(_keyCustomStartDate, startDate.toIso8601String());
    await prefs.setString(_keyCustomEndDate, endDate.toIso8601String());
  }

  /// Ottiene il range di date corrente basato sul filtro attivo
  DateRange getCurrentDateRange() {
    final now = DateTime.now();

    switch (_currentPeriod) {
      case FilterPeriod.currentWeek:
        return _getCurrentWeekRange(now);

      case FilterPeriod.lastWeek:
        final lastWeek = now.subtract(const Duration(days: 7));
        return _getCurrentWeekRange(lastWeek);

      case FilterPeriod.currentMonth:
        return DateRange(
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1))
        );

      case FilterPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return DateRange(
          startDate: lastMonth,
          endDate: DateTime(lastMonth.year, lastMonth.month + 1, 1).subtract(const Duration(days: 1))
        );

      case FilterPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return DateRange(
            startDate: _customStartDate!,
            endDate: _customEndDate!
          );
        }
        // Fallback alla settimana corrente se non ci sono date personalizzate
        return _getCurrentWeekRange(now);

      case FilterPeriod.all:
        // Ritorna un range molto ampio per mostrare tutti i dati
        return DateRange(
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2030, 12, 31)
        );
    }
  }

  /// Calcola il range della settimana (lunedì-domenica) per una data specifica
  DateRange _getCurrentWeekRange(DateTime date) {
    // Trova il lunedì della settimana
    final mondayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final startOfMonday = DateTime(mondayOfWeek.year, mondayOfWeek.month, mondayOfWeek.day);

    // Domenica è 6 giorni dopo il lunedì
    final endOfSunday = startOfMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return DateRange(
      startDate: startOfMonday,
      endDate: endOfSunday
    );
  }

  /// Genera la clausola WHERE per le query SQL
  String getWhereClause({String timestampColumn = 'timestamp'}) {
    if (_currentPeriod == FilterPeriod.all) {
      return '';
    }

    final range = getCurrentDateRange();
    return "$timestampColumn >= '${range.startDate.toUtc().toIso8601String()}' AND $timestampColumn <= '${range.endDate.toUtc().toIso8601String()}'";
  }

  /// Genera i parametri per Supabase query
  Map<String, dynamic> getSupabaseFilter({String timestampColumn = 'timestamp'}) {
    if (_currentPeriod == FilterPeriod.all) {
      return {};
    }

    final range = getCurrentDateRange();
    return {
      '${timestampColumn}_gte': range.startDate.toUtc().toIso8601String(),
      '${timestampColumn}_lte': range.endDate.toUtc().toIso8601String(),
    };
  }

  /// Verifica se una data è inclusa nel filtro corrente
  bool isDateInCurrentFilter(DateTime date) {
    if (_currentPeriod == FilterPeriod.all) {
      return true;
    }

    final range = getCurrentDateRange();
    return date.isAfter(range.startDate.subtract(const Duration(seconds: 1))) &&
           date.isBefore(range.endDate.add(const Duration(seconds: 1)));
  }

  /// Restituisce una descrizione leggibile del filtro corrente
  String getFilterDescription() {
    switch (_currentPeriod) {
      case FilterPeriod.currentWeek:
        final range = getCurrentDateRange();
        return 'Settimana corrente (${_formatDate(range.startDate)} - ${_formatDate(range.endDate)})';

      case FilterPeriod.lastWeek:
        final range = getCurrentDateRange();
        return 'Settimana scorsa (${_formatDate(range.startDate)} - ${_formatDate(range.endDate)})';

      case FilterPeriod.currentMonth:
        final now = DateTime.now();
        return 'Mese corrente (${_getMonthName(now.month)} ${now.year})';

      case FilterPeriod.lastMonth:
        final lastMonth = DateTime.now().month == 1 ? 12 : DateTime.now().month - 1;
        final year = DateTime.now().month == 1 ? DateTime.now().year - 1 : DateTime.now().year;
        return 'Mese scorso (${_getMonthName(lastMonth)} $year)';

      case FilterPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return 'Periodo personalizzato (${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)})';
        }
        return 'Periodo personalizzato (non configurato)';

      case FilterPeriod.all:
        return 'Tutti i dati';
    }
  }

  /// Lista delle opzioni disponibili per l'UI
  List<String> getFilterOptions() {
    return [
      'Settimana corrente',
      'Settimana scorsa',
      'Mese corrente',
      'Mese scorso',
      'Periodo personalizzato',
      'Tutti i dati'
    ];
  }

  /// Converte l'indice dell'opzione al FilterPeriod
  FilterPeriod getFilterPeriodFromIndex(int index) {
    if (index >= 0 && index < FilterPeriod.values.length) {
      return FilterPeriod.values[index];
    }
    return FilterPeriod.currentWeek;
  }

  /// Ottiene l'indice dell'opzione corrente
  int getCurrentFilterIndex() {
    return _currentPeriod.index;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return months[month];
  }

  /// Reset alle impostazioni predefinite
  Future<void> reset() async {
    _currentPeriod = FilterPeriod.currentWeek;
    _customStartDate = null;
    _customEndDate = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFilterPeriod);
    await prefs.remove(_keyCustomStartDate);
    await prefs.remove(_keyCustomEndDate);
  }
}