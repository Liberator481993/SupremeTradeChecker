import 'trade_line.dart';

enum TradeVerdict { win, fair, lose, unknown, empty }

class TradeResult {
  const TradeResult({
    required this.offerTotal,
    required this.receiveTotal,
    required this.difference,
    required this.percentDifference,
    required this.hasUnknownData,
    required this.verdict,
  });

  final double? offerTotal;
  final double? receiveTotal;
  final double? difference;
  final double? percentDifference;
  final bool hasUnknownData;
  final TradeVerdict verdict;

  static TradeResult calculate({
    required List<TradeLine> offer,
    required List<TradeLine> receive,
    double tolerancePercent = 5,
  }) {
    if (offer.isEmpty || receive.isEmpty) {
      return const TradeResult(
        offerTotal: null,
        receiveTotal: null,
        difference: null,
        percentDifference: null,
        hasUnknownData: false,
        verdict: TradeVerdict.empty,
      );
    }

    final allLines = [...offer, ...receive];
    final hasUnknown =
        allLines.any((line) => line.hasUnknownValue || line.quantity <= 0);

    if (hasUnknown) {
      return const TradeResult(
        offerTotal: null,
        receiveTotal: null,
        difference: null,
        percentDifference: null,
        hasUnknownData: true,
        verdict: TradeVerdict.unknown,
      );
    }

    final offerTotal = offer.fold<double>(
      0,
      (sum, line) => sum + line.subtotal!,
    );
    final receiveTotal = receive.fold<double>(
      0,
      (sum, line) => sum + line.subtotal!,
    );
    final difference = receiveTotal - offerTotal;
    final percent = offerTotal == 0 ? null : difference / offerTotal * 100;

    final verdict = percent == null
        ? TradeVerdict.unknown
        : percent >= tolerancePercent
            ? TradeVerdict.win
            : percent <= -tolerancePercent
                ? TradeVerdict.lose
                : TradeVerdict.fair;

    return TradeResult(
      offerTotal: offerTotal,
      receiveTotal: receiveTotal,
      difference: difference,
      percentDifference: percent,
      hasUnknownData: percent == null,
      verdict: verdict,
    );
  }

  String get label {
    switch (verdict) {
      case TradeVerdict.win:
        return 'WIN';
      case TradeVerdict.fair:
        return 'FAIR';
      case TradeVerdict.lose:
        return 'LOSE';
      case TradeVerdict.unknown:
        return 'UNKNOWN DATA';
      case TradeVerdict.empty:
        return 'ADD ITEMS';
    }
  }
}
