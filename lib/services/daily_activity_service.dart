import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_activity.dart';

class DailyActivityService {
  DailyActivityService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  bool _roleLoaded = false;
  bool _isPartnerUser = false;

  Future<bool> _checkIsPartnerUser() async {
    if (_roleLoaded) return _isPartnerUser;
    final user = _client.auth.currentUser;
    if (user == null) {
      _roleLoaded = true;
      _isPartnerUser = false;
      return false;
    }

    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = (data is Map<String, dynamic>) ? (data['role'] as String?) : null;
      _isPartnerUser = role == 'partner_user';
    } catch (_) {
      // Rol okunamazsa, erişimi kısıtlamadan devam et (log spam istemiyoruz).
      _isPartnerUser = false;
    } finally {
      _roleLoaded = true;
    }

    return _isPartnerUser;
  }

  Future<void> _ensureNotPartnerUser() async {
    if (await _checkIsPartnerUser()) {
      throw Exception('Bu işlem için yetkiniz yok.');
    }
  }

  /// Belirli bir tarihe ait aktiviteleri getirir.
  Future<List<DailyActivity>> getActivities(DateTime date, {String? userId}) async {
    // Partner kullanıcılar günlük plan verisi göremez
    if (await _checkIsPartnerUser()) return [];
    try {
      final targetUserId = userId ?? _client.auth.currentUser?.id;
      if (targetUserId == null) return [];

      final dateStr = date.toIso8601String().substring(0, 10); // YYYY-MM-DD

      final List<dynamic> data = await _client
          .from('daily_activities')
          .select('*')
          .eq('user_id', targetUserId)
          .eq('activity_date', dateStr)
          .order('created_at', ascending: true);

      return data
          .map((row) => DailyActivity.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      developer.log(
        '🔴 Aktiviteleri çekme hatası',
        name: 'DailyActivityService.getActivities',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Yeni aktivite ekler (Alt adımlarıyla birlikte).
  Future<void> addActivity({
    required String title,
    required DateTime date,
    String? targetUserId,
    List<ActivityStep> steps = const [],
  }) async {
    try {
      await _ensureNotPartnerUser();
      final myUserId = _client.auth.currentUser?.id;
      if (myUserId == null) throw Exception('Kullanıcı oturumu kapalı');

      final activityUserId = targetUserId ?? myUserId;

      await _client.from('daily_activities').insert({
        'user_id': activityUserId,
        'creator_id': myUserId,
        'title': title,
        'activity_date': date.toIso8601String().substring(0, 10),
        'is_completed': false,
        'steps': steps.map((s) => s.toJson()).toList(), // JSON Listesi
      });
    } catch (e, st) {
      developer.log(
        '🔴 Aktivite ekleme hatası',
        name: 'DailyActivityService.addActivity',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Aktivite durumunu günceller (Sadece ana is_completed alanı).
  /// [DailyActivity.progress] 1.0 ise otomatik is_completed: true yaparız,
  /// ama yine de manuel kontrol gerekebilir.
  Future<void> toggleCompletion(String activityId, bool isCompleted) async {
    try {
      await _ensureNotPartnerUser();
      await _client
          .from('daily_activities')
          .update({'is_completed': isCompleted}).eq('id', activityId);
    } catch (e, st) {
      developer.log(
        '🔴 Aktivite güncelleme hatası',
        name: 'DailyActivityService.toggleCompletion',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Alt adımları günceller (Komple steps listesini JSON olarak basar).
  Future<void> updateActivitySteps(String activityId, List<ActivityStep> steps) async {
    try {
      await _ensureNotPartnerUser();
      // Steps'in hepsi bitti mi?
      final allDone = steps.isNotEmpty && steps.every((s) => s.isCompleted);

      await _client.from('daily_activities').update({
        'steps': steps.map((s) => s.toJson()).toList(),
        // Otomatik olarak ana işi de bitir veya aç
        'is_completed': allDone, 
      }).eq('id', activityId);
    } catch (e, st) {
      developer.log(
        '🔴 Adım güncelleme hatası',
        name: 'DailyActivityService.updateActivitySteps',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Aktiviteyi siler.
  Future<void> deleteActivity(String activityId) async {
    try {
      await _ensureNotPartnerUser();
      await _client.from('daily_activities').delete().eq('id', activityId);
    } catch (e, st) {
      developer.log(
        '🔴 Aktivite silme hatası',
        name: 'DailyActivityService.deleteActivity',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// KPI puanını günceller.
  Future<void> updateKpiScore(String activityId, int? score) async {
    try {
      await _ensureNotPartnerUser();
      await _client
          .from('daily_activities')
          .update({'kpi_score': score}).eq('id', activityId);
    } catch (e, st) {
      developer.log(
        '🔴 KPI puanı güncelleme hatası',
        name: 'DailyActivityService.updateKpiScore',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Geçmişte tamamlanmamış aktivitelerin sayısını getirir.
  Future<int> getPendingPastActivitiesCount() async {
    // Partner kullanıcılar günlük plan verisi göremez
    if (await _checkIsPartnerUser()) return 0;
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0;

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final response = await _client
          .from('daily_activities')
          .select('id')
          .eq('user_id', user.id)
          .lt('activity_date', todayStr)
          .eq('is_completed', false)
          .count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Tamamlanmamış aktiviteleri bugüne (veya hedef tarihe) taşır.
  /// Geriye taşınan kayıt sayısını döner.
  Future<int> moveIncompleteActivities({
    required DateTime fromDate, // Hangi tarihten? (Genelde dün veya geçmiş)
    required DateTime toDate,   // Hangi tarihe? (Genelde bugün)
    String? userId,
  }) async {
    // Partner kullanıcılar günlük plan verisi göremez / taşıma yapamaz
    if (await _checkIsPartnerUser()) return 0;
    try {
      final targetUserId = userId ?? _client.auth.currentUser?.id;
      if (targetUserId == null) return 0;

      final fromStr = fromDate.toIso8601String().substring(0, 10);
      final toStr = toDate.toIso8601String().substring(0, 10);

      // 1. Önce taşınacakları bul (Sadece ana iş tamamlanmamışsa)
      // Not: Supabase update işleminde count dönemeyebilir, o yüzden önce select yapıp sonra update etmek daha güvenli olabilir
      // veya update sonrası dönen data sayısına bakabiliriz.
      
      final List<dynamic> records = await _client
          .from('daily_activities')
          .select('id, title, activity_date, steps, user_id, creator_id') // Tüm gerekli alanları al
          .eq('user_id', targetUserId)
          .lt('activity_date', toStr) // Bugünden önceki her şey
          .eq('is_completed', false); // Sadece bitmeyenler

      if (records.isEmpty) return 0;

      int movedCount = 0;
      
      for (var record in records) {
        String oldTitle = record['title'] as String;
        String oldDateStr = record['activity_date'] as String;
        String oldDateDisplay = oldDateStr.substring(5, 10);
        
        try {
           final dt = DateTime.parse(oldDateStr);
           oldDateDisplay = "${dt.day}.${dt.month}";
        } catch (_) {}
        
        // --- 1. YENİ GÖREV OLUŞTUR (BUGÜNE) ---
        String newTitle = oldTitle;
        if (!newTitle.contains('[DEVİR]')) {
           newTitle = '[DEVİR] ($oldDateDisplay) $newTitle'; 
        }

        // Yeni görev ekle
        await _client.from('daily_activities').insert({
          'user_id': record['user_id'],
          'creator_id': record['creator_id'],
          'title': newTitle,
          'activity_date': toStr, // Bugüne
          'is_completed': false,
          'steps': record['steps'] ?? [], // Eski adımları koru
          // created_at otomatik oluşur
        });

        // --- 2. ESKİ GÖREVİ GÜNCELLE (İZ BIRAK) ---
        // Bugünün tarihini formatla (Örn: 22.05)
        String todayDisplay = "${toDate.day}.${toDate.month}";
        
        // Eski başlığı güncelle: "➡️ (22.5'e Devredildi) Eski Başlık"
        String traceTitle = "➡️ ($todayDisplay'e Devredildi) $oldTitle";
        traceTitle = "($todayDisplay'e Devredildi) $oldTitle";

        await _client
          .from('daily_activities')
          .update({
            'title': traceTitle,
            'is_completed': true // Artık tamamlandı (devredildi) sayılsın
          })
          .eq('id', record['id']);
          
        movedCount++;
      }

      return movedCount;
    } catch (e, st) {
      developer.log(
        '🔴 Aktivite taşıma hatası',
        name: 'DailyActivityService.moveIncompleteActivities',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }
}
