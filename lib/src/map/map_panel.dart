import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../design/components/button.dart' show MileafControlMetrics;
import '../design/components/glass_surface.dart';
import '../design/components/icon_button.dart';
import '../design/icons.dart';
import '../design/layout.dart';
import '../design/semantic.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../performance_trace.dart';
import 'amap_android_platform.dart';
import 'amap_ios_platform.dart';
import 'map_consent.dart';
import 'map_consent_sheet.dart';
import 'map_platform.dart';
import 'map_key.dart';
import 'map_privacy_page.dart';
import 'map_scene.dart';
import 'sketch_platform.dart';

MapPlatform defaultMapPlatform() {
  if (Platform.isAndroid) return const AmapAndroidPlatform();
  if (Platform.isIOS) return const AmapIosPlatform();
  return const SketchPlatform();
}

enum _MapStatus {
  configuration,
  consent,
  unsupported,
  empty,
  loading,
  ready,
  failed,
}

class MapPanel extends StatefulWidget {
  /// P04 shared detail geometry, independent of text scaling.
  static const detailHeight = 220.0;
  static const sketchHeight = 120.0;
  const MapPanel({
    super.key,
    required this.scene,
    required this.consent,
    this.platform,
    this.height = 280,
    this.overlay,
    this.interactive = false,
    this.onExpand,
    this.showControls = false,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(MileafRadius.lg),
    ),
  });

  final MapScene scene;
  final MapConsentController consent;
  final MapPlatform? platform;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final Widget? overlay;
  final bool interactive;
  final VoidCallback? onExpand;
  final bool showControls;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  late MapPlatform _platform;
  late _MapStatus _status;
  final _controller = MapViewController();
  Timer? _timer;
  int _generation = 0;
  int? _trial;
  String? _approval;
  bool _retrySketch = false;
  MapKeyController? _keys;
  String? _keyStamp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keys = MapKeyScope.maybeOf(context);
    final stamp = _keys == null
        ? null
        : "${_keys!.loaded}|${_keys!.readFailed}|${_keys!.effectiveKey}";
    if (stamp != _keyStamp) {
      _keyStamp = stamp;
      _reset();
    }
  }

  @override
  void initState() {
    super.initState();
    _platform = widget.platform ?? defaultMapPlatform();
    _status = _initialStatus();
    widget.consent.addListener(_consentChanged);
    if (!widget.consent.loaded) widget.consent.load();
    if (_status == _MapStatus.loading) _arm();
  }

  @override
  void didUpdateWidget(covariant MapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consent != widget.consent) {
      oldWidget.consent.removeListener(_consentChanged);
      widget.consent.addListener(_consentChanged);
    }
    final nextPlatform = widget.platform ?? defaultMapPlatform();
    if (oldWidget.platform != widget.platform ||
        oldWidget.scene.isEmpty != widget.scene.isEmpty) {
      _platform = nextPlatform;
      _reset();
      return;
    }
    if (_status == _MapStatus.empty && !widget.scene.isEmpty) {
      _reset();
    } else if (_status != _MapStatus.consent &&
        _status != _MapStatus.empty &&
        widget.scene.isEmpty) {
      _timer?.cancel();
      setState(() => _status = _MapStatus.empty);
    }
  }

  _MapStatus _initialStatus() {
    if (widget.scene.isEmpty) return _MapStatus.empty;
    if (_keys != null && !_keys!.available) return _MapStatus.configuration;
    if (!widget.consent.isGrantedFor(_platform.providerName)) {
      return _MapStatus.consent;
    }
    if (!_platform.supported) return _MapStatus.unsupported;
    return _MapStatus.loading;
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _status = _initialStatus();
      _approval = null;
      _generation++;
    });
    if (_status == _MapStatus.loading) _arm();
  }

  void _consentChanged() {
    if (!mounted) return;
    if (_keys != null && !_keys!.available) {
      _reset();
      return;
    }
    if (!widget.consent.isGrantedFor(_platform.providerName)) {
      _timer?.cancel();
      setState(() => _status = _MapStatus.consent);
      return;
    }
    if (_status == _MapStatus.consent) _reset();
  }

  bool get _isSketch => _platform.providerName == '路线示意';

  void _arm() {
    _timer?.cancel();
    _trial = _isSketch
        ? null
        : PerformanceTrace.start(PerformancePoint.mapRequest);
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted && _status == _MapStatus.loading) {
        _failed(MapFailure.timeout);
      }
    });
  }

  void _loaded() {
    if (!mounted || _status != _MapStatus.loading) return;
    _timer?.cancel();
    if (!_isSketch) {
      PerformanceTrace.mark(
        PerformancePoint.mapFirstTileDecoded,
        trial: _trial,
      );
    }
    setState(() {
      _status = _MapStatus.ready;
      _retrySketch = false;
    });
  }

  void _failed(MapFailure failure) {
    if (!mounted ||
        (_status != _MapStatus.loading && _status != _MapStatus.ready)) {
      return;
    }
    _timer?.cancel();
    PerformanceTrace.mark(PerformancePoint.mapFailed, trial: _trial);
    setState(() => _status = _MapStatus.failed);
  }

  void _retry() {
    _retrySketch = true;
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.consent.removeListener(_consentChanged);
    _controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final degraded =
            (_status != _MapStatus.ready && _status != _MapStatus.loading) ||
            (_status == _MapStatus.loading && _retrySketch);
        final mapHeight = degraded && widget.height.isFinite
            ? MapPanel.sketchHeight
            : widget.height.isFinite
            ? widget.height
            : constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final panel = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status == _MapStatus.empty)
              _content(context)
            else
              SizedBox(
                height: mapHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _content(context),
                        if (_status != _MapStatus.ready &&
                            widget.overlay != null)
                          Positioned.fill(
                            child: IgnorePointer(child: widget.overlay!),
                          ),
                        if (_status == _MapStatus.ready &&
                            widget.onExpand != null)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onExpand,
                            ),
                          ),
                        if (_status == _MapStatus.ready) _chrome(context),
                        if (_status == _MapStatus.loading) _loading(context),
                      ],
                    ),
                  ),
                ),
              ),
            if (_status == _MapStatus.configuration)
              _configurationPanel(context),
            if (_status == _MapStatus.unsupported) _unsupportedPanel(context),
            if (_status == _MapStatus.failed) _failurePanel(context),
            if (_keys?.restartRequired == true)
              Text(_keys!.status, style: context.type.footnote),
            if (widget.onExpand != null &&
                degraded &&
                _status != _MapStatus.consent)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onExpand,
                  child: const Text('查看完整地图'),
                ),
              ),
            if (_status == _MapStatus.consent)
              Padding(
                padding: const EdgeInsets.only(top: MileafSpace.s8),
                child: _consentCard(context),
              ),
          ],
        );
        return constraints.hasBoundedHeight
            ? SingleChildScrollView(child: panel)
            : panel;
      },
    );
  }

  Widget _content(BuildContext context) {
    switch (_status) {
      case _MapStatus.empty:
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: Text(
              '没有有效轨迹坐标',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      case _MapStatus.configuration:
      case _MapStatus.consent:
      case _MapStatus.unsupported:
      case _MapStatus.failed:
        return RouteSketch(scene: widget.scene);
      case _MapStatus.loading:
      case _MapStatus.ready:
        final generation = _generation;
        final map = KeyedSubtree(
          key: ValueKey(_generation),
          child: _platform.build(
            widget.scene,
            MapCallbacks(
              onLoaded: () {
                if (generation == _generation) _loaded();
              },
              onFailed: (failure) {
                if (generation == _generation) _failed(failure);
              },
              onApprovalNumber: (value) {
                if (mounted && generation == _generation) {
                  setState(() => _approval = value);
                }
              },
            ),
            _controller,
          ),
        );
        return widget.interactive ? map : IgnorePointer(child: map);
    }
  }

  Widget _chrome(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        if (widget.onExpand != null)
          Positioned(
            right: MileafSpace.s8,
            top: MileafSpace.s8,
            // CL30/CL31：地图浮控的背板由实色改玻璃（P15 的「不用玻璃」被
            // 本增量取代），参数与底栏、浮层菜单同源。
            child: _glassButton(
              context,
              child: MileafIconButton(
                icon: MileafIconName.expand,
                tooltip: '查看完整地图',
                fill: MileafIconButtonFill.none,
                onPressed: widget.onExpand,
              ),
            ),
          ),
        if (widget.overlay != null)
          Positioned.fill(child: IgnorePointer(child: widget.overlay!)),
        if (widget.showControls)
          Positioned(
            right: MileafSpace.s8,
            bottom: MileafSpace.s32,
            child: Column(
              children: [
                _mapButton(
                  context,
                  '适配轨迹',
                  MileafIconName.route,
                  _controller.fit,
                ),
                _mapButton(
                  context,
                  '放大地图',
                  MileafIconName.plus,
                  _controller.zoomIn,
                ),
                _mapButton(
                  context,
                  '缩小地图',
                  MileafIconName.minus,
                  _controller.zoomOut,
                ),
              ],
            ),
          ),
        // 底部版权：地图卡的最后一行（P04），实色底保证在底图上可读。
        Positioned(
          right: MileafSpace.s8,
          bottom: MileafSpace.s4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: MileafRadius.xsAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MileafSpace.s4,
                vertical: MileafSpace.inline2,
              ),
              child: Text(
                _approval == null || _approval!.isEmpty
                    ? '© ${_platform.providerName}'
                    : '© ${_platform.providerName} $_approval',
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(
    BuildContext context,
    String tooltip,
    MileafIconName icon,
    VoidCallback onPressed,
  ) => Padding(
    padding: const EdgeInsets.only(top: MileafSpace.s8),
    child: _glassButton(
      context,
      child: MileafIconButton(
        icon: icon,
        tooltip: tooltip,
        fill: MileafIconButtonFill.none,
        onPressed: onPressed,
      ),
    ),
  );

  /// Flutter 速写可透过背板取样；加载中的原生地图走同几何实色回退。
  Widget _glassButton(BuildContext context, {required Widget child}) =>
      SizedBox.square(
        dimension: MileafLayout.touchTarget(context),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: MileafControlMetrics.iconVisual,
              child: MileafGlassSurface.control(
                borderRadius: MileafRadius.fullAll,
                forceSolid:
                    (_status == _MapStatus.loading ||
                        _status == _MapStatus.ready) &&
                    (_platform is AmapAndroidPlatform ||
                        _platform is AmapIosPlatform),
                child: const SizedBox.expand(),
              ),
            ),
            child,
          ],
        ),
      );

  Widget _loading(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.surface.withValues(alpha: 0.86),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MileafIcon(
              MileafIconName.mapPin,
              size: MileafIconMetrics.nav,
              color: colors.textSecondary,
            ),
            const SizedBox(height: MileafSpace.s8),
            Text(
              '正在加载底图',
              style: context.type.footnote.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The full privacy notice below the map uses its natural text height.
  ///
  /// Map geometry and authorization remain independent of notice wrapping.
  Widget _consentCard(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '底图未启用，显示路线示意',
              style: type.subheadline.copyWith(color: colors.text),
            ),
          ),
          TextButton(
            onPressed: () => showMapConsentSheet(
              context,
              widget.consent,
              providerName: _platform.providerName,
            ),
            child: const Text('启用地图'),
          ),
          if (widget.onExpand != null)
            MileafIconButton(
              icon: MileafIconName.expand,
              tooltip: '查看完整地图',
              fill: MileafIconButtonFill.track,
              onPressed: widget.onExpand,
            ),
        ],
      ),
    );
  }

  Widget _unsupportedPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s8),
      child: _card(
        context,
        Text(
          '此平台暂不支持底图，其他记录仍可阅读',
          style: context.type.body.copyWith(color: context.colors.textMuted),
        ),
      ),
    );
  }

  void _openConfiguration(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MapPrivacyPage(
            consent: widget.consent,
            providerName: _platform.providerName,
          ),
        ),
      );

  Widget _configurationPanel(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MileafSpace.s8),
    child: _card(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _keys!.readFailed ? '地图配置读取失败，显示路线速写' : '配置地图 Key 后可加载底图',
            style: context.type.body,
          ),
          TextButton(
            onPressed: () => _openConfiguration(context),
            child: const Text('配置地图'),
          ),
        ],
      ),
    ),
  );

  Widget _failurePanel(BuildContext context) {
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s8),
      child: _card(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '地图暂不可用，其他记录仍可阅读',
              style: type.body.copyWith(color: context.colors.textMuted),
            ),
            Wrap(
              children: [
                TextButton(onPressed: _retry, child: const Text('重试底图')),
                if (_keys != null)
                  TextButton(
                    onPressed: () => _openConfiguration(context),
                    child: const Text('地图设置'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Natural-height map notices share the raised surface and control radius.
  Widget _card(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.all(MileafSpace.s12),
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: MileafRadius.mdAll,
      border: Border.all(color: context.colors.line),
    ),
    child: child,
  );
}
