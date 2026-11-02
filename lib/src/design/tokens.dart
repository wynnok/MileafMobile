import 'package:flutter/material.dart';

/// Primitive palette for the「行笺」appearance v2 system (ADR 0006, Spec §2.2).
///
/// Raw colour values are only allowed here (and in [MileafElevation]); pages
/// and components consume the semantic tokens in `semantic.dart`.
///
/// Neutrals stay neutral (slate / paper / mist / graphite); the brand colour is
/// a signal only and comes in two strengths: `azure500` for graphics and
/// `azure600` for text and solid fills.
abstract final class MileafPalette {
  const MileafPalette._();

  /// 电光蓝：图形（500）/ 文字与实心（600）/ hero 图形（300）。
  static const azure300 = Color(0xFF64A8FF);
  static const azure500 = Color(0xFF2688F5);
  static const azure600 = Color(0xFF0B62C4);

  /// 深色中性：hero / canvas / surface / surfaceRaised。
  static const slate1000 = Color(0xFF06090E);
  static const slate950 = Color(0xFF0A0B0D);
  static const slate900 = Color(0xFF12161C);
  static const slate850 = Color(0xFF191E25);

  /// 浅色中性：canvas / surface。
  static const paper50 = Color(0xFFF4F5F7);
  static const paper0 = Color(0xFFFFFFFF);

  /// 深色正文与 hero 内三级文字。
  static const mist0 = Color(0xFFF2F4F7);
  static const mist400 = Color(0xFFA7B4C2);
  static const mist500 = Color(0xFF9AA5B1);
  static const mist550 = Color(0xFF8A96A4);
  static const mist600 = Color(0xFF7E8A96);

  /// 浅色正文。
  static const graphite900 = Color(0xFF0E1319);
  static const graphite600 = Color(0xFF5A6672);
  static const graphite500 = Color(0xFF63707C);

  /// 参照/基线，两模式都是中性石墨。
  static const steel500 = Color(0xFF5F6B78);
  static const steel300 = Color(0xFF8E99A6);

  /// 状态色：warning / error，只出现在状态与校验。
  static const amber500 = Color(0xFFB45309);
  static const amber400 = Color(0xFFFFB020);
  static const red600 = Color(0xFFCE271B);
  static const red400 = Color(0xFFFF7A70);

  /// 浅色 hero 锚点。Spec §2.2 的 slate 档位只覆盖深色，浅色 hero 是独立取值。
  static const heroLight = Color(0xFF070B11);

  /// Alpha-based lines and overlays; kept here so pages never mix their own.
  static const lineDark = Color(0x17F2F4F7); // 242,244,247 · 9%
  static const lineStrongDark = Color(0x24F2F4F7); // 14%
  static const lineLight = Color(0x1A0E1319); // 14,19,25 · 10%
  static const lineStrongLight = Color(0x290E1319); // 16%
  static const navDark = Color(0xE00A0B0D); // 10,11,13 · 88%
  static const navLight = Color(0xEBFFFFFF); // 92%
  static const scrimDark = Color(0x80000000); // 50%
  static const scrimLight = Color(0x590E1319); // 35%
  static const skeletonDark = Color(0x12F2F4F7); // 7%
  static const skeletonLight = Color(0x0F0E1319); // 6%
  static const accentSoftDark = Color(0x2964A8FF); // 100,168,255 · 16%
  static const accentSoftLight = Color(0xFFDCEBFD);
  static const pressOverlayDark = Color(0x0AF2F4F7); // 4%
  static const pressOverlayLight = Color(0x0F0E1319); // 6%
  static const accentFocus = Color(0x9964A8FF); // 60%
}

/// 4px base spacing. Named steps are the only values pages may use.
abstract final class MileafSpace {
  const MileafSpace._();

  static const inline2 = 2.0;
  static const inline6 = 6.0;
  static const inline10 = 10.0;
  static const row14 = 14.0;
  static const section = 28.0;

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s18 = 18.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s56 = 56.0;

  /// Fixed structural measurements from the spec.
  static const heroTop = 16.0;
  static const heroBottom = 18.0;
  static const rowMin = 56.0;
  static const touch = 44.0;
  static const navHeight = 64.0;
  static const contentBottom = 84.0;
  static const chipHeight = 34.0;
  static const chartHeight = 140.0;
  static const chartHeightWide = 148.0;

  /// hero card geometry (Spec §5.1): card outer margin and fixed inner pad.
  static const cardInset = 12.0;
  static const cardPad = 16.0;
}

abstract final class MileafRadius {
  const MileafRadius._();

  static const none = Radius.zero;
  static const noneAll = BorderRadius.zero;
  static const xs = 4.0;
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const full = 999.0;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgTop = BorderRadius.vertical(top: Radius.circular(lg));
  static const fullAll = BorderRadius.all(Radius.circular(full));
}

abstract final class MileafDurations {
  const MileafDurations._();

  static const press = Duration(milliseconds: 120);
  static const tab = Duration(milliseconds: 160);
  static const enter = Duration(milliseconds: 180);
  static const value = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 240);
  static const chart = Duration(milliseconds: 500);
  static const skeleton = Duration(milliseconds: 1200);
}

/// Only two shadow levels exist: sheet/overlay and toast.
abstract final class MileafElevation {
  const MileafElevation._();

  static const sheetDark = [
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 12), blurRadius: 40),
  ];
  static const sheetLight = [
    BoxShadow(
      color: Color(0x1A0E1319), // 14,19,25 · 10%
      offset: Offset(0, 12),
      blurRadius: 40,
    ),
  ];
  static const toast = [
    BoxShadow(color: Color(0x40000000), offset: Offset(0, 6), blurRadius: 20),
  ];
}

/// Font sizes, line heights, weights and tracking from Spec §3.2.
abstract final class MileafType {
  const MileafType._();

  static const displaySize = 60.0;
  static const displayHeight = 60.0;
  static const displayTracking = -0.04;

  static const metricLgSize = 44.0;
  static const metricLgHeight = 44.0;
  static const metricLgTracking = -0.035;

  static const metricMdSize = 24.0;
  static const metricMdHeight = 26.0;
  static const metricMdTracking = -0.03;

  static const titleSize = 18.0;
  static const titleHeight = 22.0;
  static const titleTracking = -0.01;

  static const bodySize = 13.0;
  static const bodyHeight = 19.5;

  static const labelSize = 10.0;
  static const labelHeight = 13.0;
  static const labelTracking = 0.08;

  static const microSize = 9.0;
  static const microHeight = 12.0;
  static const microTracking = 0.12;

  /// Technical table values and form error text.
  static const detailSize = 12.0;
  static const detailHeight = 17.0;

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemiBold = FontWeight.w600;

  static const family = 'Inter';

  /// CJK falls back to the platform UI font; no second display family.
  static const fallback = <String>[
    'PingFang SC',
    'Noto Sans CJK SC',
    'Heiti SC',
    'sans-serif',
  ];
}

/// Icon geometry (24 grid, 1.5 stroke) and brand mark measurements.
abstract final class MileafIconMetrics {
  const MileafIconMetrics._();

  static const grid = 24.0;
  static const stroke = 1.5;
  static const inline = 16.0;
  static const nav = 20.0;
  static const header = 24.0;
  static const brandDefault = 19.0;
  static const brandMin = 18.0;
  static const brandDotDiameter = 2.7;
}

/// Chart geometry from Spec §8; no chart package is introduced.
abstract final class MileafChartMetrics {
  const MileafChartMetrics._();

  static const lineStroke = 1.5;
  static const microStroke = 1.2;
  static const areaMaxOpacity = .16;
  static const areaMinOpacity = .0;
  static const currentPoint = 4.0;
  static const currentHalo = 8.0;
  static const pointRadius = 2.5;
  static const stemStroke = 1.5;
  static const stemIdleOpacity = .35;
  static const stemEndpoint = 2.5;
  static const barMaxWidth = 12.0;
  static const barSlotCoverage = .6;
  static const barIdleOpacity = .3;
  static const barRadius = 1.0;
  static const axisLabelSize = 9.0;
  static const referenceDash = <double>[4, 4];
  static const yTicks = 3;
}

/// 88px battery arc (72 at 200%); 2.5 stroke, 10% track, 22/9 centre.
abstract final class MileafBatteryMetrics {
  const MileafBatteryMetrics._();

  static const size = 88.0;
  static const largeTextSize = 72.0;
  static const stroke = 2.5;
  static const trackOpacity = .10;
  static const valueSize = 22.0;
  static const valueHeight = 24.0;
  static const labelSize = 9.0;
}

/// Share ring geometry from Spec `charging-method-share-ring` §5.2 / §10.1.
///
/// A 12px donut split by AC / DC known energy. Dimensions step with the width
/// and the text scale; the centre may disappear before any number may shrink.
abstract final class MileafShareRingMetrics {
  const MileafShareRingMetrics._();

  static const diameterNarrow = 96.0;
  static const diameter = 104.0;
  static const diameterWide = 116.0;
  static const diameterLargeText = 120.0;
  static const stroke = 12.0;

  /// Gap between segments, in arc pixels (converted with the radius).
  static const gap = 3.0;
  static const centerPad = 8.0;
  static const legendRow = 44.0;
  static const dot = 8.0;
}

/// Brand lockup measurements from Spec §6.2.
abstract final class MileafBrand {
  const MileafBrand._();

  static const wordSize = 15.0;
  static const wordTracking = 0.3;
  static const latinSize = 7.0;
  static const latinTracking = 0.24;
  static const gap = 9.0;
  static const latinGap = 10.0;
}

/// Widths from Spec §10.1.
abstract final class MileafBreakpoints {
  const MileafBreakpoints._();

  static const compact = 320.0;
  static const base = 360.0;
  static const wide = 390.0;
  static const maxContent = 560.0;
  static const sheetMax = 520.0;

  /// `MediaQuery.textScalerOf(context).scale(14) >= 21` (about 150%).
  static const largeTextThreshold = 21.0;
  static const largeTextReference = 14.0;
}
