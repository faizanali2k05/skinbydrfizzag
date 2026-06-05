import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple service to manage the single `about_us` row in the database.
class AboutUsService {
  /// Fetches the current about‑us information. Returns null if not found.
  Future<Map<String, dynamic>?> getAboutUs() async {
    try {
      final data = await Supabase.instance.client
          .from('about_us')
          .select()
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Insert or update the about_us row. Any field that is null will be ignored.
  Future<String?> upsertAboutUs({
    String? description,
    String? email,
    String? phone,
    String? instagramUrl,
    String? facebookUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (description != null) updates['description'] = description;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (instagramUrl != null) updates['instagram_url'] = instagramUrl;
    if (facebookUrl != null) updates['facebook_url'] = facebookUrl;

    if (updates.isEmpty) return null;
    updates['id'] = 1;

    try {
      await Supabase.instance.client
          .from('about_us')
          .upsert(updates)
          .select()
          .maybeSingle();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
