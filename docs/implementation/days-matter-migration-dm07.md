# DM07 页面包：统计 + 设置 + 详情 + 连接（MG09/05b/04/02/01）实施记录

> 2026-11-19，DM07（[days-matter-migration-tickets.md](../specs/days-matter-migration-tickets.md) DM07）。
> 条款依据：[days-matter-migration.md](../specs/days-matter-migration.md) MG09/05b/04/02/01、
> [days-matter-migration-state.md](days-matter-migration-state.md)（DM04 新组件接口）、
> [days-matter-migration-icons.md](days-matter-migration-icons.md) §1.2 盘点表、
> [settings-order.md](settings-order.md)（inset 参照）。
> 硬边界执行：本次未 git 提交、未推送；只改动 DM07 声明文件清单内的页面、相关测试与本文档；
`components/`、`semantic.dart`、`tokens.dart`、`overview_page.dart`（含 MetaPage 服务信息）、
`charging_page/`、`session_pages.dart`（登录页）、`currency.dart`、`copy/dates.dart`、地图平台层均未触碰。

## 1 改动文件

| 文件 | 变化 |
| --- | --- |
| `lib/src/statistics_insights_page.dart` | 统计首页两条整页失败路径接三要素；图标统一出口 import |
| `lib/src/statistics_usage_page.dart` | 用车节奏空态接无数据/筛选无结果两档（含建议动作）；图标出口 import |
| `lib/src/statistics_conditions_page.dart` | 能耗条件空态接无数据档 + 刷新动作；图标出口 import |
| `lib/src/statistics_charging_page.dart` | 补能专题空态接无数据档 + 刷新动作；图标出口 import |
| `lib/src/statistics_range_page.dart` | 续航两处空态接无数据档 + 刷新动作；图标出口 import |
| `lib/src/statistics_parking_page.dart` | 停放新增「无停车窗口」无数据档空态；图标出口 import |
| `lib/src/connection_page.dart` | 检查失败改 InlineBanner（error tone + 重试动作）；成功句保留 accentStrong 文字；图标出口 import（经管理页） |
| `lib/src/connection_management.dart` | 两处 MileafGroupHeader 传 `inset: MileafSpace.cardPad`；失败反馈改 InlineBanner；图标出口 import |
| `lib/src/setup_page.dart` | 初始化失败反馈改 InlineBanner |
| `lib/src/settings_page.dart` / `lib/src/map/map_privacy_page.dart` | inset 已由 settings-order 迁移，核对确认；图标出口 import |
| `lib/src/drive_detail_page.dart` | 三要素核对确认（见 §2.4）；图标出口 import |
| `test/days_migration_dm07_test.dart` | 新增：连接页失败三要素 + 统计首页失败三要素 |
| `test/statistics_usage_test.dart` 等 8 个相关测试 | 断言随空态分档/横幅结构更新，业务断言未放宽（见 §6） |
| `test/support/copy_guard_baseline/*.txt` 7 个 | 基线随结构登记上调（见 §5） |
| `docs/implementation/days-matter-migration-color.md` | 追加 DM07 各页彩色面积登记行（仅追加） |

## 2 MG09 状态诚实三要素接线

### 2.1 连接三页（连接页 / 连接管理 / 初始化）

- **连接页** `connection_page.dart`：`_check` 失败（API 失败/超时/握手/格式/不可达）由
  「页面直接指定 `colors.error` 的 Text」改为 `InlineBanner(tone: BannerTone.error)`，
  带重试动作（`actionLabel: '重试'`、读屏对象名 `重试检查连接`、loading 时禁用）。
  现状句沿用 CP07 既有失败句（含原因与下一步指引，如 503 →「服务可达，但数据库或上游
  暂不可用，请稍后重试」）。信任读取/保存失败句进横幅但不带「重试」动作（重试语义
  不属于健康检查，既有信任控件承担下一步）。成功句「服务正常，版本 x」保留原
  accentStrong 文字层样式，不走状态条。新增 `_messageIsSuccess` / `_checkFailed`
  两个私有标记区分两条渲染路径，既有成功/失败文案与请求行为零变化。
- **连接管理** `connection_management.dart`：`_feedback`（替换/退出失败）改为
  `InlineBanner(tone: BannerTone.error)`；下一步动作由本页既有「验证并替换连接 /
  退出此设备」主按钮承担（横幅不内嵌动作，避免与失败来源不符的通用重试）。
- **初始化** `setup_page.dart`：`session.message` 反馈改 `InlineBanner(tone: BannerTone.error)`；
  下一步动作由「设置口令并登录 / 返回登录」既有按钮承担。
- **登录页** `session_pages.dart` 不在 DM07 文件清单内，未接线（遗留，登记 §8）。
- 三页均消除「页面直接指定 `colors.error`」的 MG02 违规；tone 全部走受限四档。

### 2.2 统计首页 `statistics_insights_page.dart`

- 能力缺失（`driving_coverage != true`）分支的错误行：`Row(Text + TextButton('重试能力'))`
  改为 `InlineBanner(tone: error, actionLabel: '重试能力', actionSemanticLabel: '重试读取统计能力')`。
- 数据为空的整页失败分支：`Text(error)` 改 `InlineBanner(tone: error)`（包一层
  `SizedBox(width: double.infinity)` 适配 Center 列），「重试统计」文字按钮保留为动作。
- `referenceError` 两条横幅已带「重试」动作，核对确认，未改。
- 失败句本身已含原因（「统计读取失败，请重试；保留上次快照」），三要素由
  现状句 + 横幅/按钮动作构成。

### 2.3 统计五专题空态四档分档

现状句与建议动作取自 `lib/src/copy/state_feedback.dart` 的 `emptyStateCopy`：

| 页面 | 原空态 | 新接线 |
| --- | --- | --- |
| 用车节奏 | `区间内无已完成行程` / `这段时间没有已完成的行程；换一个期间或继续记录。` | `noData('已完成行程')` →「这段时间没有已完成行程」+ 保留指引句 + 动作「刷新」 |
| 能耗条件 | `区间内无已完成行程` / `这段时间没有可配对的已完成行程。` | `noData('可配对行程')` + 动作「刷新」（读屏「重试读取能耗条件」） |
| 补能 | `还没有充电记录` / `尚无补能统计；换一个期间或继续记录。` | `noData('充电记录')` →「这段时间没有充电记录」+ 保留指引句 + 动作「刷新」 |
| 续航·无记录 | `观察窗口内没有充电记录` | `noData('充电记录')` + 保留指引句 + 动作「刷新」 |
| 续航·样本不足 | `尚无有效续航样本` | `noData('有效续航样本')` + 保留限定句 + 动作「刷新」 |
| 停放 | （无整页空态，缺数据只画「—」） | 新增 `noData('停车窗口')` 整页空态 + 动作「刷新」（`d != null && rows.isEmpty && !busy && error == null` 时出现） |
| 行程证据（用车节奏下钻） | `没有匹配行程` | `filterNoMatch('已完成行程')` →「筛选后没有已完成行程」+ 指引句 + 动作「调整筛选」（返回上一页调整） |

- **离线档**：四档中的离线档要求「网络不可用，显示的是缓存数据」+ 缓存截至时间；
  行笺页面层没有连通性信号（catch 不区分网络类型），且 `workspace/api` 属禁改文件，
  本包不引入探测。有旧数据的刷新失败已由 CP07 `staleMessage`（「没能更新，显示的是
  HH:mm 的数据」）承担「缓存标注到分钟」的语义，五专题失败横幅均复用该构造
  ——即验收口径「显示至 HH:mm 的缓存数据」场景的既有承载，本包未改动其文案。
- **能力缺失（unsupported）空态**不属于四档原因，维持领域空态、不提供无效动作。
- 统计首页数据空态由 `legacyBuilder` 承载（S01–S08 契约，按边界保持原样）。

### 2.4 行程详情 `drive_detail_page.dart`（核对确认）

明细、过程曲线、参照三处刷新失败均已就地使用 `InlineBanner(tone: error) +
readFailedMessage/staleMessage 现状句 + 「重试」动作`，三要素在接线前已满足；
首次明细失败另有「返回行程列表」退路按钮。本包未改动其结构，仅登记确认。

### 2.5 InlineBanner tone 调用点迁移清单

DM04 已把 `tone` 参数类型收为四档受限枚举 `BannerTone`（neutral/warning/error/accent），
转发 `MileafStatusTone` 解析。核对结论：**DM07 范围内全部 InlineBanner 调用点
（statistics 13 处、drive_detail 4 处、map_privacy 1 处）原本就只传受限四档值，
无 `info` 旧值、无自由 Color**；本包新增调用点同样只传 `error`。参数类型改用
`MileafStatusTone` 并删除 `BannerTone` 别名需改 `design/components/state_view.dart`
（components/ 禁改），留给 DM08 集成包执行。相应地，本包通过把三页「直接指定
`colors.error` 的反馈文字」迁入 tone 化横幅，消除了包内最后一类绕过受限枚举的取色点
（`currency.dart` 的 `colors.error` 反馈在禁改文件内，登记 §8）。

## 3 MG05b 分组标题 inset 迁移清单

| 页面 | 调用点 | 处理 |
| --- | --- | --- |
| 设置 `settings_page.dart` | 使用偏好 / 当前站点 | 已由 settings-order 迁移（`inset: MileafSpace.cardPad`），核对确认 |
| 地图设置 `map_privacy_page.dart` | 本机配置 / 申请帮助 / 地图隐私 | 已由 settings-order 迁移，核对确认 |
| 连接管理 `connection_management.dart` | 当前连接 / 本机访问 | 本包迁移：两处传 `inset: MileafSpace.cardPad`（标题原落页面边距，卡内行起始线在页面边距 + 16，属 R24 两条起始线偏差） |
| 停放专题 `statistics_parking_page.dart` | 每段停车 / 停车时状态 / 停放记录 | 核对确认无需迁移：前两者在 `MileafModuleCard`（默认 `cardPad` 内边）内、第三者已有 `cardPad` 水平包装，均已在卡内起始线上 |
| 服务信息（MetaPage） | 位于 `overview_page.dart`（他人持有，禁改） | **跳过，登记由 DM05 处理** |
| 币种页 `currency.dart` | 无 `MileafGroupHeader` 调用点；且文件不在本包清单 | 无需迁移，登记确认 |

新增守卫：`connection_management_test` 断言本页全部 `MileafGroupHeader.inset == MileafSpace.cardPad`。

## 4 MG04 图标接线结论

- 按 icons.md §1.2 盘点表核对：DM07 范围页面**页面直绘图标 = 0、Material Icons = 0**
  （`grep 'Icons\.'` 与自绘 painter 复查均无）；仅存的自绘 painter（`_TemperaturePlot` /
  `_ParkingPainter` / `_StateSegmentPainter` / `_RangePainter` / `_UsagePatternPainter`）
  均为数据图形，已在 icons.md §1.3 登记「不纳入家族」。
- hero 状态图形：统计与设置、连接、详情页无 hero；家族 `bolt/moon/offline` 已在
  `design/components/hero.dart` 走统一出口（icons.md §1.4），**登记「已满足」**。
- 统一出口迁移：DM07 范围 9 个直接 `import 'design/icons.dart'` 的页面全部改按
  `import 'design/components/icons.dart'`（MG04 统一出口）消费；`components/icons.dart`
  是纯再导出桥接，视觉与 API 零变化。

## 5 copy guard 基线变化

新文案只来自「空态分档现状句/动作」与「重试对象名」结构行，未复活任何旧串；
基线按结构上调（允许范围内登记）：

| 基线 | 变化 |
| --- | --- |
| statistics_usage_page.dart.txt | 81 → 84 |
| statistics_conditions_page.dart.txt | 50 → 51 |
| statistics_charging_page.dart.txt | 59 → 61 |
| statistics_range_page.dart.txt | 37 → 40 |
| statistics_parking_page.dart.txt | 47 → 50 |
| statistics_insights_page.dart.txt | 113 → 114 |
| connection_page.dart.txt | 15 → 17 |

其余 DM07 文件计数不变。CP12 冻结文案（HTTP 信任、退出设备说明、推荐 HTTPS 句等）逐字未动。
**已知非本包缺口**：`apple_polish_copy_guard_test` 当前唯一失败为 DM05 在途
`drives_page.dart`（46 > 基线 45），与本包无关。

## 6 测试更新与结果

- 结构映射更新（未放宽业务断言）：空态文案断言 2 处
  （statistics_usage / statistics_charging → 四档现状句）、图册 markers 4 组
  （topic-rhythm/energy/charging/range 的 empty must 与 normal mustNot）、
  setup_test 增加横幅类型断言；statistics_usage / statistics_charging 增加空态动作
  「刷新」断言；connection_management 新增 inset 断言。
- 新增 `test/days_migration_dm07_test.dart`：连接页检查失败（状态条 + 重试动作 +
  语义对象名 + 重试真实再请求）、统计首页能力读取失败（状态条 + 重试能力）。
- 锁内结果：
  - `analyze`：**本包文件 0 诊断**。全库残余 4 条均在包外：`creator/` 工作区 2 条、
    DM05 在途 `drives_page.dart` unused_import 1 条、`apple_polish_ap10_test` 既有 info 1 条。
  - 第一批（dm07/statistics_usage/charging/conditions/range/parking/setup/connection_management）：
    全过；第二批（statistics/insights/embedded/a_statistics/session/settings_navigation/
    drive_detail 三件/charging_statistics/overview_statistics_reading/days_migration_state/
    days_migration_color_guard/apple_polish_copy_guard）：仅 copy guard 的
    `drives_page` 基线失败（DM05 在途），其余全过。

## 7 MG02 图形取色核对（对照映射表；异常只登记，不在本包改色）

| 图形 | 取色 | 对照 MG02 映射表 | 结论 |
| --- | --- | --- | --- |
| 停放·状态占比条 `_StateSegmentPainter` | online=accent 实色；asleep/offline=textFaint 实色 + 斜线/点纹（纹理刻色 canvas）；未知=空底 + lineStrong 描边 | online 属「进行中=accent」状态语义（占比条主数据系列，豁免）；睡眠/离线/未知全部中性，无彩色信号 | 合规 |
| 停放·趋势柱/点 | accent 柱与点、选中白底点 + textSecondary 选中线、网格 line、缺失留槽 | 主系列豁免；选中标记计入预算；缺失不补零 | 合规 |
| 温度点图 `_TemperaturePlot` | accent 点（adequate 实心 / 其余空心描边）、选中 halo accent 20%、缺失组不画点 | 主系列豁免；「样本不足」用空心形状编码置信度，未引入 warning/彩色信号；缺失=不渲染 | 合规 |
| 能耗分类条 `MileafCompositionBar`（共享组件，只读核对） | seriesPrimary / seriesSecondary / seriesNeutral；缺失分类不进条，图例 `—` textSecondary | 主数据系列豁免；「未知」分类走 seriesNeutral 中性系；缺失走中性旁注 | 合规 |

**待裁定（登记，不改色）**：`_StateSegmentPainter` 纹理刻色固定用 `colors.canvas`，
但占比条宿主是 `surface` 卡面（`MileafModuleCard`），浅色（#F4F5F7 vs #FFFFFF）与深色
（#0A0B0D vs #12161C）刻线与卡面均有轻微明度差。属纹理层取值问题，非映射表违规；
如需整改建议改按宿主取 `surface` 或由组件显式传入宿主底色，需用户裁定。

## 8 遗留

1. **登录页三要素**：`session_pages.dart` 不在 DM07 文件清单，登录失败反馈仍是
   页面直定 error 色文字；建议 DM08 或后续页面包补齐。
2. **币种页反馈**：`currency.dart`（禁改清单）的 `colors.error` 保存失败反馈未 tone 化。
3. **`BannerTone` → `MileafStatusTone` 改名**：需编辑 `design/components/state_view.dart`
   （components/ 禁改），随 DM08 收口；届时本包调用点可直接换名。
4. **离线档触发路径**：页面层无连通性信号，「网络不可用，显示的是缓存数据」档暂无
   真实触发点；如需落地须先在数据层定义连通性状态（跨包工程，需立项）。
5. **服务信息 MetaPage inset**：在 `overview_page.dart` 内，由 DM05 处理。
6. **MG01 量化图册**：本包登记行为估算法结论，精确像素量化待 DM08 重采全库图册后修订。
7. **停放纹理刻色**：见 §7 待裁定项。
