// lib/features/schedule/meal_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'meal_model.dart';

final mealsProvider = FutureProvider<List<Meal>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/meals');
  return (resp.data as List)
      .map((j) => Meal.fromJson(j as Map<String, dynamic>))
      .toList();
});

class MealActions {
  static Future<Meal> add(Map<String, dynamic> data) async {
    final resp = await ApiClient.instance.dio.post('/api/meals', data: data);
    return Meal.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Meal> updateStatus(int id, String status,
      {List<int>? consumedIds}) async {
    final resp = await ApiClient.instance.dio.post(
      '/api/meals/$id/status',
      data: {
        'status': status,
        'consumed_ids': consumedIds,
      },
    );
    return Meal.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/meals/$id');
  }
}
