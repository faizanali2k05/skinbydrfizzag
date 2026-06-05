import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/procedure_model.dart';

/// Procedure service backed by Supabase `procedures` table
class ProcedureService {
  final _supabase = Supabase.instance.client;

  // ==================== Real-time Streams ======================

  Stream<List<ProcedureModel>> getAllProceduresStream() {
    return _supabase
        .from('procedures')
        .stream(primaryKey: ['id'])
        .order('title', ascending: true)
        .map((event) {
      return event
          .map((e) => ProcedureModel.fromMap(e, e['id'] as String))
          .toList();
    });
  }

  // ==================== Single Fetches ======================

  Future<List<ProcedureModel>> getAllProcedures() async {
    try {
      final List<dynamic> data = await _supabase
          .from('procedures')
          .select()
          .order('title', ascending: true);
      return data
          .map((e) => ProcedureModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ProcedureModel?> getProcedureById(String procedureId) async {
    try {
      final data = await _supabase
          .from('procedures')
          .select()
          .eq('id', procedureId)
          .single();
      return ProcedureModel.fromMap(data, data['id'] as String);
    } catch (e) {
      return null;
    }
  }

  Future<List<ProcedureModel>> searchProcedures(String query) async {
    if (query.isEmpty) return getAllProcedures();
    try {
      final List<dynamic> data = await _supabase
          .from('procedures')
          .select()
          .ilike('title', '%$query%');
      return data
          .map((e) => ProcedureModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== Admin: Create/Update/Delete ======================

  Future<String?> createProcedure({
    required String title,
    required String description,
    required int duration,
    required double price,
    String? category,
    int? sessions,
    int? visitsPerSession,
    List<String>? keyFeatures,
    String? imageUrl,
  }) async {
    if (title.trim().isEmpty) return 'Procedure title is required.';
    if (description.trim().isEmpty) return 'Description is required.';
    if (duration <= 0) return 'Duration must be greater than 0.';
    if (price < 0) return 'Price cannot be negative.';
    try {
      await _supabase.from('procedures').insert({
        'title': title.trim(),
        'description': description.trim(),
        'duration': duration,
        'price': price,
        'category': category ?? 'GENERAL',
        'sessions': sessions ?? 1,
        'visits_per_session': visitsPerSession ?? 1,
        'key_features': keyFeatures ?? [],
        'image_url': imageUrl ?? '',
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateProcedure(
    String procedureId, {
    String? title,
    String? description,
    int? duration,
    double? price,
    String? category,
    int? sessions,
    int? visitsPerSession,
    List<String>? keyFeatures,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      updates['title'] = title.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      updates['description'] = description.trim();
    }
    if (duration != null && duration > 0) {
      updates['duration'] = duration;
    }
    if (price != null && price >= 0) {
      updates['price'] = price;
    }
    if (category != null) {
      updates['category'] = category;
    }
    if (sessions != null) {
      updates['sessions'] = sessions;
    }
    if (visitsPerSession != null) {
      updates['visits_per_session'] = visitsPerSession;
    }
    if (keyFeatures != null) {
      updates['key_features'] = keyFeatures;
    }
    if (imageUrl != null) {
      updates['image_url'] = imageUrl;
    }

    if (updates.isEmpty) {
      return 'No fields to update.';
    }
    try {
      await _supabase
          .from('procedures')
          .update(updates)
          .eq('id', procedureId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteProcedure(String procedureId) async {
    try {
      await _supabase
          .from('procedures')
          .delete()
          .eq('id', procedureId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== Utility Methods ======================

  Future<List<ProcedureModel>> getProceduresByDuration(int maxDuration) async {
    final all = await getAllProcedures();
    return all.where((p) => p.duration <= maxDuration).toList();
  }

  Future<List<ProcedureModel>> getProceduresByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    final all = await getAllProcedures();
    return all
        .where((p) => p.price >= minPrice && p.price <= maxPrice)
        .toList();
  }
}
