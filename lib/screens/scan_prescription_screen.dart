import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../core/app_colors.dart';
import '../models/medicine_model.dart';
import '../providers/medicine_provider.dart';
import '../services/prescription_scanner_service.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  const ScanPrescriptionScreen({super.key});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final ImagePicker _picker = ImagePicker();

  // States: idle, scanning, results, error
  String _state = 'idle';
  String? _imagePath;
  List<ScannedMedicine> _medicines = [];
  String _errorMessage = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPickerSheet();
    });
  }

  // ── Image Picker Bottom Sheet ───────────────────────────────
  void _showPickerSheet() {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: c.divider, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Upload Prescription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text('Choose how to add your prescription',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      subtitle: 'Take a photo',
                      color: c.primary,
                      onTap: () {
                        setState(() => _state = 'picking');
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Choose existing',
                      color: c.accent,
                      onTap: () {
                        setState(() => _state = 'picking');
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (_state == 'idle' && mounted) {
        Navigator.pop(context);
      }
    });
  }

  Widget _pickerOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Pick Image ──────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      setState(() {
        _imagePath = image.path;
        _state = 'scanning';
      });

      await _scanPrescription();
    } catch (e) {
      debugPrint('Pick image error: $e');
      if (!mounted) return;
      setState(() {
        _state = 'error';
        _errorMessage = 'Failed to pick image.\n$e';
      });
    }
  }

  // ── Scan Prescription ───────────────────────────────────────
  Future<void> _scanPrescription() async {
    if (_imagePath == null) {
      setState(() {
        _state = 'error';
        _errorMessage = 'No image selected.';
      });
      return;
    }

    try {
      debugPrint('Starting prescription scan for: $_imagePath');

      final results = await PrescriptionScannerService.scanPrescription(
        _imagePath!,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('Scan timed out');
          return <ScannedMedicine>[];
        },
      );

      debugPrint('Scan complete: ${results.length} medicines found');

      if (!mounted) return;
      setState(() {
        _medicines = results;
        if (results.isEmpty) {
          _state = 'error';
          _errorMessage = 'No medicines found in this image.\nPlease try a clearer photo of the prescription.';
        } else {
          _state = 'results';
        }
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      if (!mounted) return;

      final msg = e.toString();
      String friendlyMsg;
      if (msg.contains('API_KEY') || msg.contains('403') || msg.contains('401')) {
        friendlyMsg = 'API authentication failed.\nPlease check the Gemini API key.';
      } else if (msg.contains('timeout') || msg.contains('SocketException') || msg.contains('Connection')) {
        friendlyMsg = 'Network error.\nPlease check your internet connection and try again.';
      } else if (msg.contains('404')) {
        friendlyMsg = 'AI model not available.\nPlease try again later.';
      } else {
        friendlyMsg = 'Scan failed. Please try again.\n\n${msg.length > 200 ? msg.substring(0, 200) : msg}';
      }

      setState(() {
        _state = 'error';
        _errorMessage = friendlyMsg;
      });
    }
  }

  // ── Save All Medicines ──────────────────────────────────────
  Future<void> _saveAllMedicines() async {
    final selected = _medicines.where((m) => m.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    final provider = context.read<MedicineProvider>();
    final now = DateTime.now();
    int savedCount = 0;

    try {
      for (final med in selected) {
        final medicine = Medicine(
          name: med.name,
          type: med.type,
          dosage: med.dosage,
          frequency: med.frequency,
          times: med.times,
          startDate: now.toIso8601String(),
          endDate: now.add(Duration(days: med.durationDays)).toIso8601String(),
        );
        await provider.addMedicine(medicine);
        savedCount++;
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $savedCount medicine${savedCount > 1 ? 's' : ''} added from prescription!'),
        backgroundColor: AppColors.of(context).success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: ${e.toString().split('\n').first}'),
        backgroundColor: AppColors.of(context).error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primaryDark, c.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan Prescription',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('AI-powered medicine extraction',
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                if (_state == 'results')
                  InkWell(
                    onTap: () {
                      setState(() => _state = 'idle');
                      _showPickerSheet();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(child: _buildBody(c)),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_state == 'scanning') return _buildScanningState(c);
    if (_state == 'results') return _buildResultsState(c);
    if (_state == 'error') return _buildErrorState(c);
    return const Center(child: CircularProgressIndicator());
  }

  // ── SCANNING STATE ──────────────────────────────────────────
  Widget _buildScanningState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple robust scanning animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Analyzing Prescription...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text('Gemini AI is reading your prescription',
                style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 8),
            Text('This may take 10-20 seconds',
                style: TextStyle(fontSize: 12, color: c.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ── RESULTS STATE ───────────────────────────────────────────
  Widget _buildResultsState(AppColors c) {
    final selectedCount = _medicines.where((m) => m.selected).length;

    return Column(
      children: [
        // Image preview strip
        if (_imagePath != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: c.surfaceVariant,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imagePath!), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.image, color: c.textTertiary, size: 32),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${_medicines.length} medicine${_medicines.length > 1 ? 's' : ''} found',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Medicine cards list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _medicines.length,
            itemBuilder: (context, index) => _buildMedicineCard(c, index),
          ),
        ),

        // Confirm button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: c.card,
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving || selectedCount == 0 ? null : _saveAllMedicines,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  disabledBackgroundColor: c.divider,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Add $selectedCount Medicine${selectedCount > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Medicine Card ───────────────────────────────────────────
  Widget _buildMedicineCard(AppColors c, int index) {
    final med = _medicines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: med.selected ? c.primary.withOpacity(0.3) : c.divider.withOpacity(0.5),
        ),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Opacity(
        opacity: med.selected ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: checkbox + name + edit + type
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => med.selected = !med.selected),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: med.selected ? c.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: med.selected ? c.primary : c.textTertiary, width: 2),
                      ),
                      child: med.selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(med.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => _showEditSheet(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_outlined, size: 16, color: c.warning),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(med.type,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Details
              Wrap(
                spacing: 8, runSpacing: 6,
                children: [
                  _detailChip(c, Icons.science_outlined, med.dosage),
                  _detailChip(c, Icons.repeat, med.frequency),
                  _detailChip(c, Icons.calendar_today, '${med.durationDays} days'),
                ],
              ),
              const SizedBox(height: 8),

              // Times
              Wrap(
                spacing: 6,
                children: med.times.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 12, color: c.success),
                      const SizedBox(width: 4),
                      Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.success)),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(AppColors c, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textSecondary)),
        ],
      ),
    );
  }

  // ── Edit Bottom Sheet ───────────────────────────────────────
  void _showEditSheet(int index) {
    final med = _medicines[index];
    final c = AppColors.of(context);

    final nameCtrl = TextEditingController(text: med.name);
    final dosageCtrl = TextEditingController(text: med.dosage);
    final durationCtrl = TextEditingController(text: med.durationDays.toString());
    String editType = med.type;
    String editFreq = med.frequency;
    List<String> editTimes = List.from(med.times);

    const types = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Inhaler', 'Drops', 'Topical', 'Patch'];
    const freqs = ['Once Daily', 'Twice Daily', 'Thrice Daily'];
    const defaultTimes = {
      'Once Daily': ['08:00 AM'],
      'Twice Daily': ['08:00 AM', '08:00 PM'],
      'Thrice Daily': ['08:00 AM', '02:00 PM', '08:00 PM'],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Edit Medicine',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 16),

                    _editField(c, 'Medicine Name', nameCtrl),
                    const SizedBox(height: 12),
                    _editField(c, 'Dosage (e.g. 500 mg)', dosageCtrl),
                    const SizedBox(height: 12),

                    // Type
                    Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: types.contains(editType) ? editType : 'Tablet',
                          isExpanded: true,
                          dropdownColor: c.card,
                          style: TextStyle(color: c.textPrimary, fontSize: 15),
                          items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setSheetState(() => editType = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Frequency
                    Text('Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: freqs.contains(editFreq) ? editFreq : 'Once Daily',
                          isExpanded: true,
                          dropdownColor: c.card,
                          style: TextStyle(color: c.textPrimary, fontSize: 15),
                          items: freqs.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) {
                            setSheetState(() {
                              editFreq = v!;
                              editTimes = List.from(defaultTimes[editFreq]!);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Times
                    Text('Times', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: editTimes.map((t) => Chip(
                        label: Text(t, style: TextStyle(fontSize: 13, color: c.primary)),
                        backgroundColor: c.primary.withOpacity(0.08),
                        side: BorderSide(color: c.primary.withOpacity(0.2)),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),

                    _editField(c, 'Duration (days)', durationCtrl, isNumber: true),
                    const SizedBox(height: 20),

                    // Save
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            med.name = nameCtrl.text.trim().isEmpty ? med.name : nameCtrl.text.trim();
                            med.dosage = dosageCtrl.text.trim();
                            med.type = editType;
                            med.frequency = editFreq;
                            med.times = editTimes;
                            med.durationDays = int.tryParse(durationCtrl.text.trim()) ?? med.durationDays;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Remove
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _medicines.removeAt(index));
                          Navigator.pop(ctx);
                          if (_medicines.isEmpty) {
                            setState(() {
                              _state = 'error';
                              _errorMessage = 'All medicines removed. Try scanning again.';
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.error,
                          side: BorderSide(color: c.error.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Remove Medicine',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(AppColors c, String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  // ── ERROR STATE ─────────────────────────────────────────────
  Widget _buildErrorState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: c.error, size: 48),
            ),
            const SizedBox(height: 24),
            Text('Scan Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _state = 'idle');
                  _showPickerSheet();
                },
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('Try Again',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
