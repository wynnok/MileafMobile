import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// §4 M10 大内容查看器：长按栏项时在屏幕中央放大的**同一个**标签。
///
/// R26/PD05 允许底栏标签、收起后的顶栏标题与顶栏胶囊文字放大封顶 1.35×，
/// 代价由这个浮层补足：160×160、半径 20、图标 40 + 文字 title2，实色
/// surfaceRaised 与浮层阴影（R24：阴影只给浮层）。浮层是 Flutter 自绘，
/// iOS 与 Android 行为一致；它不进入语义树，读屏仍读原来的完整名称。
class MileafLargeContentViewer extends StatelessWidget {
  const MileafLargeContentViewer({super.key, required this.label, this.icon});

  final String label;
  final MileafIconName? icon;

  static const extent = 160.0;
  static const radius = MileafRadius.lg;
  static const iconSize = MileafIconMetrics.nav * 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconName = icon;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: colors.sheetShadow,
        ),
        child: SizedBox.square(
          dimension: extent,
          child: Padding(
            padding: const EdgeInsets.all(MileafSpace.s16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconName != null) ...[
                  MileafIcon(iconName, size: iconSize, color: colors.text),
                  const SizedBox(height: MileafSpace.s8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.title2.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 大内容查看器的浮层生命周期：出现 150ms、消失 120ms（M10），减少动效时
/// 两者都为 0。宿主（底栏、顶栏）在长按开始时 [show]、移动时用新的标签再次
/// [show]（同一浮层不重播入场）、抬手时 [hide]。
class MileafLargeContentViewerHost {
  MileafLargeContentViewerHost(this._overlay);

  final OverlayState? _overlay;
  final _label = ValueNotifier<String>('');
  final _icon = ValueNotifier<MileafIconName?>(null);
  final _key = GlobalKey<_LargeContentViewerState>();
  OverlayEntry? _entry;

  void show({required String label, MileafIconName? icon}) {
    final overlay = _overlay;
    _label.value = label;
    _icon.value = icon;
    if (overlay == null) return;
    if (_entry != null) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            // 浮层插在根 Overlay 里，没有 Material / DefaultTextStyle 祖先；
            // 透明 Material 只提供正常文字样式，不给浮层添材质或水波。
            child: Material(
              type: MaterialType.transparency,
              child: _LargeContentViewer(key: _key, label: _label, icon: _icon),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  Future<void> hide() async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    await _key.currentState?.dismiss();
    entry.remove();
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
    _label.dispose();
    _icon.dispose();
  }
}

class _LargeContentViewer extends StatefulWidget {
  const _LargeContentViewer({
    super.key,
    required this.label,
    required this.icon,
  });

  final ValueListenable<String> label;
  final ValueListenable<MileafIconName?> icon;

  @override
  State<_LargeContentViewer> createState() => _LargeContentViewerState();
}

class _LargeContentViewerState extends State<_LargeContentViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MileafLayout.motion(
      context,
      MileafDurations.viewerIn,
    );
    if (_controller.isDismissed) _controller.forward();
  }

  Future<void> dismiss() async {
    _controller.duration = MileafLayout.motion(
      context,
      MileafDurations.viewerOut,
    );
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: ScaleTransition(
      scale: Tween<double>(
        begin: MileafMotion.viewerScale,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: MileafCurves.fade)),
      child: ValueListenableBuilder<MileafIconName?>(
        valueListenable: widget.icon,
        builder: (context, icon, _) => ValueListenableBuilder<String>(
          valueListenable: widget.label,
          builder: (context, label, _) =>
              MileafLargeContentViewer(label: label, icon: icon),
        ),
      ),
    ),
  );
}
