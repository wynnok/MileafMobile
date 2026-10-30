# C 行程列表（#9）

2026-10-30，基于 C 原型、ADR 0001 与 #9 C 增量。仅改变列表呈现：深色期间里程主 tile，紧凑出行节奏，薄荷色强调服务端顺序中的首条路线/地点记录，其他记录使用纸面 tile；12px 页边距、8px 节奏。保留起终点、时间、距离/时长、估算能量/电耗、围栏/地址、进行中和缺失提示。归期时区、完整查询区间及校验时间收入数据说明。

列表不含路线坐标，因而未画装饰性地图、未预取详情；点记录仍进入原详情。统计、日期筛选、点日、分页、缓存、迟到响应隔离和 API 没有修改。主 tile 为整行，不需双列 bento；200% 字号自然单列展开。

## 验证

- TDD：先增加 App＋可控 HTTP 测试，因缺少“最近的路”红灯；实现后通过，验证 360×800 的节奏、首条可点击记录、技术说明收起与点击进入行程 #17。
- `tool/flutterw test --no-pub test/collage_drives_test.dart test/drives_test.dart`：29 项通过，包含日期、统计独立加载、分页失败/304/去重、切车与200%既有回归。
- `tool/flutterw analyze`：无问题；修改文件已格式化。
- `test/collage_drives_render_test.dart`：正常/空/缺失 × 浅/深色 × 100/200%，20 张正式 Flutter PNG，生成前检查无 Flutter 异常。样本统计距离遵守冻结契约（必有）；缺失样本覆盖能量/电耗及记录距离、长地点。空样本为0趟/0km及空桶，不生成零趋势。
- 已人工查看正常浅深首屏、正常大字首屏/记录、长地点缺失大字/深色、空态浅色与深色大字，未发现横向裁切；大字允许纵向滚动。图册在 `collage-renders/drives/`。

复现：`MILEAF_FLUTTER_SDK` 指向现有项目 SDK，运行 `tool/flutterw test --no-pub test/collage_drives_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/drives '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。

本切片未运行双端构建；由集成复验统一进行。用户视觉评审、读屏、真机返回、真实站点分页与对账、地图和性能仍待验，不关闭工单，不推送。
