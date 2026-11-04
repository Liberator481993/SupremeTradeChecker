import 'package:flutter/material.dart';

import 'data/catalog_repository.dart';
import 'models/catalog_item.dart';
import 'models/trade_line.dart';
import 'models/trade_result.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SupremeTradeCheckerApp());
}

class SupremeTradeCheckerApp extends StatelessWidget {
  const SupremeTradeCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF9B83FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Supreme Trade Checker',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF111522),
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF131A29),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0C1220),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF273148)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF273148)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seed, width: 1.5),
          ),
        ),
      ),
      home: const TradeHomeScreen(),
    );
  }
}

class TradeHomeScreen extends StatefulWidget {
  const TradeHomeScreen({super.key});

  @override
  State<TradeHomeScreen> createState() => _TradeHomeScreenState();
}

class _TradeHomeScreenState extends State<TradeHomeScreen> {
  final CatalogRepository _repository = CatalogRepository();
  List<CatalogItem> _catalog = const [];
  List<TradeLine> _offer = [];
  List<TradeLine> _receive = [];
  String? _lastFetchedAt;
  String? _sourceUpdatedLabel;
  bool _loading = true;
  bool _refreshing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    try {
      final results = await Future.wait<Object?>([
        _repository.loadItems(),
        _repository.lastFetchedAt(),
        _repository.sourceUpdatedLabel(),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<CatalogItem>;
        _lastFetchedAt = results[1] as String?;
        _sourceUpdatedLabel = results[2] as String?;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _refreshCatalog() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _loadError = null;
    });

    try {
      final report = await _repository.refresh();
      final items = await _repository.loadItems();
      if (!mounted) return;
      setState(() {
        _catalog = items;
        _lastFetchedAt = report.fetchedAt.toIso8601String();
        _sourceUpdatedLabel = report.sourceUpdatedLabel;
        _refreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated: ${report.itemCount} items across ${report.categoryCount} categories.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update rejected. Saved data kept. $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  TradeResult get _result => TradeResult.calculate(
        offer: _offer,
        receive: _receive,
        tolerancePercent: 5,
      );

  void _setOffer(List<TradeLine> value) {
    setState(() => _offer = value);
  }

  void _setReceive(List<TradeLine> value) {
    setState(() => _receive = value);
  }

  void _clearTrade() {
    setState(() {
      _offer = [];
      _receive = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUPREME TRADE CHECKER',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'MM2 • Offline calculator',
              style: TextStyle(
                color: Color(0xFF8E9AB1),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear trade',
            onPressed: _clearTrade,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              children: [
                _catalogStatusCard(),
                const SizedBox(height: 14),
                TradeSideEditor(
                  title: 'YOUR OFFER',
                  subtitle: 'Items you are giving',
                  accent: const Color(0xFF69C9F5),
                  lines: _offer,
                  onChanged: _setOffer,
                  search: (query) =>
                      _repository.search(_catalog, query, limit: 6),
                  exactMatches: (query) =>
                      _repository.exactMatches(_catalog, query),
                ),
                const SizedBox(height: 14),
                TradeSideEditor(
                  title: 'YOU RECEIVE',
                  subtitle: 'Items you are getting',
                  accent: const Color(0xFFB69BFF),
                  lines: _receive,
                  onChanged: _setReceive,
                  search: (query) =>
                      _repository.search(_catalog, query, limit: 6),
                  exactMatches: (query) =>
                      _repository.exactMatches(_catalog, query),
                ),
                const SizedBox(height: 14),
                _resultCard(result),
                const SizedBox(height: 14),
                _sourceNote(),
              ],
            ),
    );
  }

  Widget _catalogStatusCard() {
    final hasCatalog = _catalog.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B83FF).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storage_rounded,
                    color: Color(0xFFBCA9FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCAL VALUE DATABASE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasCatalog
                            ? '${_catalog.length} items saved on this device'
                            : 'No local catalogue yet',
                        style: const TextStyle(
                          color: Color(0xFF9AA7BF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCatalog)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF70D6AB),
                    size: 20,
                  ),
              ],
            ),
            if (_lastFetchedAt != null) ...[
              const SizedBox(height: 12),
              _metadataLine('Downloaded', _formatDate(_lastFetchedAt)),
            ],
            if (_sourceUpdatedLabel != null &&
                _sourceUpdatedLabel!.isNotEmpty) ...[
              const SizedBox(height: 5),
              _metadataLine('Source update', _sourceUpdatedLabel!),
            ],
            if (_loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: const TextStyle(color: Color(0xFFFF9B9B), fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _refreshing ? null : _refreshCatalog,
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _refreshing ? 'Updating catalogue…' : 'Update database',
                ),
              ),
            ),
            if (!hasCatalog) ...[
              const SizedBox(height: 7),
              const Text(
                'Connect to the internet and update once. The saved catalogue can then be used offline.',
                style: TextStyle(
                  color: Color(0xFF8794AC),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metadataLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF76839B), fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFFC6D0E1), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _resultCard(TradeResult result) {
    final Color verdictColor;
    switch (result.verdict) {
      case TradeVerdict.win:
        verdictColor = const Color(0xFF70D6AB);
        break;
      case TradeVerdict.fair:
        verdictColor = const Color(0xFF8DBBFF);
        break;
      case TradeVerdict.lose:
        verdictColor = const Color(0xFFFF8D97);
        break;
      case TradeVerdict.unknown:
        verdictColor = const Color(0xFFFFC56D);
        break;
      case TradeVerdict.empty:
        verdictColor = const Color(0xFF9AA7BF);
        break;
    }

    final offerValue = result.verdict == TradeVerdict.empty
        ? '—'
        : result.offerTotal == null
            ? 'UNKNOWN'
        : _formatValue(result.offerTotal!);
    final receiveValue = result.verdict == TradeVerdict.empty
        ? '—'
        : result.receiveTotal == null
            ? 'UNKNOWN'
        : _formatValue(result.receiveTotal!);
    final differenceValue = result.difference == null
        ? '—'
        : '${result.difference! >= 0 ? '+' : ''}${_formatValue(result.difference!.abs())}';
    final percentageValue = result.percentDifference == null
        ? '—'
        : '${result.percentDifference! >= 0 ? '+' : ''}${result.percentDifference!.toStringAsFixed(1)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRADE RESULT',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
              decoration: BoxDecoration(
                color: verdictColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: verdictColor.withOpacity(0.36)),
              ),
              child: Column(
                children: [
                  Text(
                    result.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: verdictColor,
                      fontSize: 22,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Default tolerance: ±5%',
                    style: TextStyle(color: Color(0xFF929FB7), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _totalTile('YOU GIVE', offerValue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _totalTile('YOU GET', receiveValue),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Divider(color: Color(0xFF263047), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _smallMetric('Difference', differenceValue)),
                Expanded(child: _smallMetric('Difference %', percentageValue)),
              ],
            ),
            if (result.verdict == TradeVerdict.unknown) ...[
              const SizedBox(height: 12),
              const Text(
                'At least one item is missing a reliable catalogue value or is not matched exactly. No WIN / FAIR / LOSE verdict is calculated.',
                style: TextStyle(
                  color: Color(0xFFFFC56D),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
            if (result.verdict == TradeVerdict.empty) ...[
              const SizedBox(height: 12),
              const Text(
                'Add at least one recognised item to both sides to calculate the trade.',
                style: TextStyle(
                  color: Color(0xFF929FB7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1220),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8794AC),
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _smallMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8794AC), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE1E8F4),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sourceNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Values are community estimates from Supreme Values, not official Roblox prices. The app is a manual calculator only; it does not connect to Roblox or perform trades.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF68758D),
          fontSize: 10,
          height: 1.45,
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return 'Not available';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d.$m.${date.year} $h:$min';
  }

  String _formatValue(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      buffer.write(rounded[i]);
      final remaining = rounded.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return buffer.toString();
  }
}

class TradeSideEditor extends StatefulWidget {
  const TradeSideEditor({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.lines,
    required this.onChanged,
    required this.search,
    required this.exactMatches,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final List<TradeLine> lines;
  final ValueChanged<List<TradeLine>> onChanged;
  final List<CatalogItem> Function(String query) search;
  final List<CatalogItem> Function(String query) exactMatches;

  @override
  State<TradeSideEditor> createState() => _TradeSideEditorState();
}

class _TradeSideEditorState extends State<TradeSideEditor> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  List<CatalogItem> _suggestions = const [];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _suggestions = widget.search(value));
  }

  void _addItem({CatalogItem? selected}) {
    final name = (selected?.name ?? _nameController.text).trim();
    if (name.isEmpty) return;

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity < 1 || quantity > 999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be between 1 and 999.')),
      );
      return;
    }

    CatalogItem? resolved = selected;
    if (resolved == null) {
      final matches = widget.exactMatches(name);
      if (matches.length == 1) resolved = matches.single;
    }

    final line = TradeLine(
      key: DateTime.now().microsecondsSinceEpoch.toString(),
      inputName: name,
      quantity: quantity,
      item: resolved,
    );
    widget.onChanged([...widget.lines, line]);
    _nameController.clear();
    _quantityController.text = '1';
    setState(() => _suggestions = const []);
  }

  void _removeLine(TradeLine line) {
    widget.onChanged(
      widget.lines.where((entry) => entry.key != line.key).toList(),
    );
  }

  void _changeQuantity(TradeLine line, int change) {
    final next = line.quantity + change;
    if (next < 1 || next > 999) return;
    widget.onChanged(
      widget.lines
          .map(
            (entry) => entry.key == line.key
                ? entry.copyWith(quantity: next)
                : entry,
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8996AE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.lines.length} items',
                  style: const TextStyle(
                    color: Color(0xFF9AA7BF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _addItem(),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Search item name',
                      prefixIcon: Icon(Icons.search_rounded),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 66,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF29344C)),
                ),
                child: Column(
                  children: _suggestions
                      .map(
                        (item) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            item.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            '${item.category.toUpperCase()} • ${item.value == null ? 'NO NUMERIC VALUE' : _price(item.value!)}',
                            style: const TextStyle(
                              color: Color(0xFF8996AE),
                              fontSize: 10,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            size: 19,
                          ),
                          onTap: () => _addItem(selected: item),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add item'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.accent,
                  side: BorderSide(color: widget.accent.withOpacity(0.38)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            if (widget.lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF263047), height: 1),
              const SizedBox(height: 5),
              ...widget.lines.map(_lineTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineTile(TradeLine line) {
    final known = !line.hasUnknownValue;
    final amount = line.subtotal;
    final itemLabel = line.item?.name ?? line.inputName;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  known ? 'Unit: ${_price(line.item!.value!)}' : 'UNKNOWN DATA',
                  style: TextStyle(
                    color: known
                        ? const Color(0xFF8996AE)
                        : const Color(0xFFFFC56D),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Decrease quantity',
            onPressed: () => _changeQuantity(line, -1),
            icon: const Icon(Icons.remove_circle_outline, size: 18),
          ),
          Text(
            line.quantity.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Increase quantity',
            onPressed: () => _changeQuantity(line, 1),
            icon: const Icon(Icons.add_circle_outline, size: 18),
          ),
          SizedBox(
            width: 70,
            child: Text(
              amount == null ? 'UNKNOWN' : _price(amount),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: known ? Colors.white : const Color(0xFFFFC56D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove item',
            onPressed: () => _removeLine(line),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF8996AE),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _price(double value) {
    final rounded = value.round().toString();
    final result = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      result.write(rounded[i]);
      final remaining = rounded.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) result.write(',');
    }
    return result.toString();
  }
}
