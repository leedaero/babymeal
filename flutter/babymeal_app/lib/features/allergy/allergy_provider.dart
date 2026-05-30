// lib/features/allergy/allergy_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'allergy_model.dart';

final allergyProvider = FutureProvider<List<AllergyTest>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/allergy');
  return (resp.data as List)
      .map((j) => AllergyTest.fromJson(j as Map<String, dynamic>))
      .toList();
});

class AllergyActions {
  static Future<void> add(Map<String, dynamic> data) async {
    await ApiClient.instance.dio.post('/api/allergy', data: data);
  }

  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/allergy/$id', data: data);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/allergy/$id');
  }
}
