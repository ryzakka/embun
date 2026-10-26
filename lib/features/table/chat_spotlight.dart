import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'chat_sheet.dart' show CutScene, chatAccent, sortChat;

/// Lapisan adegan obrolan di luar layar obrolan (layar meja dan diskusi).
///
/// Tempatkan di dalam Stack milik TablePage, di atas isi halaman:
///
///   Positioned.fill(child: ChatSpotlightLayer(...))
///
/// Adegan ditaruh di bagian ATAS panel kanan (di bawah bar mata uang dan
/// deretan avatar) dan menyisakan ruang di bawah, supaya kolom ketik dan
/// tombol "Siap memilih" / "Akhiri hari" tidak tertutup.
///
/// Pesan pertama yang diterima dianggap riwayat (tidak disorot). Selama
/// [enabled] false (fase lain, efek dimatikan, atau sheet obrolan terbuka),
/// pesan baru tetap dicatat sebagai "sudah dilihat" supaya tidak diputar
/// ulang nanti.
class ChatSpotlightLayer extends StatefulWidget {
  /// null = stream obrolan belum memberi data pertama.
  final List<Map<String, dynamic>>? messages;
  final List<Map<String, dynamic>> players;
  final String myId;
  final bool enabled;

  /// Jarak kiri supaya adegan tidak menutupi sidebar hari (120 + garis + padding).
  final double leftInset;

  /// Jarak atas: melewati bar mata uang + deretan avatar + judul diskusi.
  final double topInset;

  /// Ruang kosong di bawah untuk kolom ketik dan tombol aksi.
  final double bottomInset;
  final double sceneHeight;

  const ChatSpotlightLayer({
    super.key,
    required this.messages,
    required this.players,
    required this.myId,
    required this.enabled,
    this.leftInset = 137,
    this.topInset = 190,
    this.bottomInset = 130,
    this.sceneHeight = 240,
  });

  @override
  State<ChatSpotlightLayer> createState() => _ChatSpotlightLayerState();
}

class _ChatSpotlightLayerState extends State<ChatSpotlightLayer> {
  final Set<String> _known = {};
  bool _primed = false;
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _spot;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ingest();
  }

  @override
  void didUpdateWidget(covariant ChatSpotlightLayer old) {
    super.didUpdateWidget(old);
    _ingest();
    if (!widget.enabled && (_spot != null || _queue.isNotEmpty)) {
      _timer?.cancel();
      _queue.clear();
      _busy = false;
      _spot = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ingest() {
    final rows = widget.messages;
    if (rows == null) return;
    // Pesan lobi (hari 0) disembunyikan: nama aslinya bisa membocorkan identitas.
    final all = rows.where((m) => m['day'] != 0).toList();
    final fresh = <Map<String, dynamic>>[];
    for (final m in sortChat(all)) {
      final id = m['id'] as String;
      if (_known.add(id) && _primed) fresh.add(m);
    }
    _primed = true;
    if (fresh.isNotEmpty && widget.enabled) _enqueue(fresh);
  }

  void _enqueue(List<Map<String, dynamic>> msgs) {
    _queue.addAll(msgs);
    if (_queue.length > 3) _queue.removeRange(0, _queue.length - 3);
    if (!_busy) _next();
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      _busy = false;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _spot = null);
      });
      return;
    }
    _timer?.cancel();
    final m = _queue.removeAt(0);
    _busy = true;
    setState(() => _spot = m);
    final len = (m['body'] as String).length;
    var ms = (2000 + len * 40).clamp(2400, 4600).toInt();
    if (_queue.isNotEmpty) ms -= 700;
    _timer = Timer(Duration(milliseconds: ms), _next);
  }

  void _skip() {
    if (_queue.isEmpty) {
      _timer?.cancel();
      _busy = false;
      setState(() => _spot = null);
    } else {
      _next();
    }
  }

  String? _cardOf(String? id) {
    for (final p in widget.players) {
      if (p['user_id'] == id) return p['character_card'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    final uid = spot?['user_id'] as String?;
    final mine = uid == widget.myId;

    return SafeArea(
      child: LayoutBuilder(builder: (context, c) {
        // Di layar pendek, inset disusutkan secara proporsional.
        final total = c.maxHeight;
        final top = min(widget.topInset, total * 0.28);
        final bottom = min(widget.bottomInset, total * 0.2);
        final h = min(widget.sceneHeight, total - top - bottom);
        final show = widget.enabled && spot != null && h >= 110;

        return Padding(
          padding: EdgeInsets.fromLTRB(widget.leftInset, top, 16, bottom),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              layoutBuilder: (cur, prev) => Stack(
                alignment: Alignment.topCenter,
                children: [...prev, ?cur],
              ),
              child: show
                  ? SizedBox(
                key: const ValueKey('cut'),
                height: h,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CutScene(
                    msg: spot,
                    card: _cardOf(uid),
                    mine: mine,
                    accent: chatAccent(uid, mine),
                    onSkip: _skip,
                  ),
                ),
              )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
        );
      }),
    );
  }
}