/// CP07 状态与错误：共享构造函数。页面只传对象名与时间，不自拼句子。
/// 技术原因（状态码、错误码、游标、字段名）只进「技术详情」，不进主界面。
library;

import 'package:mileaf/src/copy/dates.dart' show formatFreshness;
import 'package:mileaf/src/copy/terms.dart' show unsupportedPrefix;

String emptyMessage(String object) => '这段时间没有$object';

String firstEmptyMessage(String object) => '还没有$object';

String loadingMessage(String object) => '正在读取$object';

String staleMessage(DateTime time, DateTime now) =>
    '没能更新，显示的是 ${formatFreshness(time, now)} 的数据';

String readFailedMessage(String object) => '没能读取$object';

String paginationFailedMessage(String object) => '没能加载更多$object，已保留当前列表';

String unsupportedMessage(String capability) => '$unsupportedPrefix$capability';

String versionIncompatibleMessage() => '服务器返回的数据格式不受支持，请确认 Mileaf Server 版本';

String timezoneUnreadableMessage() => '无法读取手机时区，暂按 UTC 显示和统计';
