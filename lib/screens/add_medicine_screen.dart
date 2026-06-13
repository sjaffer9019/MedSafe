import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/medicine_model.dart';
import '../providers/medicine_provider.dart';
import '../services/openfda_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? editMedicine;
  const AddMedicineScreen({super.key, this.editMedicine});

  bool get isEditMode => editMedicine != null;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  // ── Layout Constants ──────────────────────────────────────
  static const double _padding        = 16.0;
  static const double _borderRadius   = 12.0;

  // ── Form ─────────────────────────────────────────────────
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController  = TextEditingController();

  // ── Medicine type / unit ──────────────────────────────────
  String _selectedType = 'Tablet';
  final List<String> _types = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Inhaler', 'Drops', 'Topical', 'Patch'];
  String _dosageUnit   = 'mg';
  final List<String> _units = ['mg', 'ml', 'mcg', 'g', 'mg/ml', 'units'];

  // ── Frequency / time slots ────────────────────────────────
  String _frequency = 'Once Daily';
  final List<String> _frequencies = ['Once Daily', 'Twice Daily', 'Thrice Daily', 'Custom'];
  List<TimeOfDay>            _selectedTimes   = [const TimeOfDay(hour: 8, minute: 0)];
  List<TextEditingController> _timeControllers = [];

  // ── Dates ─────────────────────────────────────────────────
  DateTime _startDate = DateTime.now();
  DateTime _endDate   = DateTime.now().add(const Duration(days: 30));

  // ── Search state ──────────────────────────────────────────
  List<DrugResult> _searchResults = [];
  bool  _isSearching    = false;
  bool  _showDropdown   = false;
  Timer? _debounce;
  final _searchFocusNode = FocusNode();

  bool _isLoading = false;

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _timeControllers = [TextEditingController(text: '08:00 AM')];

    // Pre-fill if in edit mode
    final med = widget.editMedicine;
    if (med != null) {
      _nameController.text = med.name;
      if (_types.contains(med.type)) _selectedType = med.type;
      _dosageController.text = med.dosage.replaceAll(RegExp(r'\s*(mg|ml|mcg|g|mg/ml|units)\s*$'), '');
      // Try to extract unit from dosage
      for (final u in _units) {
        if (med.dosage.toLowerCase().endsWith(u.toLowerCase())) {
          _dosageUnit = u;
          _dosageController.text = med.dosage.substring(0, med.dosage.toLowerCase().lastIndexOf(u.toLowerCase())).trim();
          break;
        }
      }
      _frequency = _frequencies.contains(med.frequency) ? med.frequency : 'Custom';
      try {
        _startDate = DateTime.parse(med.startDate);
      } catch (_) {}
      try {
        _endDate = DateTime.parse(med.endDate);
      } catch (_) {}
      // Parse existing times
      _selectedTimes = [];
      _timeControllers = [];
      for (final t in med.times) {
        final parsed = _parseTime(t);
        if (parsed != null) {
          _selectedTimes.add(parsed);
          _timeControllers.add(TextEditingController(text: _formatTime(parsed)));
        } else {
          _selectedTimes.add(const TimeOfDay(hour: 8, minute: 0));
          _timeControllers.add(TextEditingController(text: t));
        }
      }
      if (_selectedTimes.isEmpty) {
        _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
        _timeControllers = [TextEditingController(text: '08:00 AM')];
      }
      // Pre-fill notes
      _notesController.text = med.notes;
    }

    _nameController.addListener(_onNameChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // Delay closing so onTap on a list item can fire first
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showDropdown = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _searchFocusNode.dispose();
    for (final c in _timeControllers) c.dispose();
    super.dispose();
  }

  // ── Search helpers ────────────────────────────────────────
  void _onNameChanged() {
    final query = _nameController.text.trim();
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() { _showDropdown = false; _searchResults = []; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await OpenFDAService.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching   = false;
        _showDropdown  = results.isNotEmpty && _searchFocusNode.hasFocus;
      });
    });
  }

  void _selectDrug(DrugResult drug) {
    // Dismiss keyboard and dropdown first
    FocusScope.of(context).unfocus();
    setState(() {
      _showDropdown  = false;
      _searchResults = [];
    });
    // Small delay to ensure setState flushes before updating text
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _nameController.text = drug.displayName;
        // Move cursor to end
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: drug.displayName.length),
        );
        // Auto-fill dosage
        if (drug.strengthValue.isNotEmpty) {
          _dosageController.text = drug.strengthValue;
        }
        if (_units.contains(drug.suggestedUnit)) {
          _dosageUnit = drug.suggestedUnit;
        }
        if (_types.contains(drug.dosageForm)) {
          _selectedType = drug.dosageForm;
        }
      });
    });
  }

  // ── Time helpers ──────────────────────────────────────────
  String _formatTime(TimeOfDay t) {
    final hour   = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  TimeOfDay? _parseTime(String input) {
    final cleaned = input.trim().toUpperCase();
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$');
    final match = reg.firstMatch(cleaned);
    if (match == null) return null;
    int    hour   = int.parse(match.group(1)!);
    final  minute = int.parse(match.group(2)!);
    final  period = match.group(3);
    if (minute > 59) return null;
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour  = 0;
    } else {
      if (hour > 23) return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  // ── Frequency change ──────────────────────────────────────
  void _onFrequencyChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _frequency = newValue;
      for (final c in _timeControllers) c.dispose();
      _selectedTimes   = [];
      _timeControllers = [];

      void addSlot(TimeOfDay t) {
        _selectedTimes.add(t);
        _timeControllers.add(TextEditingController(text: _formatTime(t)));
      }

      switch (_frequency) {
        case 'Once Daily':
          addSlot(const TimeOfDay(hour: 8, minute: 0));
          break;
        case 'Twice Daily':
          addSlot(const TimeOfDay(hour: 8,  minute: 0));
          addSlot(const TimeOfDay(hour: 20, minute: 0));
          break;
        case 'Thrice Daily':
          addSlot(const TimeOfDay(hour: 8,  minute: 0));
          addSlot(const TimeOfDay(hour: 14, minute: 0));
          addSlot(const TimeOfDay(hour: 20, minute: 0));
          break;
        case 'Custom':
          addSlot(const TimeOfDay(hour: 8, minute: 0));
          break;
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: c.primary,
                  onPrimary: Colors.white,
                  surface: c.surface,
                  onSurface: c.textPrimary,
                )
              : ColorScheme.light(
                  primary: c.primary,
                  onPrimary: Colors.white,
                  onSurface: c.textPrimary,
                ),
          dialogBackgroundColor: c.card,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index]         = picked;
        _timeControllers[index].text  = _formatTime(picked);
      });
    }
  }

  Future<void> _pickDate(bool isStartDate) async {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate   = isStartDate ? DateTime.now() : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2050),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: c.primary,
                  onPrimary: Colors.white,
                  surface: c.surface,
                  onSurface: c.textPrimary,
                )
              : ColorScheme.light(
                  primary: c.primary,
                  onPrimary: Colors.white,
                  onSurface: c.textPrimary,
                ),
          dialogBackgroundColor: c.card,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addCustomTime() {
    final t = const TimeOfDay(hour: 12, minute: 0);
    setState(() {
      _selectedTimes.add(t);
      _timeControllers.add(TextEditingController(text: _formatTime(t)));
    });
  }

  void _removeCustomTime(int index) {
    if (_selectedTimes.length > 1) {
      setState(() {
        _selectedTimes.removeAt(index);
        _timeControllers[index].dispose();
        _timeControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveMedicine() async {
    final c = AppColors.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please select at least one time.'), backgroundColor: c.error),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('End date cannot be before start date.'), backgroundColor: c.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final List<String> formattedTimes = [];
      for (int i = 0; i < _timeControllers.length; i++) {
        final parsed = _parseTime(_timeControllers[i].text);
        formattedTimes.add(parsed != null ? _formatTime(parsed) : _formatTime(_selectedTimes[i]));
      }

      final dosageValue = _dosageController.text.trim();
      final medicine = Medicine(
        id:        widget.editMedicine?.id,
        name:      _nameController.text.trim(),
        type:      _selectedType,
        dosage:    dosageValue.isNotEmpty ? '$dosageValue $_dosageUnit' : _dosageUnit,
        frequency: _frequency,
        times:     formattedTimes,
        startDate: _startDate.toIso8601String(),
        endDate:   _endDate.toIso8601String(),
        notes:     _notesController.text.trim(),
      );

      if (widget.isEditMode) {
        await context.read<MedicineProvider>().updateMedicine(medicine);
      } else {
        await context.read<MedicineProvider>().addMedicine(medicine);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditMode
              ? 'Medicine successfully updated!'
              : 'Medicine successfully added!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save medicine to database.'),
          backgroundColor: AppColors.of(context).error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Input decoration helper ───────────────────────────────
  InputDecoration _inputDecoration(String label, {Widget? suffix}) {
    final c = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: c.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: c.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Medicine' : 'Add Medicine',
            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _showDropdown = false);
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(_padding),
              children: [
                // ── SECTION 1: Medicine Information ──────────
                _buildSectionTitle('Medicine Information'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius)),
                  color: c.card,
                  child: Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Drug Search Bar ─────────────────
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        // ── Dosage + Unit ───────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _dosageController,
                                decoration: _inputDecoration('Dosage *'),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _dosageUnit,
                                decoration: _inputDecoration('Unit'),
                                items: _units
                                    .map((u) =>
                                        DropdownMenuItem(value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _dosageUnit = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── Medicine Type ───────────────────
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: _inputDecoration('Medicine Type'),
                          items: _types
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedType = val!),
                        ),
                        const SizedBox(height: 16),
                        // ── Notes ───────────────────────────
                        TextFormField(
                          controller: _notesController,
                          decoration: _inputDecoration('Notes (Optional)'),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── SECTION 2: Frequency & Schedule ──────────
                _buildSectionTitle('Frequency & Schedule'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius)),
                  color: c.card,
                  child: Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _frequency,
                          decoration: _inputDecoration('Frequency'),
                          items: _frequencies
                              .map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: _onFrequencyChanged,
                        ),
                        const SizedBox(height: 16),
                        Text('Times',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary)),
                        const SizedBox(height: 8),
                        ...List.generate(_selectedTimes.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _timeControllers[index],
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 08:00 AM',
                                      filled: true,
                                      fillColor: c.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(_borderRadius),
                                        borderSide: BorderSide(color: c.divider),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(_borderRadius),
                                        borderSide: BorderSide(color: c.divider),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(_borderRadius),
                                        borderSide: BorderSide(color: c.primary, width: 2),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                    ),
                                    onChanged: (val) {
                                      final parsed = _parseTime(val);
                                      if (parsed != null) {
                                        setState(() =>
                                            _selectedTimes[index] = parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _pickTime(index),
                                  icon: Icon(Icons.access_time,
                                      color: c.primary),
                                  tooltip: 'Pick time',
                                ),
                                if (_frequency == 'Custom')
                                  IconButton(
                                    onPressed: () => _removeCustomTime(index),
                                    icon: Icon(Icons.remove_circle_outline,
                                        color: c.error),
                                    tooltip: 'Remove',
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (_frequency == 'Custom')
                          TextButton.icon(
                            onPressed: _addCustomTime,
                            icon: Icon(Icons.add, color: c.primary),
                            label: Text('Add Time Slot',
                                style: TextStyle(color: c.primary)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── SECTION 3: Treatment Period ───────────────
                _buildSectionTitle('Treatment Period'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius)),
                  color: c.card,
                  child: Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: Row(
                      children: [
                        Expanded(
                            child:
                                _buildDateSelector('Start Date', _startDate, true)),
                        const SizedBox(width: 16),
                        Expanded(
                            child:
                                _buildDateSelector('End Date', _endDate, false)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Save Button ───────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveMedicine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_borderRadius)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text(widget.isEditMode ? 'Save Changes' : 'Save Medicine',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _buildSearchBar() {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field
        TextFormField(
          controller: _nameController,
          focusNode: _searchFocusNode,
          decoration: _inputDecoration(
            'Medicine Name *',
            suffix: _isSearching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.primary)),
                  )
                : _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: c.textSecondary),
                        onPressed: () {
                          _nameController.clear();
                          setState(() {
                            _showDropdown  = false;
                            _searchResults = [];
                          });
                        },
                      )
                    : Icon(Icons.search, color: c.textSecondary),
          ),
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        // Dropdown results
        if (_showDropdown && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(color: c.divider),
              boxShadow: [
                BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
              itemBuilder: (context, i) {
                final drug = _searchResults[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectDrug(drug),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.medication,
                              color: c.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                drug.displayName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary),
                              ),
                              if (drug.genericName.isNotEmpty &&
                                  drug.genericName != drug.displayName ||
                                  drug.dosageForm.isNotEmpty ||
                                  drug.strength.isNotEmpty)
                                Text(
                                  [
                                    if (drug.genericName.isNotEmpty &&
                                        drug.genericName != drug.displayName)
                                      drug.genericName,
                                    if (drug.dosageForm.isNotEmpty)
                                      drug.dosageForm,
                                    if (drug.strength.isNotEmpty)
                                      drug.strength,
                                  ].join(' • '),
                                  style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: c.textSecondary, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Hint shown when user types 1 char
        if (_nameController.text.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Type at least 2 characters to search…',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.textPrimary)),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, bool isStart) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickDate(isStart),
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: c.divider),
              borderRadius: BorderRadius.circular(_borderRadius),
              color: c.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(date),
                    style: TextStyle(
                        fontSize: 15, color: c.textPrimary)),
                Icon(Icons.calendar_today,
                    size: 18, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
