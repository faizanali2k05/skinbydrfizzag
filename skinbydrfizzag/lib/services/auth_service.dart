import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../constants/config.dart';

/// Authentication service backed by Supabase
class AuthService with ChangeNotifier {
  UserModel? _currentUser;
  StreamSubscription<AuthState>? _authSubscription;

  AuthService() {
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final session = data.session;
      if (session?.user != null) {
        _fetchProfile(session!.user.id);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Stream<UserModel?> get authStateChanges {
    return Supabase.instance.client.auth.onAuthStateChange.asyncMap((
      data,
    ) async {
      final user = data.session?.user;
      if (user != null) {
        return await _fetchProfile(user.id);
      }
      return null;
    });
  }

  UserModel? get currentUser => _currentUser;

  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  String? get currentUserEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  bool get isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  /// Creates a new user account. When called by a signed-in admin, this routes
  /// through the backend admin API so the admin's current session is preserved
  /// (otherwise Supabase signUp would replace it with the new user's session
  /// and break subsequent admin actions like changing the new user's password).
  ///
  /// [existingProfileId] lets the backend merge an existing WhatsApp-only
  /// profile into the new auth account so the user does not appear twice.
  Future<String?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? existingProfileId,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

      if (await isCurrentUserAdmin()) {
        final accessToken =
            Supabase.instance.client.auth.currentSession?.accessToken;
        if (accessToken == null) {
          return 'Admin session expired. Please sign in again.';
        }
        final response = await http.post(
          Uri.parse('${AppConfig.backendBaseUrl}/admin/create-user'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
            'full_name': name,
            'phone': cleanPhone,
            'existing_profile_id': existingProfileId,
          }),
        );

        if (response.statusCode == 200) {
          return null;
        }
        try {
          final data = jsonDecode(response.body);
          return data['error']?.toString() ?? 'Failed to create user';
        } catch (_) {
          return 'Failed to create user (HTTP ${response.statusCode})';
        }
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'phone': cleanPhone},
      );

      final userId = res.user?.id;
      if (userId == null) return 'Failed to create user account.';

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      if (res.user != null) {
        await _fetchProfile(res.user!.id);
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<UserModel?> _fetchProfile(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (res == null) {
        // Fallback or create profile if missing (though trigger should handle it)
        debugPrint('Profile not found for $uid, might be a sync delay.');
        return null;
      }

      _currentUser = UserModel.fromMap(res, uid);
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<UserModel?> getCurrentUserDocument() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    if (_currentUser != null && _currentUser!.uid == uid) return _currentUser;
    return await _fetchProfile(uid);
  }

  Future<UserModel?> getUserByUid(String uid) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data, uid);
    } catch (e) {
      debugPrint('Error getting user by UID: $e');
      return null;
    }
  }

  Future<String> getCurrentUserRole() async {
    if (_currentUser == null) {
      final doc = await getCurrentUserDocument();
      return doc?.role ?? 'user';
    }
    return _currentUser!.role;
  }

  Future<bool> isCurrentUserAdmin() async {
    return (await getCurrentUserRole()) == 'admin';
  }

  Future<String?> updateUserProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) return 'Not authenticated';
    final updates = <String, dynamic>{};
    if (name != null) updates['full_name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (photoUrl != null) updates['photo_url'] = photoUrl;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update(updates)
          .eq('id', uid);
      await _fetchProfile(uid);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Upload image to Supabase Storage
  Future<String?> uploadImage(String bucket, String path, dynamic file) async {
    try {
      if (file is File) {
        final bytes = await file.readAsBytes();
        await Supabase.instance.client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      } else {
        await Supabase.instance.client.storage
            .from(bucket)
            .upload(
              path,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      }

      final String publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint('AuthService: Error uploading image: $e');
      return null;
    }
  }

  Future<String?> setUserRole(String uid, String role) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': role})
          .eq('id', uid);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> getAdminId() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(1)
          .maybeSingle();
      return data?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Admin updates another user's password
  Future<String?> updateUserPassword(String userId, String newPassword) async {
    try {
      if (newPassword.isEmpty || newPassword.length < 6) {
        return 'Password must be at least 6 characters long';
      }

      debugPrint(
        'AuthService: Attempting to update password for user: $userId',
      );

      // Get current admin session token
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return 'Admin not logged in';
      }

      // Call backend endpoint instead of direct Supabase admin API
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/admin/update-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'user_id': userId,
          'new_password': newPassword,
          'admin_token': session.accessToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          debugPrint(
            'AuthService: Password updated successfully for user: $userId',
          );
          return null;
        } else {
          return data['error'] ?? 'Unknown error';
        }
      } else {
        final error = jsonDecode(response.body);
        debugPrint('AuthService: Password update failed: ${error['error']}');
        return error['error'] ?? 'Failed to update password';
      }
    } catch (e) {
      debugPrint('AuthService: Error updating password: $e');
      return 'Failed to update password: $e';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<UserModel?> getCurrentUserStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', currentUserId ?? '')
        .map(
          (data) => data.isNotEmpty
              ? UserModel.fromMap(data.first, data.first['id'])
              : null,
        );
  }

  Stream<List<UserModel>> getAllProfilesStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((event) {
          return event
              .map((e) => UserModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<String> getUserRole() async => getCurrentUserRole();
}
