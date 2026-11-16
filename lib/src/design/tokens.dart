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
  static const segmentTrackLight = Color(0xFFE6E9ED);
  static const segmentSelectedDark = Color(0xFF343C46);

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
  static const navDark = Color(0xE60A0B0D); // 10,11,13 · 90%
  static const navLight = Color(0xE0FFFFFF); // 88%
  static const navHighlightDark = Color(0x1AFFFFFF); // 10%
  static const navHighlightLight = Color(0x59FFFFFF); // 35%
  static const scrimDark = Color(0x80000000); // 50%
  static const scrimLight = Color(0x590E1319); // 35%
  static const skeletonDark = Color(0x12F2F4F7); // 7%
  static const skeletonLight = Color(0x0F0E1319); // 6%
  static const accentSoftDark = Color(0x2964A8FF); // 100,168,255 · 16%
  static const accentSoftLight = Color(0xFFDCEBFD);
  static const pressOverlayDark = Color(0x0AF2F4F7); // 4%
  static const pressOverlayLight = Color(0x0F0E1319); // 6%
  static const accentFocus = Color(0x9964A8FF); // 60%

  /// 液态玻璃底栏（ADR 0013）。四组值分别是「玻璃体上下沿」、顶部高光、
  /// 下沿弯月增厚、选中镜片，以及内外两圈受光边缘。
  ///
  /// 浅色以白、深色以近黑叠色，因此玻璃只会把浅色内容提亮、把深色内容压暗，
  /// 正文对比不会被自身透明度吃掉；合成实测见 liquid_glass_nav_test 的 L04。
  static const glassLightTop = Color(0x66FFFFFF); // 白 · 40%
  static const glassLightBottom = Color(0x8FFFFFFF); // 白 · 56%
  static const glassLightSheen = Color(0x8CFFFFFF); // 白 · 55%
  static const glassLightMeniscus = Color(0x2EFFFFFF); // 白 · 18%
  static const glassLightLensTop = Color(0x8CFFFFFF); // 白 · 55%
  static const glassLightLensBottom = Color(0x66FFFFFF); // 白 · 40%

  static const glassDarkTop = Color(0x7A0A0B0D); // 10,11,13 · 48%
  static const glassDarkBottom = Color(0xA00A0B0D); // 63%
  static const glassDarkSheen = Color(0x24FFFFFF); // 白 · 14%
  static const glassDarkMeniscus = Color(0x59000000); // 黑 · 35%
  static const glassDarkLensTop = Color(0x26FFFFFF); // 白 · 15%
  static const glassDarkLensBottom = Color(0x1AFFFFFF); // 白 · 10%

  static const glassRimLightTop = Color(0xE6FFFFFF); // 90%
  static const glassRimLightSide = Color(0x52FFFFFF); // 32%
  static const glassRimLightBottom = Color(0x42FFFFFF); // 26%

  /// 浅色玻璃的内缘必须更暗：玻璃压在亮内容上时，折射让边缘收暗。
  static const glassInnerLight = Color(0x1F0E1319); // 14,19,25 · 12%

  static const glassRimDarkTop = Color(0x59FFFFFF); // 35%
  static const glassRimDarkSide = Color(0x29FFFFFF); // 16%
  static const glassRimDarkBottom = Color(0x1AFFFFFF); // 10%
  static const glassInnerDark = Color(0x1FFFFFFF); // 12%

  static const glassLensRimLightTop = Color(0xF0FFFFFF); // 94%
  static const glassLensRimLightSide = Color(0x59FFFFFF); // 35%
  static const glassLensRimLightBottom = Color(0x29FFFFFF); // 16%
  static const glassLensInnerLight = Color(0x1C0E1319); // 14,19,25 · 11%

  static const glassLensRimDarkTop = Color(0x4DFFFFFF); // 30%
  static const glassLensRimDarkSide = Color(0x24FFFFFF); // 14%
  static const glassLensRimDarkBottom = Color(0x14FFFFFF); // 8%
  static const glassLensInnerDark = Color(0x17FFFFFF); // 9%
}

/// 4px base spacing. Named steps are the only values pages may use.
abstract final class MileafSpace {
  const MileafSpace._();

  static const inline2 = 2.0;
  static const inline6 = 6.0;
  static const inline10 = 10.0;
  static const row14 = 14.0;
  static const section = 32.0;

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

  /// Generic list row floor (R05); rows that render as inputs use
  /// [inputMinHeight] instead. P16's vehicle-row floor of 56 stays satisfied.
  static const rowMin = 72.0;

  /// Text input floor (R05: 最小52，字16).
  static const inputMinHeight = 52.0;
  static const touch = 44.0;
  static const touchAndroid = 48.0;
  static const navHeight = 64.0;
  static const primaryButtonHeight = 48.0;
  static const rhythmHeight = 88.0;
  static const chartHeight = 160.0;
  static const detailChartHeight = 200.0;
  static const chartHeightWide = 160.0;

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
  static const surface = 24.0;
  static const sheet = 28.0;
  static const full = 999.0;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const surfaceAll = BorderRadius.all(Radius.circular(surface));
  static const lgTop = BorderRadius.vertical(top: Radius.circular(lg));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const fullAll = BorderRadius.all(Radius.circular(full));
}

abstract final class MileafDurations {
  const MileafDurations._();

  /// R07：按压 100ms easeOut（中性覆盖层，由 InkWell 高光承载）。
  static const press = Duration(milliseconds: 100);

  /// R16 M02：互斥选中移动 180ms。
  static const selection = Duration(milliseconds: 180);

  /// R16 M03：内容经过顶栏时，仅叠色在 120ms 内收敛。
  static const chrome = Duration(milliseconds: 120);

  /// R16 M06：折叠 chevron 160ms。保留 tab 别名供既有调用迁移。
  static const chevron = Duration(milliseconds: 160);
  static const tab = chevron;

  /// 180ms 整页入场时长。`MileafPageEnter` 已改为即时直出（U03，ADR0011），
  /// 仅剩 `map/map_privacy_page.dart`（U10 范围）的自绘折叠 chevron 消费；
  /// U10 在 P12 迁移该 chevron 后删除本 token 与 `MileafCurves.enter`。
  static const enter = Duration(milliseconds: 180);

  /// R16 M05：弹层进入 280ms、退出 220ms。
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const sheet = sheetIn;

  /// R16 M08：局部快照更新 120ms，数值在首帧即时正确。
  static const value = Duration(milliseconds: 120);
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
  static const navigationDark = [
    BoxShadow(color: Color(0x47000000), offset: Offset(0, 4), blurRadius: 16),
  ];
  static const navigationLight = [
    BoxShadow(color: Color(0x1A0E1319), offset: Offset(0, 4), blurRadius: 16),
  ];

  /// 浮动玻璃离页面的距离：一层柔和大范围晕影 + 一道贴合边缘的窄影。
  static const glassNavigationLight = [
    BoxShadow(
      color: Color(0x1A0E1319),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x0F0E1319),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];
  static const glassNavigationDark = [
    BoxShadow(
      color: Color(0x59000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x33000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];
  static const glassLensLight = [
    BoxShadow(color: Color(0x140E1319), offset: Offset(0, 2), blurRadius: 10),
    BoxShadow(color: Color(0x0A0E1319), offset: Offset(0, 1), blurRadius: 3),
  ];
  static const glassLensDark = [
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 10),
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 1), blurRadius: 3),
  ];
}

abstract final class MileafMaterialMetrics {
  const MileafMaterialMetrics._();

  static const navigationBlur = 18.0;

  /// 液态玻璃：更重的模糊与轻微过饱和，让背后的色块融成光而不是可读内容。
  static const glassBlur = 36.0;
  static const glassSaturation = 1.35;

  /// 受光边缘以物理像素为单位的倍数，缩放后仍是一条线。
  static const glassRimStroke = 1.2;
  static const glassInnerStroke = 0.9;
  static const glassLensRimStroke = 1.0;

  /// 顶部高光覆盖范围与下沿弯月起点的相对高度。
  static const glassSheenReach = .52;
  static const glassMeniscusStart = .58;

  /// 内缘细线从多高开始出现（只压在下半圈）。
  static const glassInnerReach = .42;

  /// 挖孔投影的外扩余量，要盖住最大偏移（10）与最大模糊（28）。
  static const glassShadowMargin = 96.0;

  /// BoxShadow.blurRadius 与 MaskFilter sigma 的换算。
  static const glassShadowSigmaScale = .5;

  /// 镜片移动时的起步横向拉伸（L05）。
  static const glassLensStretch = 1.06;
}

/// Font sizes, line heights, weights and tracking from Spec §3.2.
abstract final class MileafType {
  const MileafType._();

  static const displaySize = 40.0;
  static const displayHeight = 46.0;
  static const displayTracking = -0.02;

  static const metricLgSize = 32.0;
  static const metricLgHeight = 38.0;
  static const metricLgTracking = -0.02;

  static const metricMdSize = 24.0;
  static const metricMdHeight = 30.0;
  static const metricMdTracking = -0.02;

  static const pageTitleSize = 28.0;
  static const pageTitleHeight = 34.0;

  static const navLabelSize = 12.0;
  static const navLabelHeight = 16.0;

  static const titleSize = 20.0;
  static const titleHeight = 28.0;
  static const titleTracking = 0.0;

  static const navigationTitleSize = 18.0;
  static const navigationTitleHeight = 26.0;

  static const bodySize = 17.0;
  static const bodyHeight = 25.0;

  static const labelSize = 14.0;
  static const labelHeight = 20.0;
  static const labelTracking = 0.0;

  static const microSize = 12.0;
  static const microHeight = 18.0;
  static const microTracking = 0.0;

  /// Technical table values and form error text.
  static const detailSize = 12.0;
  static const detailHeight = 18.0;

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

  static const lineStroke = 2.0;

  /// R06：参照线 1.5 虚线 4/4，比主线细一档。
  static const referenceStroke = 1.5;
  static const microStroke = 1.2;
  static const areaMaxOpacity = .16;
  static const areaMinOpacity = .0;
  static const currentPoint = 4.0;
  static const currentHalo = 8.0;
  static const pointRadius = 2.5;
  static const stemStroke = 1.5;
  static const stemEndpoint = 2.5;

  /// A real zero under a bar: a dot on the baseline, never a sliver of volume.
  static const zeroDot = 1.5;
  static const barMaxWidth = 12.0;
  static const barSlotCoverage = .6;
  static const barRadius = 2.0;
  static const axisLabelSize = 12.0;
  static const referenceDash = <double>[4, 4];
  static const yTicks = 3;
}

/// 88px battery arc (72 at 200%); 2.5 stroke, 10% track, 22 centre text.
abstract final class MileafBatteryMetrics {
  const MileafBatteryMetrics._();

  static const size = 88.0;
  static const largeTextSize = 72.0;
  static const stroke = 2.5;
  static const trackOpacity = .10;
  static const valueSize = 22.0;
  static const valueHeight = 24.0;
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
