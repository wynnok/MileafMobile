import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart' show MileafControlMetrics, MileafPressOverlay;
import 'glass_surface.dart';

/// 小胶囊菜单的宽度下限（原 s56*4 的既有值；非间距语义，本地化保留原值）。
const double kPullDownMenuMinWide = 224.0;

/// CL30/CL31 浮层菜单玻璃背板的定位键：菜单是浮层（不是内容层），背板与底栏
/// 同一套玻璃参数，测试按这个键取整块背板。
const ValueKey<String> kPullDownMenuSurfaceKey = ValueKey(
  'pull-down-glass-surface',
);

/// 下拉菜单的一个选项。
@immutable
class MileafPullDownOption<T> {
  const MileafPullDownOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// R27 下拉：小胶囊（高 32，segmentTrack）+ control 文字 + 向下箭头；菜单按 R28
/// （半径 14、行高 44、选中项尾部勾选）与 CL30/CL31（浮层菜单改玻璃）。
///
/// 胶囊文字是当前值本身（对照表：类型 / 费用 / 排序 等），不另写标签。
///
/// 材质分层：胶囊在画布上，仍是 segmentTrack 实色；弹出的**菜单是浮层**，
/// 背板改玻璃。玻璃一个数值都不在本文件重写——模糊 σ、过饱和、上下叠色、
/// 受光边缘、阴影全部来自 MileafMaterialMetrics 与 MileafColors.glass*，
/// 因此浮层菜单与底栏、地图浮控是同一块玻璃（CL31.1）。
class MileafPullDown<T> extends StatefulWidget {
  const MileafPullDown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final List<MileafPullDownOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// 读屏用的对象名（如「类型」）；不给时只用当前值。
  final String? label;
  final bool enabled;

  @override
  State<MileafPullDown<T>> createState() => _MileafPullDownState<T>();
}

class _MileafPullDownState<T> extends State<MileafPullDown<T>> {
  final _anchor = GlobalKey();
  bool _pressed = false;

  Future<void> _open() async {
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showGeneralDialog<T>(
      context: context,
      // R28：菜单不吃散射光——不压暗背后内容（原生菜单同样没有 scrim），
      // 点外部关闭。层次由玻璃自己的叠色、受光边与阴影给出。
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      // R07/CL38：弹层进出用既有「状态转换」档，减少动效时归零。
      transitionDuration: MileafLayout.motion(
        context,
        MileafDurations.selection,
      ),
      pageBuilder: (routeContext, _, _) => _PullDownMenu<T>(
        overlaySize: overlay.size,
        anchor: origin & box.size,
        anchorWidth: box.size.width,
        options: widget.options,
        value: widget.value,
        onSelected: (value) => Navigator.of(routeContext).pop(value),
      ),
      transitionBuilder: (routeContext, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: MileafCurves.fade),
        child: child,
      ),
    );
    // 菜单可能在页面切换时被路由撤掉；没有新值、或宿主已卸载时不回调。
    if (!mounted) return;
    if (selected != null && selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final current = widget.options.firstWhere(
      (option) => option.value == widget.value,
      orElse: () => widget.options.first,
    );
    final semantic = widget.label;
    final value = current.label;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: semantic == null ? value : '$semantic $value',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: _anchor,
          onTap: widget.enabled ? _open : null,
          onHighlightChanged: widget.enabled
              ? (pressed) => setState(() => _pressed = pressed)
              : null,
          customBorder: const StadiumBorder(),
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MileafControlMetrics.smallCapsuleHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
            decoration: BoxDecoration(
              color: colors.segmentTrack,
              borderRadius: BorderRadius.circular(MileafRadius.full),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: type.control.copyWith(
                          color: widget.enabled
                              ? colors.text
                              : colors.textFaint.withValues(alpha: .38),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: MileafSpace.s4),
                    MileafIcon(
                      MileafIconName.chevronDown,
                      size: MileafIconMetrics.inline,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                Positioned.fill(
                  child: MileafPressOverlay(
                    visible: _pressed,
                    color: colors.accentSoft,
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

/// 弹出的菜单面板：一块玻璃 + 若干 44 高选项行。
///
/// 位置沿用 R28 的锚点几何——贴在胶囊下方 s4，宽度不小于胶囊且不小于
/// [kPullDownMenuMinWide]，左右各留 s8 不出屏；下方放不下时翻到胶囊上方。
class _PullDownMenu<T> extends StatelessWidget {
  const _PullDownMenu({
    required this.overlaySize,
    required this.anchor,
    required this.anchorWidth,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  final Size overlaySize;
  final Rect anchor;
  final double anchorWidth;
  final List<MileafPullDownOption<T>> options;
  final T value;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    // R28：菜单上下各留 s8 内边距，行与行之间不再加间距。
    const pad = MileafSpace.s8;
    final menuWidth = math.max(anchorWidth, kPullDownMenuMinWide);
    final height =
        options.length * MileafControlMetrics.menuRowHeight + pad * 2;
    final left = math.min(
      anchor.left,
      math.max(MileafSpace.s8, overlaySize.width - menuWidth - MileafSpace.s8),
    );
    var top = anchor.bottom + MileafSpace.s4;
    if (top + height > overlaySize.height - MileafSpace.s8) {
      top = math.max(MileafSpace.s8, anchor.top - height - MileafSpace.s4);
    }
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: anchorWidth,
              maxWidth: menuWidth,
            ),
            // CL30/CL31：整块背板就是一块玻璃。模糊 σ、过饱和、叠色、受光边与
            // 挖孔阴影都由 MileafGlassSurface 从 MileafMaterialMetrics /
            // MileafColors.glass* 取；它自带的 1px 受光描边是浅色压在亮内容上的
            // 兜底边界（tokens.dart 的 glassRim* 注释：白色边线在浅底上等于没有
            // 边界，所以下半圈用石墨收暗）。
            child: MileafGlassSurface(
              key: kPullDownMenuSurfaceKey,
              borderRadius: BorderRadius.circular(
                MileafControlMetrics.menuRadius,
              ),
              // 语义与兜底（与 Material 的 popup menu 对齐的那两条）：
              // 1. 让读屏把浮层当成一个可命名的路由（scopesRoute/namesRoute），
              //    否则换成自建路由后整块面板对读屏是「无名的对话框」；
              // 2. 选项多到超出屏幕时能滚（原 PopupMenu 有 SingleChildScrollView，
              //    这里用 maxHeight 限高 + 滚动兜底，避免列表被裁掉）。
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                // scopesRoute 要求显式子节点：菜单把每个选项行当作独立语义节点。
                explicitChildNodes: true,
                label: '选择项',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: pad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        MileafControlMetrics.menuRowHeight,
                        overlaySize.height - MileafSpace.s8 * 4,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options)
                            _PullDownRow<T>(
                              option: option,
                              selected: option.value == value,
                              onSelected: onSelected,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 菜单行：高 44、左右 16、body 文字、选中项尾部勾选（R28）。
///
/// 按压走 M01 的覆盖层（无涟漪）；语义是一个按钮，选中项读作已选中。
class _PullDownRow<T> extends StatefulWidget {
  const _PullDownRow({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final MileafPullDownOption<T> option;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  State<_PullDownRow<T>> createState() => _PullDownRowState<T>();
}

class _PullDownRowState<T> extends State<_PullDownRow<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.option.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => widget.onSelected(widget.option.value),
        child: SizedBox(
          height: MileafControlMetrics.menuRowHeight,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MileafSpace.s16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.option.label,
                        style: type.body.copyWith(color: colors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.selected) ...[
                      const SizedBox(width: MileafSpace.s12),
                      MileafIcon(
                        MileafIconName.check,
                        size: MileafIconMetrics.nav,
                        color: colors.accent,
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: MileafPressOverlay(
                    visible: _pressed,
                    color: colors.accentSoft,
                    borderRadius: MileafRadius.smAll,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
