import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/copy_probe.dart';

/// AP06 文案守卫（CP09 1–4 与对照表「现状」列精确旧串）。
///
/// 两级内容检查：
/// - 持有非页面文件与 number_format.dart：CP09 1–4 + 实际出现在这些文件中的
///   精确旧串（_oldHeld）。被既有测试钉住的旧串不在本层检查范围，逐条记录在
///   AP06.md 偏差账本，由持有页面票处理。
/// - copy/* 新库：CP09 1–4 + 对照表全部精确旧串（_oldAll），新代码不得复活旧文案。
/// 页面文件只做基线计数检查；内容检查在 AP14 全局归零后由总控扩展。

const _heldNonPage = <String>[
  'lib/src/api.dart',
  'lib/src/session.dart',
  'lib/src/workspace.dart',
  'lib/src/currency.dart',
  'lib/src/overview_period.dart',
  'lib/src/appearance.dart',
  'lib/src/map/map_key.dart',
  'lib/src/map/map_consent.dart',
  'lib/src/map/sketch_platform.dart',
  'lib/src/map/amap_ios_platform.dart',
  'lib/src/map/amap_android_platform.dart',
];

/// 出现在持有非页面文件中的对照表「现状」精确旧串（AP06 负责清除）。
const _oldHeld = <String>['未配置 · 使用路线速写'];

/// 对照表「现状」列全部精确旧串（copy 新库禁止复活）。
const _oldAll = <String>[
  '10 月 · 2026',
  '10月2日行程',
  '16:05–16:51 46 分钟',
  '20% → 80% 记录用时不可用：…',
  '2026-03-29 07:10，充电类型 DC，34 分钟',
  '2026-10-02 至 2026-10-02',
  '2026/10 · 未结束月',
  '209 km 记录里程',
  '46趟有效',
  '52 趟 估算 197.47 kWh 净电耗 154 Wh/km',
  '8 次',
  '8/9 次已记录',
  '9 次，对应入电 214 kWh',
  '9/27—10/26（期间上方）',
  'AC 与 DC 接近 · 类型未知 20.7 kWh',
  'AC记录 DC记录 未知分类记录',
  'DC 占已知分类能量 44.86% · 未知不计入构成 · 分类已知 9/9 次',
  'HTTP 信任、地图隐私、清除 Key、退出此设备、费用补录后果',
  'Y · 尾号 0002',
  'complete · 有效 · complete 等记录行',
  'minimum_paired_drives : 5 等',
  'pp = SOC 百分点',
  '—（基期为0）',
  '↑ 91.3 km · 较9/1–9/26',
  '● 是 ○ 否 × 未知；重合事件可展开查看',
  '一条有参照的变化',
  '上一温度组',
  '上月同期 09.01 — 09.26，55.4 km',
  '下一温度组',
  '与参照同期持平',
  '与速度过程同屏',
  '两类能量',
  '两类能量分别记录，不相加。',
  '仅1个采样点，无法绘制趋势',
  '仅看 YYYY年M月D日结束的充电',
  '今日 km',
  '估算 kWh',
  '位置采样完整时间',
  '依据',
  '候选',
  '候选 4 · 排除 1 · 开放 1',
  '停放SOC变化',
  '充入电池',
  '充入电量趋势',
  '充电 #1',
  '充电中 · 11.0 kW（状态行）',
  '充电单价 CNY',
  '充电已结束',
  '充电曲线 kW',
  '充电次数',
  '充电类型 DC',
  '充电记录 #1',
  '入电 46.8 kWh',
  '入电量走势 · 按结束日',
  '全部指标与口径',
  '全部类型',
  '全部记录',
  '全部费用',
  '关联观察，不代表因果或排名',
  '净电耗 154 Wh/km（行内）',
  '净电耗趋势 · 估算',
  '出发 18%',
  '出行节奏',
  '分段：里程 电耗 补能 费用',
  '分母为有效窗口观测小时',
  '分类记录时长：AC 90.0',
  '分页游标未前进，已保留现有充电，请刷新或手动重试',
  '分页游标未前进，已保留现有行程，请刷新或手动重试',
  '到达 82%',
  '前一个采样',
  '前一点',
  '功率 kW',
  '功率读数 11.00 kW',
  '加权净电耗 · Wh/km',
  '加载更多窗口',
  '参照 9/1–9/26',
  '参照 9/1–9/26 55.4 km（差 4.6 km）',
  '参照口径不可比，仅展示原值',
  '参照暂不可用',
  '口径或覆盖待核验，仅展示原值',
  '同期参照不足',
  '后一个采样',
  '后一点',
  '在线 2.0 h · 16.7%',
  '地图',
  '地点校验时间 …',
  '地点账目',
  '基期为 0',
  '基期区间',
  '外观',
  '完整 URL 第二行',
  '完整匹配 1 趟',
  '对应入电',
  '对照电量',
  '小样本，仅供点读',
  '差 +4.6 km',
  '已到最后一条',
  '已显示全部行程',
  '已知充电费用',
  '已知支出 · 覆盖同时看',
  '已知费用的覆盖',
  '已知费用趋势',
  '币种未记录',
  '平均记录速度',
  '应用区间',
  '应用日期',
  '开始日期 YYYY-MM-DD',
  '归期时区',
  '恢复近30日',
  '我的补能方式',
  '所选月中位数',
  '所选温度组 · −10至−5°C',
  '扩展能力暂未确认；保留当前口径',
  '持平',
  '按开始日归期',
  '排除原因：missing_soc ×1',
  '推荐 HTTPS 安全连接。请保留端口和反向代理路径前缀。',
  '搜索充电地点',
  '数据说明与更多',
  '数据说明（折叠入口）',
  '无法读取设备 IANA 时区，暂按 UTC 展示与归期',
  '日期格式 YYYY-MM-DD；…',
  '日期矩阵',
  '时长（三格）',
  '曲线数据说明',
  '更多充电信息',
  '更多行程指标',
  '最近',
  '最近充电',
  '最近状态区间起始',
  '最近的充电',
  '最近的路',
  '最近结束',
  '最近行程',
  '月中位数 · P10–P90有效日波动带（km）/ 纵轴 410–460 km，非零起点',
  '有效入电均价',
  '有效入电均价 0.4/kWh',
  '有效入电均价 0.87 ¥/kWh',
  '有效日 8 · 有效样本',
  '有效窗口 2 · 观测 12.0 h · 标准化率 -4.0 pp/24h',
  '有效窗口SOC变化',
  '有效配对',
  '服务信息',
  '服务端采样 N 点',
  '服务端采样 N 点 · 当前指标有效 M 点',
  '服务返回格式不兼容，请核对版本',
  '未知 0.0 分钟',
  '未知时间分布',
  '未配置',
  '未配置 · 使用路线速写',
  '本月 · 2026年10月',
  '本月 · 驾驶里程',
  '本期',
  '本期区间',
  '本期尚无可统计时间，稍后刷新里程趋势',
  '本次 188 Wh/km，参考净电耗 188 Wh/km（此前30个完整本地日 · 全部路线；服务端估算，样本覆盖未知）；缺失不补点。',
  '查找',
  '查看全部充电记录',
  '查看期间补能记录',
  '查看比较依据',
  '查看该温度组行程',
  '校验时间',
  '次行程',
  '正值回升、负值下降都只是观测变化；标准化率为已观测结果，不预测未来24小时。',
  '此指标没有已知读数',
  '每入电 kWh',
  '每日用车',
  '每日补能',
  '每日里程 km（图表头）+ 10.01 — 10.26',
  '每活跃日 41.8 km',
  '每网侧 kWh',
  '比较依据',
  '毛电耗说明',
  '活跃 5 天',
  '浅色；币种',
  '海拔过程',
  '温度下的用车能耗',
  '满电等效额定续航',
  '满电等效额定续航 · 记录估计 · 非电池健康检测',
  '点按图形读值',
  '点按读值',
  '版本与兼容性',
  '状态时间分布',
  '独立6/12个本地月窗口',
  '电池加热状态变化',
  '电网侧',
  '电网侧 22 kWh',
  '电量 %',
  '电量下降 0 个百分点',
  '电量区间',
  '电量过程',
  '看当天',
  '站点连接',
  '结束日期 YYYY-MM-DD',
  '结束日期（含）',
  '统计专题',
  '统计区间须大于 0 且不超过 730×24 小时，请缩小区间',
  '统计区间须大于0且不超过730天，行程列表仍可使用',
  '继续',
  '缺失的费用不表示免费。净电耗与驾驶消耗为估算。',
  '自定义日期',
  '自定义统计日期',
  '自己的地点账目',
  '行程地图（图下标签）',
  '行程室外均温 · 5°C半开分组',
  '行程电量区间',
  '补入电池',
  '补能结构 · AC',
  '补能账本（说明标题）',
  '补能账目 · 按结束日 · 仅已完成充电',
  '记录、端点电量与口径',
  '记录时长 · 非等待时间',
  '记录驾驶时长 798 分钟 · 46趟有记录',
  '证据',
  '该组数据覆盖',
  '读取参照中',
  '费用',
  '费用 ¥71.28',
  '费用有记录',
  '费用有记录 8',
  '费用覆盖 2',
  '距离缺失',
  '路线示意 · 非导航',
  '车辆与数据',
  '较上月同期',
  '较参照低 8 Wh/km',
  '过程数据说明',
  '近7天 · 驾驶里程',
  '返回完整区间',
  '返回账本',
  '这一次的账',
  '这段时间的用车节奏',
  '进专题查看',
  '选择车辆：车辆 ID 1',
  '速度数据说明',
  '速度读数 60 km/h',
  '速度过程',
  '配对估算',
  '配对估算净电耗',
  '配对净电耗与覆盖',
  '采样数据说明',
  '里程走势',
  '重试概览',
  '重试补能',
  '重试里程趋势',
  '非实时 · 数据截至 HH:mm',
  '驾驶 13h18',
  '驾驶消耗',
  '驾驶消耗趋势 · 估算',
  '默认跟随系统。切换后立即生效，并保存在本机。',
  '；保留上次快照',
];

List<String> _copyLibraryFiles() {
  if (!Directory('lib/src/copy').existsSync()) return [];
  return Directory('lib/src/copy')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => 'lib/src/copy/${f.uri.pathSegments.last}')
      .toList()
    ..sort();
}

void main() {
  group('文案守卫·基线计数（每源文件一个基线，只许下降）', () {
    test('每个含中文的源文件都有基线，且当前计数不高于基线', () {
      final dir = Directory('test/support/copy_guard_baseline');
      final baselines = <String, int>{};
      for (final entry in dir.listSync()) {
        if (entry is! File || !entry.path.endsWith('.txt')) continue;
        final key = entry.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.txt$'),
          '',
        );
        final text = entry.readAsStringSync().trim();
        final value = int.tryParse(text);
        expect(
          value,
          isNotNull,
          reason: '${entry.uri.pathSegments.last} 内容必须是一个整数',
        );
        baselines[key] = value!;
      }
      expect(baselines, isNotEmpty, reason: '基线目录为空');
      final problems = <String>[];
      for (final file in appSourceFiles()) {
        final basename = file.split('/').last;
        final count = chineseLiteralCount(File(file).readAsStringSync());
        if (count == 0) continue;
        final baseline = baselines[basename];
        if (baseline == null) {
          problems.add(
            '$file 含 $count 行中文字面量，缺基线 test/support/copy_guard_baseline/$basename.txt',
          );
        } else if (count > baseline) {
          problems.add('$file 中文字面量 $count 行超过基线 $baseline（只许下降）');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('文案守卫·内容检查（CP09 1–4 与精确旧串）', () {
    test('持有非页面文件与 copy 库无违规', () {
      final checked = <String>[
        ..._heldNonPage,
        'lib/src/number_format.dart',
        ..._copyLibraryFiles(),
      ];
      final violations = <String>[];
      for (final file in checked) {
        final lines = File(file).readAsStringSync().split('\n');
        final isHeld =
            _heldNonPage.contains(file) || file == 'lib/src/number_format.dart';
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('// copy-guard: technical')) continue;
          for (final lit in chineseLiterals(line)) {
            final at = '$file:${i + 1}';
            if (copyGuardViolationDotJoin(lit)) {
              violations.add('$at CP09.1 点号拼接: $lit');
            }
            if (copyGuardViolationUnitLabel(lit)) {
              violations.add('$at CP09.2 单位当标签: $lit');
            }
            if (copyGuardViolationTechnicalToken(lit)) {
              violations.add('$at CP09.3 字段名/技术 token: $lit');
            }
            if (copyGuardViolationSymbolSubstitute(lit)) {
              violations.add('$at CP09.4 符号代替词: $lit');
            }
            final oldList = isHeld ? _oldHeld : _oldAll;
            if (oldList.contains(lit)) {
              violations.add('$at 精确旧串: $lit');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
