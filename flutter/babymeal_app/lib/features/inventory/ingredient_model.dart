// lib/features/inventory/ingredient_model.dart
class Ingredient {
  final int id;
  final String name;
  final String emoji;
  final String color;
  final String createdAt;
  final int totalCubes;
  final int currentCubes;
  final int? weightPerCube;
  final String unitType;
  final String? imageUrl;

  const Ingredient({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.createdAt,
    required this.totalCubes,
    required this.currentCubes,
    this.weightPerCube,
    required this.unitType,
    this.imageUrl,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'] ?? '',
        color: j['color'] ?? '#4BA3E3',
        createdAt: j['created_at'] ?? '',
        totalCubes: j['total_cubes'] ?? 0,
        currentCubes: j['current_cubes'] ?? 0,
        weightPerCube: j['weight_per_cube'],
        unitType: j['unit_type'] ?? 'weight',
        imageUrl: j['image_url'],
      );

  bool get isLowStock => currentCubes <= 3;

  bool get isExpired {
    if (createdAt.isEmpty) return false;
    try {
      final made = DateTime.parse(createdAt);
      return DateTime.now().difference(made).inDays > 90;
    } catch (_) {
      return false;
    }
  }
}
