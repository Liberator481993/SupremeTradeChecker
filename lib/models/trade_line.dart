import 'catalog_item.dart';

class TradeLine {
  TradeLine({
    required this.key,
    required this.inputName,
    required this.quantity,
    this.item,
  });

  final String key;
  final String inputName;
  final int quantity;
  final CatalogItem? item;

  TradeLine copyWith({int? quantity, CatalogItem? item}) {
    return TradeLine(
      key: key,
      inputName: inputName,
      quantity: quantity ?? this.quantity,
      item: item ?? this.item,
    );
  }

  double? get subtotal {
    final unitValue = item?.value;
    if (unitValue == null || quantity <= 0) return null;
    return unitValue * quantity;
  }

  bool get hasUnknownValue => item == null || item!.value == null;
}
