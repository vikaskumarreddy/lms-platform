class SubscriptionPlanModel {
  final int id;
  final String name;
  final double price;
  final String period;
  final String description;
  final List<String> features;
  final String color;
  final bool isPopular;
  final bool isActive;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    this.description = '',
    this.features = const [],
    this.color = '#0F172A',
    this.isPopular = false,
    this.isActive = true,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    // features comes as TEXT - could be newline-separated or comma-separated
    final rawFeatures = json['features'] ?? '';
    final List<String> parsedFeatures = rawFeatures
        .toString()
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return SubscriptionPlanModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      period: json['period'] ?? '/month',
      description: json['description'] ?? '',
      features: parsedFeatures,
      color: json['color'] ?? '#0F172A',
      isPopular: json['isPopular'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'period': period,
      'description': description,
      'features': features.join('\n'),
      'color': color,
      'isPopular': isPopular,
      'isActive': isActive,
    };
  }
}
