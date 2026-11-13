import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/game_repository.dart';
import '../../data/inspection.dart';
import '../common/art.dart';
import '../common/ornate.dart';

Future<bool> showInspectionReport(
  BuildContext context,
  InspectionReport report, {
  String? characterStem,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: _ReportDialog(report: report, characterStem: characterStem),
      ),
    ) ??
    false;

class _ReportDialog extends StatelessWidget {
  const _ReportDialog({required this.report, this.characterStem});
  final InspectionReport report;
  final String? characterStem;

  @override
  Widget build(BuildContext context) {
    final accent = switch (report.outcome) {
      'antagonis' || 'buruk' => EmbunColors.mist,
      'warga' || 'baik' || 'number' => EmbunColors.leaf,
      _ => EmbunColors.gold,
    };
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 470,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: Duration(milliseconds: reduced ? 0 : 650),
          curve: Curves.easeOutCubic,
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: .94 + .06 * value, child: child),
          ),
          child: OrnatePanel(
            accent: accent,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const GameIcon('lock', size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'HASIL PRIBADI',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                            color: EmbunColors.gold,
                          ),
                        ),
                      ),
                      Text(
                        'HARI ${report.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: PlayerAvatar(
                      path: characterStem == null
                          ? null
                          : protagonistPath(characterStem!),
                      size: 86,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.targetName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: EmbunColors.cream,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    report.source,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: accent.withValues(alpha: .3),
                        ),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: .03),
                          accent.withValues(alpha: .13),
                          accent.withValues(alpha: .03),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          report.headline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: report.isNumber ? 52 : 30,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          report.detail,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (report.isRole)
                    Text(
                      'Tingkat pemeriksaan ${report.chance ?? 30}%${(report.chance ?? 30) >= 80 ? ' · Kebal pengelabuan' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: EmbunColors.gold,
                      ),
                    )
                  else if (report.isNumber)
                    const Text(
                      'ANGKA PASTI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: EmbunColors.leaf,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 17),
                  EmbunButton(
                    label: 'Simpan ke catatan',
                    icon: 'centang',
                    expand: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Hanya kamu yang melihat hasil ini. Buka ulang lewat Infoku.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showInspectionHistory(
  BuildContext context, {
  required GameRepository repo,
  required String gameId,
  required List<Map<String, dynamic>> players,
  void Function(String id)? onRead,
}) => showDialog<void>(
  context: context,
  builder: (_) => _HistoryDialog(
    repo: repo,
    gameId: gameId,
    players: players,
    onRead: onRead,
  ),
);

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({
    required this.repo,
    required this.gameId,
    required this.players,
    this.onRead,
  });
  final GameRepository repo;
  final String gameId;
  final List<Map<String, dynamic>> players;
  final void Function(String)? onRead;
  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  late Future<List<Map<String, dynamic>>> _future = widget.repo
      .inspectionReports(widget.gameId);
  Future<void> _open(InspectionReport report) async {
    final player = widget.players
        .where((p) => p['user_id'] == report.targetId)
        .firstOrNull;
    final read = await showInspectionReport(
      context,
      report,
      characterStem: player?['character_card'] as String?,
    );
    if (!mounted || !read) return;
    widget.onRead?.call(report.id);
    try {
      await widget.repo.markInspectionReportRead(report.id);
    } catch (_) {
      /* Tetap tersimpan; dapat dicoba saat tersambung lagi. */
    }
    if (mounted) _reload();
  }

  void _reload() {
    final next = widget.repo.inspectionReports(widget.gameId);
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(14),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: OrnatePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Catatan pemeriksaan',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'PRIBADI · Seluruh pertandingan',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white54,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Catatan belum dapat dimuat.'),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final reports = snapshot.data!.reversed
                      .map(InspectionReport.fromRow)
                      .toList();
                  if (reports.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Belum ada hasil pemeriksaan.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final report = reports[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _open(report),
                        leading: const GameIcon('lock', size: 25),
                        title: Text(report.targetName),
                        subtitle: Text(
                          'Hari ${report.day} · ${report.source}\n${report.headline}${report.chance == null ? '' : ' · ${report.chance}%'}',
                        ),
                        trailing: Icon(
                          report.seen ? Icons.chevron_right : Icons.circle,
                          size: report.seen ? 20 : 8,
                          color: EmbunColors.gold,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
