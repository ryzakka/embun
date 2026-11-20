import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const publicInformationSections = ['tentang', 'privasi', 'ketentuan'];

/// The existing deployment serves Flutter and the public static pages from
/// the same root. No OAuth query or fragment is included in these links.
Uri publicInformationUri(String section, {Uri? origin}) {
  if (!publicInformationSections.contains(section)) {
    throw ArgumentError.value(section, 'section');
  }
  final base =
      origin ?? (kIsWeb ? Uri.base : Uri.parse('https://embun.pages.dev/'));
  if (!['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
    throw ArgumentError('Alamat halaman publik tidak valid.');
  }
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/$section/',
  );
}

class PublicInformationLinks extends StatelessWidget {
  const PublicInformationLinks({super.key});

  Future<void> _open(BuildContext context, String section) async {
    try {
      final opened = await launchUrl(
        publicInformationUri(section),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Halaman belum dapat dibuka. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 2,
    runSpacing: 2,
    children: [
      for (final entry in const {
        'tentang': 'Tentang Embun',
        'privasi': 'Privasi',
        'ketentuan': 'Ketentuan',
      }.entries)
        TextButton(
          onPressed: () => _open(context, entry.key),
          child: Text(entry.value, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}
