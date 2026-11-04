import 'package:flutter_test/flutter_test.dart';
import 'package:supreme_trade_checker/models/catalog_item.dart';
import 'package:supreme_trade_checker/models/trade_line.dart';
import 'package:supreme_trade_checker/models/trade_result.dart';

void main() {
  const commonKnife = CatalogItem(
    id: 'godlies:sample',
    name: 'Sample Knife',
    category: 'godlies',
    value: 100,
  );
  const rareKnife = CatalogItem(
    id: 'godlies:sample-rare',
    name: 'Sample Rare Knife',
    category: 'godlies',
    value: 106,
  );

  TradeLine line(CatalogItem? item, String name, {int quantity = 1}) {
    return TradeLine(
      key: name,
      inputName: name,
      item: item,
      quantity: quantity,
    );
  }

  test('returns WIN when receive side is at least 5% higher', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name)],
      receive: [line(rareKnife, rareKnife.name)],
    );
    expect(result.verdict, TradeVerdict.win);
    expect(result.difference, 6);
  });

  test('returns FAIR when difference is inside tolerance', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name)],
      receive: [
        line(
          const CatalogItem(
            id: 'godlies:near',
            name: 'Near Value',
            category: 'godlies',
            value: 103,
          ),
          'Near Value',
        ),
      ],
    );
    expect(result.verdict, TradeVerdict.fair);
  });

  test('returns LOSE at the negative 5% boundary', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name)],
      receive: [
        line(
          const CatalogItem(
            id: 'godlies:low',
            name: 'Low Value',
            category: 'godlies',
            value: 95,
          ),
          'Low Value',
        ),
      ],
    );
    expect(result.verdict, TradeVerdict.lose);
  });

  test('quantity is included in the total', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name, quantity: 3)],
      receive: [line(rareKnife, rareKnife.name, quantity: 3)],
    );
    expect(result.offerTotal, 300);
    expect(result.receiveTotal, 318);
  });

  test('unknown items prevent a verdict and are never treated as zero', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name)],
      receive: [line(null, 'Unmatched Item')],
    );
    expect(result.verdict, TradeVerdict.unknown);
    expect(result.offerTotal, isNull);
    expect(result.receiveTotal, isNull);
  });

  test('a missing side asks for more items', () {
    final result = TradeResult.calculate(
      offer: [line(commonKnife, commonKnife.name)],
      receive: const [],
    );
    expect(result.verdict, TradeVerdict.empty);
  });
}
