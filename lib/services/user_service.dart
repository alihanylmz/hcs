import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart'; // Hem UserProfile hem UserRole buradan gelir

class UserService {
  UserService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Geçerli (auth olmuş) kullanıcının profil kaydını çeker.
  /// - Profil bulunamazsa: null döner (ghost profile yok!)
  /// - Hata olursa: log yazar ve null döner.
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        developer.log(
          '⚠️ Profil bulunamadı (profiles tablosunda kayıt yok).',
          name: 'UserService.getCurrentUserProfile',
        );
        return null;
      }

      return UserProfile.fromJson(data as Map<String, dynamic>);
    } catch (e, st) {
      developer.log(
        '🔴 Profil çekme hatası',
        name: 'UserService.getCurrentUserProfile',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Stok silme yetkisi – business rule.
  /// Kullanıcı admin veya manager ise true.
  bool canDeleteStock(UserProfile? profile) {
    if (profile == null) return false;
    return profile.isAdmin == true || profile.isManager == true;
  }

  /// Manuel profil oluşturma (normalde Supabase trigger'ı yapar).
  Future<void> createProfile(
    String userId,
    String email,
    String? fullName,
  ) async {
    try {
      await _client.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': UserRole.pending,
      });
    } catch (e, st) {
      developer.log(
        '🔴 Profil oluşturma hatası',
        name: 'UserService.createProfile',
        error: e,
        stackTrace: st,
      );
      rethrow; // UI bilsin istersek
    }
  }

  /// Profil güncelleme (şimdilik sadece isim).
  Future<void> updateProfile(
    String userId, {
    String? fullName,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({'full_name': fullName}).eq('id', userId);
    } catch (e, st) {
      developer.log(
        '🔴 Profil güncelleme hatası',
        name: 'UserService.updateProfile',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Tüm kullanıcıları listele (alfabetik).
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('*')
          .order('full_name', ascending: true);

      return rows
          .map((row) => UserProfile.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      developer.log(
        '🔴 Kullanıcı listesi çekme hatası',
        name: 'UserService.getAllUsers',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Kullanıcı rolünü güncelle.
  /// - Başarılı: true
  /// - Hata: false (UI snackbar vs. gösterebilir)
  Future<bool> updateUserRole(
    String userId,
    String newRole, {
    int? partnerId,
  }) async {
    try {
      final data = <String, dynamic>{
        'role': newRole,
        'partner_id': newRole == UserRole.partnerUser ? partnerId : null,
      };

      await _client.from('profiles').update(data).eq('id', userId);
      return true;
    } catch (e, st) {
      developer.log(
        '🔴 Rol güncelleme hatası',
        name: 'UserService.updateUserRole',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
