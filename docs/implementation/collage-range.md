# C「数据拼贴」长期续航

2026-10-30，#20 的 C 视觉切片。统计章节卡 → 长期 → 独立续航专题沿用统计承载已有路由和上下文 builder；不改变停车 builder 或 API。独立续航路由明确显示独立 6/12 个本地月窗口，不把首页期间标作观察窗口。

专题以所选月的服务端 P50 为唯一深色主 tile，随后是月中位线、P10–P90 波动带与选月证据。主数跟随图表选月；缺月保留破折号，稀疏只点读，保留有效日、partial 和前后月选择。查询生成时间与完整窗口进入数据说明；query 范围首次采样与会话→日→月方法仍可展开核查。未增加 SOH、衰减、容量、实际可开距离或原始样本分页。

验证：

- 已确认 App＋可控 HTTP 边界的红→绿：先新增独立窗口/主结果断言，旧布局失败，再实施；4 项续航行为测试通过（6/12 月请求、稀疏、缺月、失败重试）。
- 1 项 opt-in 正式 Flutter 渲染通过：360×800、浅/深色、100%/200%、正常/缺月/真实无记录，20 张结果及主图截图保存在 `collage-renders/range/`。无 Flutter overflow 异常。已直接检查正常浅色主数、深色200%图、缺月200%图与空态200%；修正主 tile 数字对比度及渲染图标字体。
- `flutter analyze --no-pub` 对 range 页面和两项测试文件通过，无问题。

复现使用原项目 `.tooling/flutter`（`MILEAF_FLUTTER_SDK`），本工作树项目内缓存：`tool/flutterw test --no-pub test/statistics_range_test.dart test/collage_range_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/range '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。

真实站点、真机、Grafana 对照与用户视觉验收保持待验；未推送、部署或关闭工单。C 图册取代此切片 A 布局证据，不代表上述外部验收已通过。
