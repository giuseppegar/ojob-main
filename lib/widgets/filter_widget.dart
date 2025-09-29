import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/filter_service.dart';

class FilterWidget extends StatefulWidget {
  final VoidCallback? onFilterChanged;
  final FilterService? filterService;

  const FilterWidget({
    super.key,
    this.onFilterChanged,
    this.filterService,
  });

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  late final FilterService _filterService;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _filterService = widget.filterService ?? FilterService();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            PhosphorIconsRegular.funnel,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          'Filtro Periodo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _filterService.getFilterDescription(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        collapsedIconColor: Colors.white,
        iconColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Opzioni filtro
                ...List.generate(_filterService.getFilterOptions().length, (index) {
                  final option = _filterService.getFilterOptions()[index];
                  final isSelected = _filterService.getCurrentFilterIndex() == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onFilterOptionSelected(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? PhosphorIconsRegular.check
                                      : PhosphorIconsRegular.circle,
                                  color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                                  size: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Sezione periodo personalizzato
                if (_filterService.currentPeriod == FilterPeriod.custom) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIconsRegular.calendarPlus,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Configura Periodo Personalizzato',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Aggiornamento automatico alla selezione',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status indicator per date personalizzate
                        if (_customStartDate != null || _customEndDate != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (_customStartDate != null && _customEndDate != null)
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_customStartDate != null && _customEndDate != null)
                                    ? Colors.green
                                    : Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (_customStartDate != null && _customEndDate != null)
                                      ? PhosphorIconsRegular.checkCircle
                                      : PhosphorIconsRegular.clock,
                                  size: 14,
                                  color: (_customStartDate != null && _customEndDate != null)
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (_customStartDate != null && _customEndDate != null)
                                      ? 'Periodo configurato - Dati aggiornati automaticamente'
                                      : 'Seleziona entrambe le date per aggiornamento automatico',
                                  style: TextStyle(
                                    color: (_customStartDate != null && _customEndDate != null)
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Data inizio
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateSelector(
                                label: 'Data Inizio',
                                selectedDate: _customStartDate,
                                onDateSelected: (date) {
                                  setState(() {
                                    _customStartDate = date;
                                  });
                                  _updateCustomRange();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateSelector(
                                label: 'Data Fine',
                                selectedDate: _customEndDate,
                                onDateSelected: (date) {
                                  setState(() {
                                    _customEndDate = date;
                                  });
                                  _updateCustomRange();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Bottone Reset
                Center(
                  child: TextButton.icon(
                    onPressed: _resetFilter,
                    icon: Icon(
                      PhosphorIconsRegular.arrowClockwise,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    label: Text(
                      'Reset Filtro',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _selectDate(onDateSelected),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.calendar,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedDate != null
                        ? _formatDate(selectedDate)
                        : 'Seleziona',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(Function(DateTime) onDateSelected) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      onDateSelected(selectedDate);
    }
  }

  Future<void> _onFilterOptionSelected(int index) async {
    debugPrint('🎯 FilterWidget: _onFilterOptionSelected chiamato per index $index');
    final period = _filterService.getFilterPeriodFromIndex(index);
    await _filterService.setFilterPeriod(period);
    setState(() {});

    if (widget.onFilterChanged != null) {
      debugPrint('🔔 FilterWidget: chiamando onFilterChanged callback');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFilterChanged!();
      });
    } else {
      debugPrint('⚠️ FilterWidget: onFilterChanged callback è null');
    }
  }

  Future<void> _updateCustomRange() async {
    if (_customStartDate != null && _customEndDate != null) {
      if (_customStartDate!.isAfter(_customEndDate!)) {
        // Scambia le date se sono nell'ordine sbagliato
        final temp = _customStartDate;
        _customStartDate = _customEndDate;
        _customEndDate = temp;
      }

      await _filterService.setCustomRange(_customStartDate!, _customEndDate!);
      setState(() {});

      // Chiamata asincrona per permettere al widget di aggiornarsi
      if (widget.onFilterChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onFilterChanged!();
        });
      }
    }
  }

  Future<void> _resetFilter() async {
    await _filterService.reset();
    setState(() {
      _customStartDate = null;
      _customEndDate = null;
    });

    if (widget.onFilterChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFilterChanged!();
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}