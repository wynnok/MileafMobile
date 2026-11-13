import 'package:flutter/material.dart';

import 'appearance.dart';
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

Future<void> showAppearanceSheet(
  BuildContext context,
  AppearanceController controller,
) => showMileafSheet<void>(
  context: context,
  title: '外观',
  builder: (_) => _AppearanceSheet(controller: controller),
);

class _AppearanceSheet extends StatefulWidget {
  const _AppearanceSheet({required this.controller});
  final AppearanceController controller;
  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  String? error;

  Future<void> select(MileafAppearance mode) async {
    try {
      await widget.controller.select(mode);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = '外观偏好保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('默认跟随系统。切换后立即生效，并保存在本机。', style: type.micro),
          const SizedBox(height: MileafSpace.s12),
          for (final mode in MileafAppearance.values)
            _AppearanceRow(
              mode: mode,
              selected: widget.controller.mode == mode,
              onTap: () => select(mode),
            ),
          if (error != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: type.micro.copyWith(color: colors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final MileafAppearance mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MileafDataRow(
      title: mode.label,
      selected: selected,
      badge: selected
          ? MileafIcon(
              MileafIconName.check,
              size: MileafIconMetrics.nav,
              color: context.colors.accentStrong,
            )
          : null,
      onTap: onTap,
    );
  }
}
