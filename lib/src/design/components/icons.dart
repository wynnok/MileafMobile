// MG04 / R32 图标家族统一出口。
//
// 本文件是「行笺」自绘图标家族的唯一出口：
// - 造型实现（[MileafIcon] / [MileafIconName]）桥接自 `lib/src/design/icons.dart`，
//   视觉与 API 零变化；组件与页面一律 `import 'design/components/icons.dart'`。
// - 家族参数（网格 / 线宽 / 端点 / 拐角 / 视觉盒）实测登记于 [MileafIconFamily]，
//   取值单一来源为 `MileafIconMetrics`，不在本文件复制数值。
// - 每个图标一句话语义登记于 [MileafIconFamily.semanticLabels]，选义走
//   apple-polish-copy CP02/CP04/CP10/CP11 术语。
//
// TODO(DM08/MG04 迁移票)：把 `_MileafIconPainter` 实现体从 design/icons.dart
// 迁入本文件并在原文件 re-export。迁移需改写 18 个 `import 'design/icons.dart'`
// 的既有 importer 且 components.dart barrel 当前有他人在途改动，留给集成包执行；
// 本包只建立出口与参数登记，不改任何既有文件。
//
// 页面自绘 hero 状态图形（充电中闪电 / 休眠月亮 / 离线）已由 AP01 迁入家族
// （`vehicleStatusIcon`，见 design/components/hero.dart:39-43），本包盘点确认
// 页面直绘图标为 0，无占位常量需要登记；DM05–DM07 页面包如发现新的自绘
// 图标，必须经本出口并以家族参数表为准。
library;

export '../icons.dart';

import 'package:flutter/material.dart' show StrokeCap, StrokeJoin;

import '../icons.dart' show MileafIconName;
import '../tokens.dart' show MileafIconMetrics;

/// 自绘图标家族参数表（MG04/R32 实测登记后冻结）。
///
/// 全部取值引用 [MileafIconMetrics]，保证参数单一来源；家族一致性由
/// `test/icon_family_test.dart` 守卫。
abstract final class MileafIconFamily {
  /// 网格：24×24 逻辑像素，绘制时按 `size / grid` 等比缩放。
  static const double grid = MileafIconMetrics.grid;

  /// 描边线宽：1.5 逻辑像素（R32）。
  static const double strokeWidth = MileafIconMetrics.stroke;

  /// 端点策略：圆头（design/icons.dart:79 实测）。
  static const StrokeCap strokeCap = StrokeCap.round;

  /// 拐角策略：圆角连接（design/icons.dart:80 实测）。
  static const StrokeJoin strokeJoin = StrokeJoin.round;

  /// 视觉盒档位（正方形边长）：行内 16 / 导航 20 / 页头 24。
  static const double boxInline = MileafIconMetrics.inline;
  static const double boxNav = MileafIconMetrics.nav;
  static const double boxHeader = MileafIconMetrics.header;

  /// 每个图标一句话语义（读屏标签推荐值，页面可给更完整的 CP11 句式）。
  static const Map<MileafIconName, String> semanticLabels = {
    MileafIconName.home: '概览',
    MileafIconName.car: '车辆',
    MileafIconName.bolt: '充电中',
    MileafIconName.chart: '统计',
    MileafIconName.route: '行程',
    MileafIconName.mapPin: '地点',
    MileafIconName.battery: '电量',
    MileafIconName.clock: '时长',
    MileafIconName.settings: '设置',
    MileafIconName.chevron: '查看详情',
    MileafIconName.refresh: '刷新',
    MileafIconName.wallet: '费用',
    MileafIconName.info: '说明信息',
    MileafIconName.close: '关闭',
    MileafIconName.check: '已完成',
    MileafIconName.copy: '复制',
    MileafIconName.calendar: '选择日期区间',
    MileafIconName.more: '更多操作',
    MileafIconName.expand: '放大查看',
    MileafIconName.chevronDown: '展开日期列表',
    MileafIconName.back: '返回',
    MileafIconName.plus: '放大地图',
    MileafIconName.minus: '缩小地图',
    MileafIconName.moon: '车辆休眠',
    MileafIconName.offline: '离线，无网络',
    MileafIconName.leaf: '续航与效率',
    MileafIconName.thermometer: '温度',
    MileafIconName.speed: '速度',
    MileafIconName.share: '分享',
  };
}
