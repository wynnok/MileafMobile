# 理念迁移增量双轴审查（days-matter-migration）

> 2026-11-19。固定点 `cadeee2`，对象 `cadeee2...HEAD`（7658a57 / c2af0c6 / 738ff58 / b646320）加工作树未提交部分。两轴由独立子代理并行执行（本文件为主会话汇总），发现分级与处置如下。

## 规格轴（MG01–MG09 / DM00–DM08 / D1–D4）

| 项 | 判定 | 要点 |
| --- | --- | --- |
| MG02 状态取色映射 | 符合 | `MileafStatusTone` 唯一映射；neutral 永不彩色 token 级守卫；BannerTone 四档转发 |
| MG03 对比度守卫 | 符合 | 60 用例；textFaint 现值保留裁决；4 条豁免组合按记录性测试登记待裁定；overview-reading 批注订正 |
| MG08 数值统一淡化 | 符合 | MileafNumber AnimatedSwitcher 120ms；时长集合七档零增减（D3）；减动效归零；拖动即时；PD13/R07 上游登记一致 |
| D1–D4 | 符合 | s12（页面接线在工作树）、受光带默认关未动、时长集合未动、无墨色 hero |
| 不迁移清单 | 符合 | 无参考 App 元素层痕迹（零新增色值/字阶/圆角/时长/图标瓦片/弹簧参数） |
| MG01 彩色面积 | 部分符合→口径已修订 | 登记表全页 ≤20%（估算法）；图册口径按规格 §9.1 修订；「DM08 重采全库图册」悬空声明已删除 |
| MG04 图标家族 | 部分符合→口径已修订 | 出口/参数/语义已交付；golden 按 opt-in 图板口径登记（§9.2）；barrel 导出待在途 barrel 落地补 |
| MG05 记录行句法 | 符合（在工作树） | 与充电行同构三格 metricSm；360/200% 用例与图册齐；未提交边界已声明 |
| MG05b inset | 部分符合→两处豁免核实为画布层正确形态 | §9.5 登记非例外；currency.dart 禁区仅登记 |
| MG06 s12 | 部分符合→口径已修订 | gap==s12 测试断言 + after 图册；before 截图豁免（§9.3）；测试随页面包落地（见标准轴发现 1 处置） |
| MG09 状态三要素 | 部分符合→口径已修订 | 连接页无缓存数据场景，验收字面按 §9.4 修订；「数据截至」用例由概览/充电详情承担 |
| MG07 材质守卫 | 原不符合→**已补齐** | tickets 原漏认领；DM08 补 `test/days_migration_material_guard_test.dart`（3 用例全绿，排除集含 page_bar/b barrel 转发） |

## 标准轴（R32/R10/S01–S08/AGENTS + Fowler 基线）

**核过无问题**：裸值纪律（页面零新增、state_feedback 0 裸值基线）；copy guard 基线全部随结构登记无旧文案放行；S01–S08 契约 0 变更（无 .g.dart/pubspec 变更、无新请求类型/参数、补录状态机未触碰、路由回调与 Key 零删改、BannerTone.info→neutral 零视觉变化）；测试断言映射无业务语义放宽；MG02/MG03 守卫；icons 桥接 TODO 留痕；术语走共享构造（DF4/CP 句式）；规格登记（PD12/PD13、R07）一致。

**发现与处置**：

1. 【阻塞】提交自洽：已提交 motion 测试引用未提交 `MileafPeriodHeader`/页面接线，HEAD 树无法编译。**处置**：MG06 间距断言拆出为 `test/days_migration_spacing_test.dart`（工作树，随 DM05 页面接线与在途切片一并提交）；`days_migration_motion_test.dart` 瘦身为纯组件级 MG08 用例（HEAD 可编译）；tickets 头部与实施记录「工作区状态」补充「HEAD 树需叠加在途改动方可全绿」的显式声明。**遗留决定（需用户裁定）**：在途切片（period-header、apple-polish AP 系列）与 DM05 两页改动的落地提交方式。
2. 【阻塞→已修复】`connection_page.dart` HandshakeException 分支漏置 `failed`，证书校验失败被渲染为成功样式。**处置**：补 `failed = true`；新增用例「MG09 连接页证书校验失败：走失败状态条而非成功句」（MockClient 抛 HandshakeException，断言 error 状态条 + 重试）。
3. 【建议→已修复】充电记录空态与页尾错误条双报失败。**处置**：`_recordsSection` 失败分支回退为空白语义（`error != null || !loaded` 不渲染模块句），三要素由页尾错误条承担；相关注释更新。
4. 【建议→候选】约 9 处失败横幅五元组接线重复（`InlineBanner.errorRetry`/`retrySemantic`/`asOfLineOrNull` 助手收口）——列为后续候选，本增量不阻塞。
5. 【nit】连接页双布尔编码三态（`_MessageKind` 枚举）——候选。
6. 【nit→已修复】验证结论未标注混合工作树前提——实施记录已补显式声明。
7. 【nit】MG06 测试提前提交（与发现 1 同根）——已按拆分处置。

## 结论

两轴阻塞项全部处置完毕（1 拆分、2 修复、3 修复、6 补记），MG07 守卫补齐后规格轴不再有不符合项；其余为已登记候选/待用户裁定（textFaint 4 条豁免组合、停放纹理刻色、在途切片落地方式）。修复后 `tool/flutterw test` 全量结果见 [days-matter-migration.md](days-matter-migration.md)「验证」节。