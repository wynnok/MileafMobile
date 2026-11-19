# MC10 记录：工作区 / 设置 / 连接 / 地图接线

凭证：[ADR 0016](../../adr/0016-chromatic-language.md) D1/D3、[规格](../../specs/chromatic-language.md) CL05/CL12/CL13/CL14/CL20。持有文件：`workspace_page.dart`、`session_pages.dart`、`connection_page.dart`、`map/map_privacy_page.dart`、`test/chromatic_shell_test.dart`。

## 做了什么

| 项 | 结论 |
| --- | --- |
| 数据身份色相 | **不引入**（CL05 + 映射表 #9）：四页源码无 `MileafHue` / `MileafDataDomain`，设置/连接/地图保持中性 + azure 动作色；参考 App 的设置页七彩索引色继续不迁移 |
| 图标 | 只复用 4 个既有字形：`car`（车行）、`refresh`（刷新/重试）、`check`（保存）、`close`（清除）；新字形 0，未引第二套库 |
| 间距 | 四页**已在 CL20 档位**，零迁移、零重排（明细见下） |
| 版面/文案/字号 | 未改：只给既有按钮传 `icon`、给两处分组行传 `leading`、给弹层动作加图标槽；四页中文字面量行数未变（copy guard 基线未动） |
| 玻璃 | 车辆弹层是 `MileafSheetFrame`（弹层，CL30.1 明确不叠玻璃）；四页无自绘浮层，未新增玻璃 |

## 逐区块色相表（CL06 / CL07）

| 页面 | 可见数据色相数（CL07） | 本切片彩色增量（CL06） | 高彩度增量（C>0.12） |
| --- | --- | --- | --- |
| 工作区 / 车辆弹层 | 0（车行图标中性 `textSecondary`，选中勾 `accentStrong`） | ≈0（刷新文字按钮图标 16×16 + 勾，<0.1% 屏） | <0.1% |
| 车辆页 / 登录页 | 0 | ≈0（主/次按钮填充与顶栏图标按钮均为改造前既有） | ≈0 |
| 连接页 | 0 | **0（本切片未改动）** | 0 |
| 地图设置页 | 0（状态行 mapPin 仍 `accent`，行首图标 `textSecondary`） | ≈0（保存 Key 主按钮图标、清除动作图标各 16×16） | <0.1% |

口径：390×844 屏逐件相加、排除图表绘图区（CL06.1）；动作色填充为改造前既有，本切片只在其内加 16 图标，故按增量登记。绝对面积的跨页统一口径由 MC12 收口。

## 补了哪些图标

| 位置 | 之前 | 现在 | 依据 |
| --- | --- | --- | --- |
| 车辆弹层车行（`_VehicleSheet`） | 无行首图标 | `car` 20，行组件取中性 `textSecondary` | CL12/CL13 |
| 车辆页车行（`VehiclePage`） | 无行首图标 | `car`（与弹层同一字形） | CL13「同一元素同一字形」 |
| 「刷新车辆列表」文字按钮 | 无图标 | `MileafActionIcon.refresh`（inline 16、间距 s8、图标在左） | CL14 |
| 「重试车辆读取」文字按钮 | 无图标 | `MileafActionIcon.retry`（= refresh） | CL14「同一动作不换图标」 |
| 地图页「保存 Key」主按钮 | 无图标 | `MileafActionIcon.save`（= check） | CL14 |
| 地图页「重试读取配置」分组行 | 无行首图标 | `MileafActionIcon.retry`，20 落卡片内边距 | CL12 + R24 |
| 地图页「清除 Key」弹层动作 | 纯文字 | `MileafActionIcon.clear`（= close）inline 16 + s8，取 TextButton 前景色 `accentStrong` | CL12/CL14 |
| 检查连接 / 登录此站点 / 编辑服务地址 / 取消更换 | 无图标 | **保持无图标**：29 字形里没有能复述这些词义的字形，按 CL14「不得引入按钮文字里没有的概念」不为凑图标自创语义 | CL14 |
| copy / back / mapPin | — | 已由 `MileafCopyRow` 复制圆钮、`mileafPageBar` 的 back、状态行 mapPin 承担，不重复添加 | CL14 |

## 间距归一清单（CL20）

四页逐行扫描 `MileafSpace.*` 与裸数字：用到且全部在档位——`cardPad`(16)×17、`s8`×12、`s12`×12、`s16`×6、`s24`×4、`section`(32)×2、`s4`×2、`s20`×1。
裸字面量只有发丝线的 `height: 0`（与 `module.dart`、概览/行程页同构，不是间距档位）；**没有 10/13/14/15 这类越级值**，故本次不迁移任何间距。
新增的弹层图标间距只取 `MileafControlMetrics.buttonIconGap`（= s8），页面未自写 8。

## 测试结果

- `./tool/flutterw analyze --no-pub lib test`：无新增诊断（唯一 info 在他人的 `test/apple_polish_ap10_test.dart:342`，属基线既有）。
- 新增 `test/chromatic_shell_test.dart`（6 用例，全绿）：弹层车行 `car` + 刷新按钮 `refresh`（inline 尺寸与「图标在左」几何断言）；车辆页车行 `car` + 重试 `retry`；地图页 `save`/`clear`（含 `accentStrong` 取色）；读取失败态重试行 leading + 与状态句同一 `x` 起始线；四页源级守卫（无 `MileafHue`/`MileafDataDomain`/裸色值；间距名只允许档位；无裸 height/width 数字）。
- 相关既有测试（map_key_page、session、apple_polish_ap02/03/07/13/15、copy_guard、settings_navigation、appearance_shell、widget_test、map_platform、ui_ux_u10）：192 过 / 2 跳过 / 1 失败；唯一失败是 copy guard 基线在**他人持有**的 `drives_page.dart`、`statistics_page.dart`、`statistics_insights_page.dart`（MC07/MC09 在途），与本切片无关。
- 全量：见文末补记。

## 登记表一行（供 MC12 收口）

| 页面 | 可见色相数 | 非图表彩色面积 | 高彩度面积 | 新增图标 | CL22 豁免 | 图册 |
| --- | --- | --- | --- | --- | --- | --- |
| 工作区 / 设置 / 连接 / 地图 | 0 | ≈0（只加动作色图标，行图标中性） | <0.1% | 0（复用 4 字形） | 0 | 本包不采图，MC12 统一采 |

## 遗留 / 交接

1. **连接页「检查连接 / 登录此站点」仍无按钮图标**：家族 29 字形无一能复述词义。要补须先在组件层定字形（本切片不得自创字形或引第二套库）。
2. **连接页的「重试」在 `InlineBanner` 动作槽**（`state_view.dart`，不在本票 write scope），该槽没有图标参数——补 retry 图标需组件层加可选 `actionIcon`，交 MC05/MC12 定夺。
3. `MileafGroupRow` 行首图标只取 `textSecondary`/`hue.strong`，无 error 档，故破坏行「清除已保存的 Key」不配 close 图标（灰图标配红字自相矛盾）；破坏语义仍由 error 文字承担，settings_order 的「起始线」断言原样保留。
4. 车行加 leading 后行文字起点右移 32（图标 20 + 间距 12），分隔线缩进由组件按 `leadingWidth` 自动跟随；未新增、未削弱任何既有断言。
