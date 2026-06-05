import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clinic_location_model.dart';

class ClinicLocationService {
  final _supabase = Supabase.instance.client;

  Stream<List<ClinicLocationModel>> getLocationsStream({
    bool activeOnly = false,
  }) {
    return _supabase
        .from('clinic_locations')
        .stream(primaryKey: ['id'])
        .order('sort_order', ascending: true)
        .map((rows) {
          final locations = rows
              .map((row) => ClinicLocationModel.fromMap(row, row['id']))
              .where((location) => !activeOnly || location.isActive)
              .toList();
          locations.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return locations;
        });
  }

  Future<List<ClinicLocationModel>> getLocations({
    bool activeOnly = false,
  }) async {
    try {
      final List<dynamic> rows = activeOnly
          ? await _supabase
                .from('clinic_locations')
                .select()
                .eq('is_active', true)
                .order('sort_order', ascending: true)
          : await _supabase
                .from('clinic_locations')
                .select()
                .order('sort_order', ascending: true);
      return rows
          .map((row) => ClinicLocationModel.fromMap(row, row['id']))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> upsertLocation(ClinicLocationModel location) async {
    if (location.name.trim().isEmpty) return 'Location name is required.';
    if (location.address.trim().isEmpty) return 'Address is required.';

    try {
      final data = location.toMap();
      if (location.id.isEmpty) {
        await _supabase.from('clinic_locations').insert(data);
      } else {
        await _supabase
            .from('clinic_locations')
            .update(data)
            .eq('id', location.id);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteLocation(String locationId) async {
    try {
      await _supabase.from('clinic_locations').delete().eq('id', locationId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
