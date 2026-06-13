import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine_model.dart';
import 'add_medicine_screen.dart';
import 'medicine_detail_screen.dart';
import 'scan_prescription_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  String _searchQuery = '';
  String _filter = 'All'; // All, Active, Completed

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, AppPageRoute(page: const AddMedicineScreen())),
        backgroundColor: c.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Blue Gradient Header ──
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.medication_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('My Medicines',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  InkWell(
                    onTap: () => Navigator.push(context, AppPageRoute(page: const ScanPrescriptionScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('Manage your prescriptions', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),

          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: c.textTertiary, size: 20),
                filled: true,
                fillColor: c.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Filter Chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: ['All', 'Active', 'Paused', 'Completed'].map((label) {
                final isSelected = _filter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label, style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : c.textSecondary,
                    )),
                    selected: isSelected,
                    selectedColor: c.primary,
                    backgroundColor: c.card,
                    side: BorderSide(color: isSelected ? c.primary : c.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Medicine List ──
          Expanded(
            child: Consumer<MedicineProvider>(
              builder: (context, provider, child) {
                // Apply filters
                var meds = provider.medicines.where((m) {
                  if (_searchQuery.isNotEmpty && !m.name.toLowerCase().contains(_searchQuery)) {
                    return false;
                  }
                  if (_filter == 'Active') return m.isActive;
                  if (_filter == 'Paused') return m.isPaused;
                  if (_filter == 'Completed') return m.isCompleted;
                  return true;
                }).toList();

                if (provider.medicines.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_outlined, size: 64, color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text('No medicines added yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                        const SizedBox(height: 6),
                        Text('Tap + to add a prescription.', style: TextStyle(color: c.textSecondary)),
                      ],
                    ),
                  );
                }

                if (meds.isEmpty) {
                  return Center(
                    child: Text('No ${_filter.toLowerCase()} medicines found',
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                  itemCount: meds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildMedicineCard(context, meds[index], provider, c);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine medicine, MedicineProvider provider, AppColors c) {
    final isPaused = medicine.isPaused;
    final isCompleted = !medicine.isActive && !isPaused;

    // Status badge config
    String statusText;
    Color statusColor;
    if (isCompleted) {
      statusText = 'Completed';
      statusColor = c.textTertiary;
    } else if (isPaused) {
      statusText = 'Paused';
      statusColor = c.warning;
    } else {
      statusText = 'Active';
      statusColor = c.success;
    }

    return Opacity(
      opacity: isPaused || isCompleted ? 0.65 : 1.0,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: c.card,
        shadowColor: c.shadow,
        child: InkWell(
          onTap: () => Navigator.push(context, AppPageRoute(page: MedicineDetailScreen(medicine: medicine))),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Medicine icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaused ? Icons.pause_circle_outline : Icons.medication_liquid,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Name + dosage/freq + timing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name | Status + Delete
                      Row(
                        children: [
                          Expanded(
                            child: Text(medicine.name,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(statusText,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showDeleteDialog(context, medicine, provider, c),
                            child: Icon(Icons.delete_outline, color: c.error, size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 2: Dosage + Frequency
                      Text('${medicine.dosage} • ${medicine.frequency}',
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      if (medicine.times.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        // Row 3: Times (on separate line to avoid overflow)
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 12, color: c.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                medicine.times.join(', '),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Medicine medicine, MedicineProvider provider, AppColors c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Medicine?'),
        content: Text('Remove ${medicine.name} from your list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (medicine.id != null) {
                provider.removeMedicine(medicine.id!);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${medicine.name} deleted'),
                  backgroundColor: c.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
