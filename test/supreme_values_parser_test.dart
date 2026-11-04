import 'package:flutter_test/flutter_test.dart';
import 'package:supreme_trade_checker/data/supreme_values_parser.dart';

void main() {
  test('parses a normal item row and source update label', () {
    const html = '''
      <html><body>
        <div>Values Last Updated - November 2nd, 2026 at 12:34 PM // Discord</div>
        <div>Image: Traveler's Gun | Traveler's Gun Value - 5,200
          Range - [N/A] Stability - Stable Demand - 5 Rarity - 5
          Origin - Halloween 2023 (Unboxed) Change in Value - (-100)
        </div>
      </body></html>
    ''';

    final parsed = SupremeValuesParser.parse(html, 'godlies');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.name, "Traveler's Gun");
    expect(parsed.items.single.value, 5200);
    expect(parsed.items.single.demand, 5);
    expect(parsed.items.single.rarity, 5);
    expect(parsed.items.single.origin, 'Halloween 2023 (Unboxed)');
    expect(parsed.sourceUpdatedLabel, 'November 2nd, 2026 at 12:34 PM');
  });

  test('extracts the set name before the Contains field', () {
    const html = '''
      <html><body>
        <div>Image: Traveler's Set | Traveler's Set Contains - Traveler's Axe,
          Traveler's Gun Value - 12,700 Range - [12,600 - 12,700]
          Stability - Underpaid For Demand - 5Rarity - 5
        </div>
      </body></html>
    ''';

    final parsed = SupremeValuesParser.parse(html, 'sets');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.name, "Traveler's Set");
    expect(parsed.items.single.value, 12700);
    expect(parsed.items.single.rangeMin, 12600);
    expect(parsed.items.single.rangeMax, 12700);
  });

  test('keeps non-numeric list values as unknown instead of zero', () {
    const html = '''
      <html><body>
        <div>Image: Tier Token | Tier Token Value - x3 T1 Commons
          Range - [N/A] Stability - Stable Demand - 2 Rarity - 3
        </div>
      </body></html>
    ''';

    final parsed = SupremeValuesParser.parse(html, 'misc');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.value, isNull);
  });

  test('imports untradables as catalogue entries with no invented price', () {
    const html = '''
      <html><body>
        <div>Image: Abduction | Abduction Rarity - 3
          Description - Surrounds Knife in a Tractor Beam
          Death Effect - N/A Origin - Halloween 2025 (Tier 24)
        </div>
        <div>Image: Cauldron | Cauldron Rarity - Coming Soon!
          Description - Gives Knife Green Bubble Particles
          Death Effect - N/A Origin - Halloween 2026 (Tier 22)
        </div>
      </body></html>
    ''';

    final parsed = SupremeValuesParser.parse(html, 'untradables');
    expect(parsed.items, hasLength(2));
    expect(parsed.items.firstWhere((item) => item.name == 'Abduction').value,
        isNull);
    expect(parsed.items.firstWhere((item) => item.name == 'Abduction').rarity,
        3);
    expect(parsed.items.firstWhere((item) => item.name == 'Cauldron').rarity,
        isNull);
  });
}
