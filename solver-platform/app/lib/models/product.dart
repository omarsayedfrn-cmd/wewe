/// Product model matching `products` DB table (coin packages).
class Product {
  final String id;
  final String name;
  final int coins;
  final double price;
  final bool active;
  final int sort;

  const Product({
    required this.id,
    required this.name,
    required this.coins,
    required this.price,
    this.active = true,
    this.sort = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        coins: json['coins'] as int,
        price: (json['price'] as num).toDouble(),
        active: json['active'] as bool? ?? true,
        sort: json['sort'] as int? ?? 0,
      );
}

/// Pricing model matching `pricing` DB table.
class Pricing {
  final String engineCode;
  final String kind; // 'full' | 'chapter'
  final int cost;

  const Pricing({
    required this.engineCode,
    required this.kind,
    required this.cost,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) => Pricing(
        engineCode: json['engine_code'] as String,
        kind: json['kind'] as String,
        cost: json['cost'] as int,
      );
}
