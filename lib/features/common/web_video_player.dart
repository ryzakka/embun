// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class WebVideoPlayer extends StatefulWidget {
  final String src;
  final BoxFit fit;

  const WebVideoPlayer({
    super.key,
    required this.src,
    this.fit = BoxFit.cover,
  });

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-${widget.src.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final video = web.document.createElement('video') as web.HTMLVideoElement;
        video.src = widget.src;
        video.autoplay = true;
        video.loop = true;
        video.muted = true; // Wajib true agar browser mengizinkan autoplay tanpa interaksi pengguna
        video.setAttribute('playsinline', 'true');
        video.style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain';
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.border = 'none';
        video.style.pointerEvents = 'none';
        return video;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return HtmlElementView(viewType: _viewId);
  }
}