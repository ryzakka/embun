import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/asset_catalog.dart';
import '../../data/errors.dart';
import '../../data/game_repository.dart';
import '../common/art.dart';
import '../common/ornate.dart';
import 'card_tile.dart';
import 'day_chrome.dart';

/// Pasar Riset memiliki stok dan jatah terpisah dari Pasar Pagi.
/// Harga dan jatah dihitung oleh server.
class ResearchView extends StatefulWidget {
  final GameRepository repo;
  final String gameId;
  final int day;
  final Map<String, Map<String, dynamic>> defs;
  final double balance;
  final bool jailed;
  final bool iAmReady;
  final int readyCount;
  final int total;
  final bool dark;
  final VoidCallback? onBought;

  const ResearchView({
    super.key,
    required this.repo,
    required this.gameId,
    required this.day,
    required this.defs,
    required this.balance,
    required this.jailed,
    required this.iAmReady,
    required this.readyCount,
    required this.total,
    this.dark = false,
    this.onBought,
  });

  @override
  State<ResearchView> createState() => _ResearchViewState();
}

enum _Category {
  points('Kartu poin', 'poinplus1', 'Untuk mengaktifkan kartu lanjutan.'),
  advanced(
    'Kartu lanjutan',
    'plus',
    'Gabungkan dengan kartu poin di tab Gabung.',
  );

  const _Category(this.label, this.icon, this.hint);

  final String label;
  final String icon;
  final String hint;
}

enum _Action { buy, finish }

class _ResearchViewState extends State<ResearchView> {
  List<Map<String, dynamic>>? _items;
  int _limit = 2;
  int _bought = 0;
  String? _error;
  _Category _category = _Category.points;
  String? _selectedId;
  _Action? _action;
  bool _finished = false;

  Color get _accent => widget.dark ? EmbunColors.mist : EmbunColors.gold;
  String get _currency => widget.dark ? 'bulirhitam' : 'bulirembun';
  String get _currencyName => widget.dark ? 'Bulir hitam' : 'Embun';
  int get _left => (_limit - _bought).clamp(0, 99);
  bool get _ready => widget.iAmReady || _finished;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      final stock = await widget.repo.researchStock(widget.gameId);
      final items = (stock['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _limit = (stock['limit'] as num?)?.toInt() ?? 2;
        _bought = (stock['bought'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errMsg(error));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 72),
        ),
      );
  }

  String _id(Map<String, dynamic> item) => item['card_id'] as String;
  int _price(Map<String, dynamic> item) => (item['price'] as num).toInt();
  String _name(Map<String, dynamic> item) =>
      (widget.defs[_id(item)]?['name'] as String?) ?? _id(item);

  Map<String, dynamic>? _definition(Map<String, dynamic> item) {
    final definition = widget.defs[_id(item)];
    return definition == null ? null : {...definition, 'cost': _price(item)};
  }

  String? _blockReason(Map<String, dynamic> item) {
    if (item['bought'] == true) return 'Sudah dibeli';
    if (_ready) return 'Kamu sudah selesai riset.';
    if (widget.jailed) return 'Dikurung · belanja ditutup.';
    if (_left == 0) return 'Jatah riset habis.';
    if (widget.balance < _price(item)) return '$_currencyName belum cukup.';
    return null;
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    if (_action != null || _error != null || _blockReason(item) != null) return;
    setState(() => _action = _Action.buy);
    try {
      await widget.repo.buyResearch(widget.gameId, _id(item));
      if (!mounted) return;
      widget.onBought?.call();
      _toast('${_name(item)} masuk ke tanganmu.');
      await _load();
    } catch (error) {
      _toast(errMsg(error));
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _finish() async {
    if (_action != null || _ready) return;
    setState(() => _action = _Action.finish);
    try {
      await widget.repo.finishResearch(widget.gameId);
      if (mounted) setState(() => _finished = true);
    } catch (error) {
      _toast(errMsg(error));
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = {
      for (final category in _Category.values)
        category: <Map<String, dynamic>>[],
    };
    for (final item in _items ?? const <Map<String, dynamic>>[]) {
      final kind = widget.defs[_id(item)]?['kind'];
      groups[kind == 'lanjutan' ? _Category.advanced : _Category.points]!.add(
        item,
      );
    }
    final category = groups[_category]!.isNotEmpty
        ? _category
        : _Category.values.firstWhere(
            (kind) => groups[kind]!.isNotEmpty,
            orElse: () => _category,
          );
    final offers = groups[category]!;
    final selected =
        offers.where((item) => _id(item) == _selectedId).firstOrNull ??
        offers.firstOrNull;

    return LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 340;
        final split = box.maxWidth >= (short ? 510 : 700);
        final compact = box.maxHeight < 425;
        final hasOffers = _error == null && selected != null;
        final finish = _finishControl();
        final controls = hasOffers ? _categories(groups, category) : null;
        final finishInHeader = split || !hasOffers;
        final Widget content;
        if (!hasOffers) {
          content = _marketState();
        } else {
          final catalog = _offersGrid(offers, selected, category, short: short);
          final selection = _selection(
            selected,
            category,
            compact: compact,
            side: split,
            finish: finishInHeader ? null : finish,
          );
          if (split) {
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: catalog),
                SizedBox(
                  width: (box.maxWidth * 0.27).clamp(188.0, 316.0),
                  child: selection,
                ),
              ],
            );
          } else {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            if (box.maxHeight < 225 + math.max(0, scale - 1) * 85) {
              content = ListView(
                children: [
                  SizedBox(height: 170, child: catalog),
                  selection,
                ],
              );
            } else {
              content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: catalog),
                  selection,
                ],
              );
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(
              inline: split,
              controls: controls,
              finish: finishInHeader ? finish : null,
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _toolbar({required bool inline, Widget? controls, Widget? finish}) {
    final quota = _error == null && _items != null ? '$_left/$_limit' : '–';
    return Container(
      decoration: tableEdge(_accent),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GameIcon('store', size: 25),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Pasar Riset',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: EmbunColors.cream,
                  ),
                ),
              ),
              if (inline && controls != null)
                Flexible(flex: 2, child: controls),
              const SizedBox(width: 7),
              Tooltip(
                message: 'Harga +20% dari harga biasa',
                child: Text('+20%', style: dayCaption.copyWith(color: _accent)),
              ),
              const SizedBox(width: 9),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Jatah '),
                    TextSpan(
                      text: quota,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: dayCaption,
              ),
              if (inline && finish != null) ...[
                const SizedBox(width: 9),
                SizedBox(width: 139, child: finish),
              ],
            ],
          ),
          if (!inline && controls != null) controls,
          if (!inline && finish != null)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(width: 145, child: finish),
            ),
        ],
      ),
    );
  }

  Widget _marketState() {
    final error = _error;
    final loading = error == null && _items == null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              GameIcon(error == null ? 'item' : 'alert', size: 30),
            const SizedBox(height: 8),
            Text(
              error != null
                  ? 'Stok riset gagal dimuat'
                  : loading
                  ? 'Memuat stok riset…'
                  : 'Pasar riset sedang kosong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: EmbunColors.cream,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(error, textAlign: TextAlign.center, style: dayCaption),
              TextButton.icon(
                onPressed: _action == null
                    ? () {
                        setState(() => _items = null);
                        _load();
                      }
                    : null,
                icon: const GameIcon('refresh', size: 20),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categories(
    Map<_Category, List<Map<String, dynamic>>> groups,
    _Category category,
  ) => Row(
    children: [
      for (final kind in _Category.values)
        Expanded(
          child: _categoryTab(
            kind,
            groups[kind]!.length,
            selected: category == kind,
          ),
        ),
    ],
  );

  Widget _categoryTab(_Category kind, int count, {required bool selected}) {
    final color = selected ? _accent : EmbunColors.cream;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: kind.hint,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: count == 0
                ? null
                : () => setState(() {
                    _category = kind;
                    _selectedId = null;
                  }),
            child: Container(
              decoration: selected ? tableEdge(_accent) : null,
              constraints: const BoxConstraints(minHeight: 35),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GameIcon(kind.icon, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: count == 0 ? Colors.white38 : color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('$count', style: dayCaption.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offersGrid(
    List<Map<String, dynamic>> offers,
    Map<String, dynamic> selected,
    _Category category, {
    required bool short,
  }) => LayoutBuilder(
    builder: (context, box) {
      const gap = 8.0;
      final available = box.maxWidth - 16;
      final columns = ((available + gap) / (short ? 142 : 104))
          .floor()
          .clamp(1, math.min(offers.length, short ? 4 : 6))
          .toInt();
      final gridWidth = math.min(
        box.maxWidth,
        columns * (short ? 185.0 : 153.0) + (columns - 1) * gap + 16,
      );
      final columnWidth = (gridWidth - 16 - (columns - 1) * gap) / columns;
      final cardWidth = (columnWidth - 8).clamp(1.0, short ? 33.0 : 137.0);
      final scaler = MediaQuery.textScalerOf(context);
      final labelHeight = scaler.scale(12) * 2.55 + scaler.scale(11) * 1.35;
      final extent = short
          ? math.max(cardWidth * kTallAspect, labelHeight) + 16
          : cardWidth * kTallAspect + labelHeight + 27;
      return Center(
        child: SizedBox(
          width: gridWidth,
          child: GridView.builder(
            key: PageStorageKey((widget.gameId, widget.day, category)),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              mainAxisExtent: extent,
            ),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final item = offers[index];
              return _offer(
                item,
                cardWidth,
                selected: item == selected,
                short: short,
              );
            },
          ),
        ),
      );
    },
  );

  Widget _offer(
    Map<String, dynamic> item,
    double width, {
    required bool selected,
    required bool short,
  }) {
    final name = _name(item);
    final price = _price(item);
    final bought = item['bought'] == true;
    final definition = _definition(item);
    final targets = cardHayuTargetLabel(definition);
    final card = CardTile(
      def: definition,
      fallbackName: name,
      width: width,
      selected: selected && !short,
      dim: bought && !selected,
      bought: bought,
      showHayuTargets: true,
    );
    final title = Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: short ? TextAlign.start : TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: EmbunColors.cream,
      ),
    );
    final cost = Row(
      mainAxisAlignment: short
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        GameIcon(bought ? 'centang' : _currency, size: 15),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            bought ? 'Terbeli' : '$price',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: bought ? EmbunColors.leaf : _accent,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: [
        bought ? '$name, terbeli' : '$name, $price $_currencyName',
        ?targets,
      ].join(', '),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: short && selected ? tableEdge(_accent) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedId = _id(item)),
            child: ExcludeSemantics(
              child: short
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          card,
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 2),
                                cost,
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(3, 12, 3, 4),
                      child: Column(
                        children: [
                          card,
                          const SizedBox(height: 4),
                          Expanded(child: Center(child: title)),
                          cost,
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selection(
    Map<String, dynamic> item,
    _Category category, {
    required bool compact,
    required bool side,
    Widget? finish,
  }) {
    final definition = _definition(item);
    final name = _name(item);
    final description = definition?['description'] as String?;
    final reason = _blockReason(item);
    final bought = item['bought'] == true;
    final detail = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GameIcon(category.icon, size: compact ? 23 : 29),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dayOverline,
                  ),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: side && !compact ? 19 : 14,
                      color: EmbunColors.cream,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (definition != null)
              IconButton(
                tooltip: 'Detail $name',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showCardPreview(context, definition, defs: widget.defs),
                icon: const GameIcon('info', size: 22),
              ),
          ],
        ),
        if (!compact && description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: dayCaption,
            maxLines: side && !compact ? null : 2,
            overflow: side && !compact ? null : TextOverflow.ellipsis,
          ),
        ],
        if (reason != null) ...[
          const SizedBox(height: 4),
          Text(
            reason,
            style: dayCaption.copyWith(
              color: bought ? EmbunColors.leaf : const Color(0xFFF0BE92),
            ),
          ),
        ],
      ],
    );
    final action = EmbunButton(
      label: bought
          ? 'Terbeli'
          : _action == _Action.buy
          ? 'Membeli…'
          : 'Beli · ${_price(item)}',
      icon: bought ? 'centang' : _currency,
      height: 42,
      expand: true,
      onPressed: reason == null && _action == null ? () => _buy(item) : null,
    );

    if (side) {
      return Container(
        decoration: tableEdge(_accent, vertical: true),
        padding: const EdgeInsets.fromLTRB(12, 5, 4, 6),
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxHeight < 72) {
              return SingleChildScrollView(
                child: Column(children: [detail, action]),
              );
            }
            if (!compact) {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [detail, const SizedBox(height: 7), action],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(child: SingleChildScrollView(child: detail)),
                ),
                const SizedBox(height: 5),
                action,
              ],
            );
          },
        ),
      );
    }
    return Container(
      decoration: tableEdge(_accent, top: true),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          detail,
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: action),
              if (finish != null) ...[
                const SizedBox(width: 7),
                Expanded(child: finish),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _finishControl() {
    if (_ready) {
      final total = widget.total;
      final count = widget.readyCount;
      return Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Menunggu $count/$total siap',
              textAlign: TextAlign.center,
              style: dayCaption.copyWith(
                color: EmbunColors.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? 0 : (count / total).clamp(0.0, 1.0),
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
              color: _accent,
            ),
          ],
        ),
      );
    }
    return EmbunButton(
      label: _action == _Action.finish ? 'Menyelesaikan…' : 'Selesai Riset',
      expand: true,
      height: 42,
      kind: EmbunButtonKind.secondary,
      onPressed: _action == null ? _finish : null,
    );
  }
}
