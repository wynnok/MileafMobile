/// MG09 状态诚实三要素：空态分档共享构造（CP 语气：先说发生了什么，再说可以做什么）。
///
/// 页面只选档位并传对象名，不自拼句子；技术原因（状态码、错误码）只进
/// 「技术详情」（CP07）。同一概念用同一个词：加载失败复用 CP07 的
/// readFailedMessage，无数据复用 emptyMessage。
library;

import 'package:mileaf/src/copy/dates.dart' show formatTime;
import 'package:mileaf/src/copy/messages.dart'
    show emptyMessage, readFailedMessage;

/// 空态分档（MG09）：离线 / 加载失败 / 无数据 / 筛选无结果。
enum EmptyStateTier { offline, loadFailed, noData, filterNoMatch }

/// 一档空态的现状句与建议动作。
class EmptyStateCopy {
  const EmptyStateCopy(this.status, this.action);

  /// 现状句：先说发生了什么。
  final String status;

  /// 建议动作：再说可以做什么（CP06 动词 + 对象）。
  final String action;
}

/// 按档位取现状句与建议动作；[object] 缺省为「数据」。
EmptyStateCopy emptyStateCopy(EmptyStateTier tier, {String? object}) {
  final name = object ?? '数据';
  return switch (tier) {
    EmptyStateTier.offline => const EmptyStateCopy(
      '网络不可用，显示的是缓存数据',
      '重试',
    ),
    EmptyStateTier.loadFailed => EmptyStateCopy(readFailedMessage(name), '重试'),
    EmptyStateTier.noData => EmptyStateCopy(emptyMessage(name), '刷新'),
    EmptyStateTier.filterNoMatch => EmptyStateCopy('筛选后没有$name', '调整筛选'),
  };
}

/// MG09 时间或原因行：「数据截至 HH:mm」（DF4 时间）。
String dataAsOfLine(DateTime time) => '数据截至 ${formatTime(time)}';
