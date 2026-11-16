# Apple 风格焕新能力迁移

原 104 项业务能力以[UI/UX refinement capability map](../ui-ux-refinement/capability-map.md)为规范清单，最终归宿以其 U12 区段为准。本轮不新增业务能力，也不改变 104 项的身份、数据条件、请求、回退与测试入口。

| 新呈现能力 | 当前入口 | 目标归宿 | 主要验证 |
| --- | --- | --- | --- |
| A11 排版层级 | MileafType / MileafTextStyles | R12 完整角色表与二级导航独立角色 | design tokens、全页大字矩阵 |
| A12 同调车况表面 | MileafHero / overview status surface | surface/text/textMuted 与 24 圆角 | 概览浅深正式渲染 |
| A13 磨砂导航材质 | 实色 MileafNavBar | NavigationMaterial 的 blur/solid 双路径 | 材质组件与减少透明度测试 |
| A14 浮动根导航 | Scaffold bottomNavigationBar | 16 外距、8 安全区上距、最大 528、单一选中底 | 导航几何、遮挡与连续切换 |
| A15 统一根上下文 | 页面注入 topBar | 根页共用上下文与统计嵌入顶栏互斥 | 四 Tab 与统计下钻返回 |
| A16 微动效语言 | 旧 R07 时长 | M01–M08 参数、打断和即时语义 | widget 逐帧与减动效 |
| A17 图表读值关系 | 共享图表和专题 Painter | 160/200 图面、88 节奏、选择和证据邻接 | 正负/零/null/极值图板 |
| A18 显示偏好 | MediaQuery disableAnimations/highContrast | 独立 reduceMotion/highContrast/reduceTransparency | Flutter controller 与 iOS 通道 |
| A19 状态完整性 | 共享 StateView 与页面分支 | loading/empty/error/full 和刷新快照 | 页面状态与可控 HTTP |
| A20 内容遮挡测量 | 固定 bottomNavigationBar 占位 | 实际浮栏尺寸用于滚动余量和焦点 reveal | 末记录、键盘和安全区 |

费用补录、地图、认证、连接、统计时间窗口与阅读恢复继续引用原能力 ID。任何呈现迁移只有在原入口、目标入口和既有行为测试同时存在时才记为完成。
