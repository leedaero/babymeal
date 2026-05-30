// lib/features/schedule/meal_model.dart

class MealIngredient {
  final int ingredientId;
  final int grams;
  final String name;
  final String emoji;
  const MealIngredient({
    required this.ingredientId,
    required this.grams,
    required this.name,
    required this.emoji,
  });
  factory MealIngredient.fromJson(Map<String, dynamic> j) => MealIngredient(
        ingredientId: j['ingredient_id'],
        grams: j['grams'] ?? 0,
        name: j['name'] ?? '',
        emoji: j['emoji'] ?? '',
      );
}

class Meal {
  final int id;
  final String date;
  final String mealTime;
  final String status;
  final String note;
  final List<MealIngredient> ingredients;

  const Meal({
    required this.id,
    required this.date,
    required this.mealTime,
    required this.status,
    required this.note,
    required this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'],
        date: j['date'] ?? '',
        mealTime: j['meal_time'] ?? '',
        status: j['status'] ?? 'upcoming',
        note: j['note'] ?? '',
        ingredients: (j['ingredients'] as List? ?? [])
            .map((i) => MealIngredient.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  static const mealTimeKo = {
    'morning': '아침',
    'morning_snack': '오전간식',
    'lunch': '점심',
    'snack': '오후간식',
    'dinner': '저녁',
    'tried': '알러지 테스트',
  };

  static const statusColor = {
    'confirmed': 0xFF1565C0,
    'upcoming': 0xFFF9A825,
    'skipped': 0xFFC62828,
    'auto-consumed': 0xFF1565C0,
  };

  String get mealTimeKoStr => mealTimeKo[mealTime] ?? mealTime;
  int get statusColorInt => statusColor[status] ?? 0xFF9E9E9E;
}
