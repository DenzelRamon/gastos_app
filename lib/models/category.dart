/// Categoría de gasto (1 categoría -> N gastos, 0..N presupuestos).
class Category {
  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? updatedAt,
    this.synced = false,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String id;
  final String name;
  final int colorValue;
  final DateTime updatedAt;
  final bool synced;

  Category copyWith({String? name, int? colorValue}) => Category(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': colorValue,
        'updated_at': updatedAt.toIso8601String(),
        'synced': synced ? 1 : 0,
        'deleted': 0,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        colorValue: m['color'] as int,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        synced: (m['synced'] as int) == 1,
      );
}
