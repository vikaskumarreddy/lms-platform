class MobileContentItem {
  final int id;
  final String section;
  final String itemType;
  final String title;
  final String subtitle;
  final String description;
  final String value;
  final String linkUrl;
  final String icon;
  final String color;
  final int orderIndex;
  final bool isActive;
  final String metadata;

  MobileContentItem({
    required this.id,
    required this.section,
    required this.itemType,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.value,
    required this.linkUrl,
    required this.icon,
    required this.color,
    required this.orderIndex,
    required this.isActive,
    required this.metadata,
  });

  factory MobileContentItem.fromJson(Map<String, dynamic> json) {
    return MobileContentItem(
      id: json['id'] ?? 0,
      section: json['section'] ?? '',
      itemType: json['itemType'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      value: json['value'] ?? '',
      linkUrl: json['linkUrl'] ?? '',
      icon: json['icon'] ?? '',
      color: json['color'] ?? '',
      orderIndex: json['orderIndex'] ?? 0,
      isActive: json['active'] ?? true,
      metadata: json['metadata'] ?? '',
    );
  }
}
