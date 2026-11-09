import 'package:flutter/material.dart';

import '../common/art.dart';
import '../common/ornate.dart';

BorderSide learningRule([Color color = EmbunColors.gold]) =>
    BorderSide(color: color.withValues(alpha: 0.32));

/// Satu latar untuk judul, navigasi, dan isi halaman belajar.
class LearningFrame extends StatelessWidget {
  final String title;
  final String icon;
  final String? background;
  final Widget? navigation;
  final List<Widget> actions;
  final Widget child;

  const LearningFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.background,
    this.navigation,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmbunColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(path: background, dim: 0.70),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x90101C15),
                  Color(0x1007130F),
                  Color(0xD007130F),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = navigation != null && box.maxWidth >= 740;
                    final showIcon = actions.isEmpty || box.maxWidth >= 360;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: box.maxWidth < 450 ? 12 : 22,
                        vertical: box.maxHeight < 480 ? 3 : 7,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(bottom: learningRule()),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Kembali',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: const GameIcon('back', size: 22),
                                    ),
                                    if (showIcon) ...[
                                      GameIcon(icon, size: 27),
                                      const SizedBox(width: 7),
                                    ],
                                    Expanded(
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w800,
                                            color: EmbunColors.cream,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (wide)
                                      Flexible(flex: 3, child: navigation!),
                                    ...actions,
                                  ],
                                ),
                                if (!wide) ?navigation,
                              ],
                            ),
                          ),
                          Expanded(child: child),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
