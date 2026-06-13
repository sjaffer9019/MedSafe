import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/medicine_model.dart';
import '../models/alert_model.dart';
import '../models/medicine_dose_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  // ── MEDICINES ─────────────────────────────────────────
  Future<List<Medicine>> getMedicines() async {
    final data = await _client
        .from('medicines')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((m) => Medicine.fromSupabase(m)).toList();
  }

  Future<int> insertMedicine(Medicine medicine) async {
    final response = await _client.from('medicines').insert({
      'user_id': _uid,
      'name': medicine.name,
      'type': medicine.type,
      'dosage': medicine.dosage,
      'frequency': medicine.frequency,
      'times': medicine.times,
      'start_date': medicine.startDate,
      'end_date': medicine.endDate,
      'notes': medicine.notes,
    }).select('id').single();
    return response['id'] as int;
  }

  Future<void> deleteMedicine(int id) async {
    await _client.from('medicines').delete().eq('id', id);
  }

  Future<void> updateMedicine(Medicine medicine) async {
    if (medicine.id == null) return;
    await _client.from('medicines').update({
      'name': medicine.name,
      'type': medicine.type,
      'dosage': medicine.dosage,
      'frequency': medicine.frequency,
      'times': medicine.times,
      'start_date': medicine.startDate,
      'end_date': medicine.endDate,
      'notes': medicine.notes,
    }).eq('id', medicine.id!);
  }

  // ── ADHERENCE ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdherenceRaw() async {
    final data = await _client
        .from('adherence')
        .select()
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getAdherenceLast7Days() async {
    final cutoff = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 7)));
    final data = await _client
        .from('adherence')
        .select()
        .gte('date', cutoff)
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> upsertAdherence(String date, int status) async {
    final existing = await _client
        .from('adherence')
        .select()
        .eq('user_id', _uid)
        .eq('date', date)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('adherence')
          .update({'status': status}).eq('id', existing['id']);
    } else {
      await _client.from('adherence').insert({
        'user_id': _uid,
        'date': date,
        'status': status,
      });
    }
  }

  // ── ALERTS ────────────────────────────────────────────
  Future<List<Alert>> getAlerts() async {
    final data = await _client
        .from('alerts')
        .select()
        .order('date', ascending: false);
    return (data as List).map((a) => Alert.fromMap(a)).toList();
  }

  Future<void> insertAlert({
    required String message,
    required String severity,
  }) async {
    await _client.from('alerts').insert({
      'user_id': _uid,
      'message': message,
      'severity': severity,
      'alert_type': 'info',
      'dose_status': 'pending',
    });
  }

  /// Insert a medicine reminder alert linked to a dose record.
  Future<void> insertReminderAlert({
    required int medicineId,
    required String medicineName,
    required String doseTime,
    required int doseId,
    required DateTime expiresAt,
  }) async {
    await _client.from('alerts').insert({
      'user_id': _uid,
      'message': 'Time to take $medicineName ($doseTime)',
      'severity': 'Medium',
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'dose_time': doseTime,
      'alert_type': 'reminder',
      'dose_id': doseId,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'dose_status': 'pending',
    });
  }

  /// Update the dose_status on a reminder alert by alert ID.
  Future<void> updateAlertDoseStatus(String alertId, String status) async {
    await _client.from('alerts').update({
      'dose_status': status,
    }).eq('id', alertId);
  }

  /// Update the dose_status on reminder alerts matching a dose ID.
  /// Used when marking doses from medicine detail screen.
  Future<void> updateAlertDoseStatusByDoseId(int doseId, String status) async {
    await _client.from('alerts').update({
      'dose_status': status,
    }).eq('dose_id', doseId).eq('user_id', _uid);
  }

  Future<void> deleteAlert(String id) async {
    await _client.from('alerts').delete().eq('id', id);
  }

  Future<void> clearAlerts() async {
    await _client.from('alerts').delete().eq('user_id', _uid);
  }

  // ── MEDICINE DOSES ────────────────────────────────────
  /// Create a new dose record (pending).
  Future<int> createDoseRecord({
    required int medicineId,
    required String scheduledDate,
    required String scheduledTime,
  }) async {
    final expiresAt =
        DateTime.now().toUtc().add(const Duration(hours: 12)).toIso8601String();

    // Use upsert to avoid duplicates
    final existing = await _client
        .from('medicine_doses')
        .select('id')
        .eq('user_id', _uid)
        .eq('medicine_id', medicineId)
        .eq('scheduled_date', scheduledDate)
        .eq('scheduled_time', scheduledTime)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as int;
    }

    final response = await _client.from('medicine_doses').insert({
      'user_id': _uid,
      'medicine_id': medicineId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': 'pending',
      'expires_at': expiresAt,
    }).select('id').single();

    return response['id'] as int;
  }

  /// Mark a dose as taken or missed.
  Future<void> updateDoseStatus(int doseId, String status) async {
    await _client.from('medicine_doses').update({
      'status': status,
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', doseId);
  }

  /// Get today's doses for the current user.
  Future<List<MedicineDose>> getTodayDoses() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await _client
        .from('medicine_doses')
        .select()
        .eq('user_id', _uid)
        .eq('scheduled_date', today)
        .order('scheduled_time', ascending: true);
    return (data as List).map((d) => MedicineDose.fromSupabase(d)).toList();
  }

  /// Get doses for a specific medicine in the last N days.
  Future<List<MedicineDose>> getDosesForMedicine(int medicineId,
      {int days = 7}) async {
    final cutoff = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: days)));
    final data = await _client
        .from('medicine_doses')
        .select()
        .eq('user_id', _uid)
        .eq('medicine_id', medicineId)
        .gte('scheduled_date', cutoff)
        .order('scheduled_date', ascending: false)
        .order('scheduled_time', ascending: false);
    return (data as List).map((d) => MedicineDose.fromSupabase(d)).toList();
  }

  /// Get all pending doses that have expired (past 12h window).
  Future<List<MedicineDose>> getExpiredPendingDoses() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = await _client
        .from('medicine_doses')
        .select()
        .eq('user_id', _uid)
        .eq('status', 'pending')
        .lt('expires_at', now);
    return (data as List).map((d) => MedicineDose.fromSupabase(d)).toList();
  }

  /// Batch auto-miss expired doses.
  Future<void> autoMissExpiredDoses() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('medicine_doses')
        .update({
          'status': 'missed',
          'responded_at': now,
        })
        .eq('user_id', _uid)
        .eq('status', 'pending')
        .lt('expires_at', now);

    // Also update corresponding alerts
    await _client
        .from('alerts')
        .update({'dose_status': 'missed'})
        .eq('user_id', _uid)
        .eq('alert_type', 'reminder')
        .eq('dose_status', 'pending')
        .lt('expires_at', now);
  }

  /// Get doses for last 7 days across all medicines (for dashboard).
  Future<List<MedicineDose>> getLast7DaysDoses() async {
    final cutoff = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 7)));
    final data = await _client
        .from('medicine_doses')
        .select()
        .eq('user_id', _uid)
        .gte('scheduled_date', cutoff)
        .order('scheduled_date', ascending: false);
    return (data as List).map((d) => MedicineDose.fromSupabase(d)).toList();
  }

  // ── PROFILE ───────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile() async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
  }

  Future<void> upsertProfile({
    required String name,
    required String phone,
  }) async {
    await _client.from('profiles').upsert({
      'id': _uid,
      'name': name,
      'phone': phone,
      'email': _client.auth.currentUser?.email ?? '',
    });
  }
}
