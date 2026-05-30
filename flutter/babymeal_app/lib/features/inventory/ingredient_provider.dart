// lib/features/inventory/ingredient_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'ingredient_model.dart';

final ingredientsProvider = FutureProvider<List<Ingredient>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/ingredients');
  return (resp.data as List)
      .map((j) => Ingredient.fromJson(j as Map<String, dynamic>))
      .toList();
});

class IngredientActions {
  static Future<void> adjust(int id, int delta) async {
    await ApiClient.instance.dio.post(
      '/api/ingredients/$id/adjust',
      data: {'delta': delta},
    );
  }

  static Future<void> add(Map<String, dynamic> data) async {
    await ApiClient.instance.dio.post('/api/ingredients', data: data);
  }

  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/ingredients/$id', data: data);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/ingredients/$id');
  }

  static Future<List<Map<String, dynamic>>> logs(int id) async {
    final resp =
        await ApiClient.instance.dio.get('/api/ingredients/$id/logs');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }
}
