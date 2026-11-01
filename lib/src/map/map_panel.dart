import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../performance_trace.dart';
import 'amap_android_platform.dart';
import 'amap_ios_platform.dart';
import 'map_consent.dart';
import 'map_consent_sheet.dart';
import 'map_platform.dart';
import 'map_scene.dart';
import 'sketch_platform.dart';

MapPlatform defaultMapPlatform() {
  if (Platform.isAndroid) return const AmapAndroidPlatform();
  if (Platform.isIOS) return const AmapIosPlatform();
  return const SketchPlatform();
}

enum _MapStatus { consent, unsupported, empty, loading, ready, failed }

class MapPanel extends StatefulWidget {
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
      bottom: Radius.circular(22),
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
    setState(() => _status = _MapStatus.ready);
  }

  void _failed(MapFailure failure) {
    if (!mounted || _status == _MapStatus.failed) return;
    _timer?.cancel();
    PerformanceTrace.mark(PerformancePoint.mapFailed, trial: _trial);
    setState(() => _status = _MapStatus.failed);
  }

  void _retry() {
    setState(() {
      _status = _MapStatus.loading;
      _generation++;
    });
    _arm();
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
    return SizedBox(
      height: widget.height,
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
              if (_status != _MapStatus.ready && widget.overlay != null)
                Positioned.fill(child: IgnorePointer(child: widget.overlay!)),
              if (_status == _MapStatus.ready && widget.onExpand != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onExpand,
                  ),
                ),
              if (_status == _MapStatus.ready) _chrome(context),
              if (_status == _MapStatus.loading) _loading(context),
              if (_status == _MapStatus.consent) _consentPanel(context),
              if (_status == _MapStatus.unsupported) _unsupportedPanel(context),
              if (_status == _MapStatus.failed) _failurePanel(context),
            ],
          ),
        ),
      ),
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
      case _MapStatus.consent:
      case _MapStatus.unsupported:
      case _MapStatus.failed:
        return RouteSketch(scene: widget.scene);
      case _MapStatus.loading:
      case _MapStatus.ready:
        final map = KeyedSubtree(
          key: ValueKey(_generation),
          child: _platform.build(
            widget.scene,
            MapCallbacks(
              onLoaded: _loaded,
              onFailed: _failed,
              onApprovalNumber: (value) {
                if (mounted) setState(() => _approval = value);
              },
            ),
            _controller,
          ),
        );
        return widget.interactive ? map : IgnorePointer(child: map);
    }
  }

  Widget _chrome(BuildContext context) {
    final theme = Theme.of(context);
    final chip = theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92);
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: chip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('地图', style: theme.textTheme.labelSmall),
          ),
        ),
        if (widget.onExpand != null)
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: chip,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: '打开全屏地图',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onExpand,
                icon: const Icon(Icons.open_in_full, size: 19),
              ),
            ),
          ),
        if (widget.overlay != null)
          Positioned.fill(child: IgnorePointer(child: widget.overlay!)),
        if (widget.showControls)
          Positioned(
            right: 10,
            bottom: 34,
            child: Column(
              children: [
                _mapButton(context, '适配轨迹', Icons.fit_screen, _controller.fit),
                _mapButton(context, '放大地图', Icons.add, _controller.zoomIn),
                _mapButton(context, '缩小地图', Icons.remove, _controller.zoomOut),
              ],
            ),
          ),
        Positioned(
          right: 8,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: chip.withValues(alpha: 0.86),
            child: Text(
              _approval == null || _approval!.isEmpty
                  ? '© ${_platform.providerName}'
                  : '© ${_platform.providerName} $_approval',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(
    BuildContext context,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow
          .withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    ),
  );

  Widget _loading(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.86),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 24,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('正在加载底图', style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }

  Widget _consentPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('底图未启用 · 路线示意', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              '加载后会向${_platform.providerName}发送 IP、设备/网络信息和当前地图范围；不发送站点凭据，不读取手机定位。',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => showMapConsentSheet(
                  context,
                  widget.consent,
                  providerName: _platform.providerName,
                ),
                child: const Text('启用地图'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unsupportedPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text('此平台暂不支持底图，其他记录仍可阅读', style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _failurePanel(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '地图暂不可用 · 其他记录仍可阅读',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: _retry, child: const Text('重试底图')),
          ],
        ),
      ),
    );
  }
}
