import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/partner.dart';

class PartnerService {
  final _supabase = Supabase.instance.client;
  final String _table = 'partners';

  // Tüm partnerleri getir (Admin için)
  Future<List<Partner>> getAllPartners() async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .order('name', ascending: true);
      return (response as List).map((e) => Partner.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Partnerler yüklenirken hata: $e');
    }
  }

  // ID'ye göre Partner getir
  Future<Partner?> getPartnerById(int id) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return Partner.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Partner Ekle
  Future<void> addPartner(String name, {String? contactInfo, String? logoUrl}) async {
    await _supabase.from(_table).insert({
      'name': name,
      'contact_info': contactInfo,
      'logo_url': logoUrl,
    });
  }

  // Partner Güncelle
  Future<void> updatePartner(int id, Map<String, dynamic> data) async {
    await _supabase.from(_table).update(data).eq('id', id);
  }

  // Partner Sil
  Future<void> deletePartner(int id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  // --- PARTNER DASHBOARD SORGULARI ---

  // Partnerin İşlerini Getir (RLS zaten filtreler ama biz partner_id ile garantiye alalım)
  Future<List<Map<String, dynamic>>> getPartnerTickets(int partnerId) async {
    try {
      // İlişkili tablolarla birlikte çekmek gerekebilir ama şimdilik düz liste
      final response = await _supabase
          .from('tickets')
          .select()
          .eq('partner_id', partnerId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('İş listesi yüklenirken hata: $e');
    }
  }
  
  // İstatistikler
  Future<Map<String, int>> getPartnerStats(int partnerId) async {
    final activeCount = await _supabase
        .from('tickets')
        .select('id')
        .eq('partner_id', partnerId)
        .neq('status', 'completed')
        .count(CountOption.exact);
        
    final completedCount = await _supabase
        .from('tickets')
        .select('id')
        .eq('partner_id', partnerId)
        .eq('status', 'completed')
        .count(CountOption.exact);
        
    return {
      'active': activeCount.count,
      'completed': completedCount.count,
    };
  }
}

