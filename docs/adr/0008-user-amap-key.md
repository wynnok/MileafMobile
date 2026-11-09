# 自备高德地图 Key 与本机地图设置

- 日期 2026-11-09
- 状态 accepted，用户于 2026-11-09 确认并授权继续完成实施
- 关系 以 ADR 0003 的版面语言、ADR 0006 的外观 v2 为视觉基线，调整 ADR 0002 的构建期 Key 来源与配置入口。

## 已确认的产品边界

用户在本会话确认以下三项。

1. 用户自备 Key。未配置时显示路线速写与配置入口。
2. Android 与 iOS 同步支持。配置仅存当前设备，同设备所有车辆与连接站点共用。
3. SDK 已初始化时，更换 Key 可在重新启动 App 后生效，页面清晰表达待重启状态。

以下 D1–D7 已随本 ADR 确认。本轮用户进一步授权继续完成实施，Spec、Ticket、教程与实现一并交付。

## 当前代码与视觉判断

| 事实 | 代码或证据 | 对本次设计的影响 |
| --- | --- | --- |
| 电光蓝、中性浅深底、图形与文字强调色分层已成立 | [tokens.dart](../../lib/src/design/tokens.dart)、[semantic.dart](../../lib/src/design/semantic.dart)、[ADR 0006](0006-appearance-and-accent.md) | 配置页沿用既有材质和层级 |
| 业务页已有正式浅深渲染 | [外观 v2 图册](../implementation/appearance-v2-renders/README.md) | 本次以相同字体、模式和缩放条件复验 |
| 连接管理页以 `MileafDataRow` 承接外观等入口 | [connection_management.dart](../../lib/src/connection_management.dart) | 新设置入口复用细线行组件 |
| 「设置与服务」内已有「地图与隐私」入口 | [overview_page.dart](../../lib/src/overview_page.dart) 的服务信息页 | 现有入口可以直接承接本次功能 |
| 地图隐私页仍使用固定 24 边距、Material 复制图标和默认文本排版 | [map_privacy_page.dart](../../lib/src/map/map_privacy_page.dart) | 需要在本模块内补齐当前视觉语言 |
| Android 从 Manifest 的构建占位符读取 Key，未接入运行时 Key | [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)、[build.gradle.kts](../../android/app/build.gradle.kts)、[AmapPlatformView.kt](../../android/app/src/main/kotlin/app/mileaf/mileaf/map/AmapPlatformView.kt) | 在原生视图创建前注入用户配置 |
| iOS 初始化视图时从 Info.plist 读取 Key | [AppDelegate.swift](../../ios/Runner/AppDelegate.swift) 的 `MileafAMapConfiguration` | 调整为本机用户配置来源 |
| 地图状态已有同意、空数据、加载、成功与失败 | [map_panel.dart](../../lib/src/map/map_panel.dart) | 配置缺失、待重启需要独立状态 |
| 安全存储依赖已存在 | [session.dart](../../lib/src/session.dart) 的 `SecureSessionStore`、[pubspec.yaml](../../pubspec.yaml) | 可复用依赖并单独保存地图配置 |

当前产品的精致感来自有节制的强调色、数字与文字层级、稳定的行节奏。地图配置页采用同一套页面和表单语法，申请所需技术信息逐层展开。

## 输入会话与接口核对

已读取「充电费用缺失方案调整」会话。该会话新增接口如下，当前 App 已在 `charging_cost.dart` 接入。

| 项目 | 已核实契约 |
| --- | --- |
| 方法与路径 | `PATCH /v1/charging-sessions/{session_id}/cost` |
| 鉴权 | 现有 Bearer 认证 |
| 请求 | `{"unit_price":"1.250000"}` |
| 成功响应 | `session_id`、`unit_price`、`billing_energy_kwh`、`cost`，十进制值以字符串返回 |
| 写入条件 | 已结束且 `cost` 为 null，按两类电量中较大可用值计算总费用 |
| 主要错误 | 403 功能未启用，404 无记录，409 已有费用或无法计费，400/422 参数错误，503 数据库授权缺失 |

参考 [后端 ADR 0004](../../MileafServer/docs/adr/0004-limited-charging-cost-writes.md)、[OpenAPI 0.4.0](../../MileafServer/docs/api/openapi-0.4.0.json)、[App 提交入口](../../lib/src/charging_cost.dart) 与 [响应 DTO](../../lib/src/charging_cost_contract.g.dart)。会话最后记录的部署版本为 `f9cf6a6`、补录已启用，这是历史会话信息。

本次地图方案的接口增量位于 Dart 与原生平台之间。拟增加应用级配置桥接，获取当前安装包绑定信息、设置本进程使用的 Key、返回 SDK 是否已经初始化。具体通道名、字段、错误类型在 Spec 冻结。Key 的有效性由原生地图实际加载结果反馈。

## D1 一个设置入口，一张专属页面

提议将既有「地图与隐私」入口改名为「地图」，副文案表达当前状态，例如「未配置 · 使用路线速写」或「已保存 · 重新启动后生效」。入口采用 `MileafDataRow`，沿用 `mapPin` 与 `chevron`，位置保持在「设置与服务」原地图入口处。

点击进入独立页面。自上而下依次为「地图」标题、配置状态与一句解释、Key 表单、申请帮助、地图隐私。独立页面能容纳键盘、可复制绑定信息和双端教程，保留清晰的返回路径。

隐私管理在同页下方分组。填写 Key 与允许高德处理地图数据各自有明确状态与动作。已有地图同意记录沿用 `MapConsentController` 的供应商语义。

修改集中在 `overview_page.dart` 的入口及 `map_privacy_page.dart` 的内容，连接管理页的其他设置继续复用现状。

## D2 原有视觉 token 直接落到每个元素

| 元素 | 拟采用的规则与原因 |
| --- | --- |
| 页面与分组 | `MileafContent` 最大宽 560，`pageInset` 在宽度小于 390 时为 20，390 起为 24。组间 28，组内采用 8/12/16/20 档位，延续现有留白节奏 |
| 材质 | canvas 页面、surface 输入面、line 分隔线。配置状态使用文字与细线建立层级 |
| 标题 | `type.title`，18/22、600，与已有 AppBar 标题一致 |
| 输入与关键说明 | `type.body`，13/19.5。申请步骤、错误、重启提示均用可缩放正文 |
| 次要信息 | 分组短标签用 `type.label`。绑定值采用正文，允许换行及选择复制 |
| 输入框 | 复用 `InputDecorationTheme`，12 圆角、横向 16／纵向 12 内边距、focusRing 2、错误语义色 |
| 主操作 | 复用现有主按钮，`accentStrong` 底与 `textOnAccent` 文字、10 圆角、至少 44 高。主要动作为「保存 Key」 |
| 次操作 | 教程、显示或隐藏 Key、复制绑定信息采用现有文字／图标按钮层级，触达面积至少 44×44 |
| 图标 | 沿用 `MileafIcon` 的 24 网格、1.5 线宽，页面图标 20/24，行内 16 |
| 状态 | 默认正文与次级文字表达已保存；warning 仅用于待重启，error 仅用于错误；每种状态均附明确文案 |
| 动效 | 使用现有路由与 `MileafDurations`，状态轻量过渡遵循减少动态效果偏好 |
| 自适应 | 单列排版。320 宽与 200% 字号时说明换行、按钮与输入区域增高，键盘出现后保存动作可滚动到达 |

来源为 [tokens.dart](../../lib/src/design/tokens.dart)、[theme.dart](../../lib/src/design/theme.dart)、[typography.dart](../../lib/src/design/typography.dart)、[layout.dart](../../lib/src/design/layout.dart)、[data_row.dart](../../lib/src/design/components/data_row.dart) 与 [icons.dart](../../lib/src/design/icons.dart)。逐元素位置、状态图及像素验收矩阵在 Spec 固化。

## D3 只填写当前平台所需的一个 Key

页面根据当前运行平台标明「Android 地图 Key」或「iOS 地图 Key」。输入区默认隐藏内容，提供带语义标签的显示切换。关闭自动纠错与输入建议，剪贴板由用户主动粘贴。

已有配置显示脱敏摘要。编辑时通过显式动作进入替换，草稿与已保存值分开管理。保存失败保留草稿与原配置，保存成功后收起键盘并更新状态。清除配置使用独立次操作与确认对话框，空输入通过表单提示处理。

申请帮助先显示「如何申请 Key」。展开后呈现当前平台所需的绑定信息与教程。Android 从当前安装包读取包名及签名证书 SHA-1，iOS 从当前安装包读取 Bundle ID；每项均可单独复制。读取失败提供可重试错误状态。

当前代码的包名与 Bundle ID 为 `app.mileaf.mileaf`。教程仍以页面实时展示的信息为准，覆盖用户自编译、重签名或未来不同发行渠道。Android 当前 release 配置使用 debug signing，固定写死某个发布证书摘要会误导用户。

高德申请要求按平台绑定应用。Android 使用包名与签名 SHA-1，iOS 使用 Bundle ID。申请步骤分别引用 [Android 官方说明](https://developer.amap.com/api/maps-sdk-for-android/guide/create-project/get-key) 与 [iOS 官方说明](https://developer.amap.com/api/ios-sdk/guide/create-project/get-key)。

## D4 保存状态、初始化状态与地图结果分别表达

| 场景 | 拟采用的行为 |
| --- | --- |
| 首次未配置 | 页面显示「未配置」，地图展示路线速写与「配置地图」入口 |
| 首次保存，SDK 尚未初始化 | 本机保存成功后可供下次打开地图使用；地图同意流程单独执行 |
| SDK 已初始化后更换 Key | 显示「已保存，重新启动 App 后生效」。保留本进程原配置快照，页面说明本次运行仍使用原 Key |
| 清除已保存 Key | 清除成功后卸载当前地图视图并阻止创建新视图，回到路线速写；SDK 已初始化时提示重启可结束已加载的 SDK 状态 |
| 保存或清除失败 | 原持久化配置保持有效，表单保留可恢复状态并提供重试 |
| 已有 Key，尚未同意 | 显示已配置与未允许加载底图两个事实；继续通过既有同意流程启用 |
| Key 读取失败 | 显示「地图配置读取失败」与重试入口，保持路线速写 |
| 网络、授权或加载超时 | 地图回到速写，提供重试与配置入口。具体原因仅在 SDK 能可靠区分时展示 |

「已保存」只表达本机写入结果。底图加载成功由现有原生加载回调反馈，配置页可展示本次运行最近的加载结果。首次配置缺失在 `MapPanel` 中直接分流，避免走满现有 15 秒超时。

重启指结束进程后重新打开，页面返回、切到后台与 Flutter widget 重建均不能消除待重启状态。以本进程有效配置和最新保存配置的差异计算待重启状态，改回原值后清除提示。

官方资料展示了 Android `MapsInitializer.setApiKey` 与 iOS `AMapServices.apiKey` 的初始化接入方式。运行中换 Key 的完整行为仍需结合仓库固定 SDK 验证，因此采用已确认的重启生效边界。[Android 官方 FAQ](https://lbs.amap.com/faq/android/map-sdk/create-project/46723)、[iOS 官方入门指南](https://developer.amap.com/api/ios-sdk/gettingstarted)

## D5 本机配置拥有独立生命周期

提议复用 `flutter_secure_storage`，以独立记录保存当前平台 Key，并沿用本设备访问级别。登录、退出、切换车辆及切换站点均保留地图配置，清除动作由地图页显式提供。

初始化时先恢复本机配置，再允许地图视图创建。读取安装包绑定信息只使用系统包信息接口。SDK 初始化继续位于已有隐私同意门之后。

地图 Key 通过专用配置桥传递，场景 wire 继续只承载地图场景。日志、错误文案与截图夹具使用脱敏值。地图配置的写入先完成持久化，再发布已保存状态。

迁移后原生地图统一消费用户 Key。需要同步审视 Android Manifest 占位符、iOS plist 读取和旧构建教程，确保旧包升级后，缺少本机配置的用户进入清晰的自备 Key 流程。

## D6 路线速写承担完整的未配置体验

`MapPanel` 保留地图原有尺寸、路线与起终点表达，在既有状态提示区域加入简短说明与配置动作。行程、充电详情与全屏地图共用同一配置状态。

有坐标时显示速写；源数据缺少坐标时继续表达原有空数据语义。配置入口进入同一地图设置页，返回后重新读取状态。每次详情进入通过轻量状态提示表达配置需求。

## D7 设计确认后的交付与验收

下一份 Spec 将锁定未配置、已保存、编辑、待重启、保存失败、配置读取失败、加载失败、清除确认、隐私未同意等状态，并为浅深模式、320/360/390 宽、100%/200% 字号与键盘状态给出尺寸和截图要求。

Ticket 随后按设置入口与页面、本机配置与状态、双端桥接、地图降级与导航、教程与验证拆分。测试覆盖配置状态与存储失败、真实组件的表单和导航、可控原生通道的契约。正式 Flutter 渲染验证样式，双端 SDK 的真实初始化与 Key 授权另行验证。

设计确认后交付两份教程，申请教程覆盖账户准备、平台选择与绑定信息，设置教程覆盖保存、隐私同意、待重启、更换、清除与常见错误。截图使用合成 Key，教程与最终界面文案一致。

## 取舍与影响

用户承担首次申请成本，个人用量归属通过各自 Key 管理。首次升级需要明显但克制的配置引导。独立页提供操作空间，申请帮助的折叠层级控制首屏信息密度。

重启生效降低 SDK 全局状态切换的不确定性，同时增加更换配置的操作成本。页面必须准确表达保存值与本次运行值。真机、真实 Key、底图、CRS、大陆网络和性能继续独立验收。
