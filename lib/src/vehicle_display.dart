import 'session.dart';

/// P16 车辆区分信息与显示名（AP13 归拢：session.dart、session_pages.dart、
/// workspace_page.dart 三处拷贝合并于此；连接符差异是既有约定——车辆弹层
/// 行用「，」（CP09.1），顶栏窄镜片用「 · 」，见 reading_continuity_test）。

/// P16/CP09：车辆区分信息片段（型号 + 尾号后四位），按行内出现顺序。
List<String> vehicleDistinctionParts(Vehicle vehicle) {
  final suffix = vehicle.vinSuffix.trim();
  final lastFour = suffix.length > 4
      ? suffix.substring(suffix.length - 4)
      : suffix;
  final model = vehicle.model?.trim() ?? '';
  return [if (model.isNotEmpty) model, if (lastFour.isNotEmpty) '尾号 $lastFour'];
}

/// P16/CP09：行内区分信息「型号，尾号」；无区分信息返回 null。
/// 车辆编号只在无任何区分信息时作为回退出现，不与名称并列。
String? vehicleDistinction(Vehicle vehicle) {
  final parts = vehicleDistinctionParts(vehicle);
  if (parts.isEmpty) return null;
  return parts.join('，');
}

/// 顶栏车辆镜片名：名称优先；无名称回退「型号 · 尾号」（镜片窄行用 ·
/// 连接，语义由 topline 语义标签承载）；再无则「车辆 N」。
String vehicleName(Vehicle vehicle) {
  if (vehicle.name?.trim().isNotEmpty ?? false) return vehicle.name!.trim();
  final parts = vehicleDistinctionParts(vehicle);
  return parts.isEmpty ? '车辆 ${vehicle.id}' : parts.join(' · ');
}
