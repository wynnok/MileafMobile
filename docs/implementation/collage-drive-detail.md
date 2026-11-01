# C 行程详情实施（#10）

2026-10-30，基于 C 数据拼贴增量及 ADR 0001。地图满幅开场，随后为路线/时间、薄荷色距离/时长/估算净电耗结果、SOC 区间与个人历史参照、速度/电量/海拔过程；驾驶与环境、更多指标在下方。沿用共享 collage.dart，不修改地图供应商、坐标契约、网络授权、API 或后端。净能量等全部原有指标在更多层保留。

地图不可用时保留紧凑真实说明，不用空白大地图占位；真实地图绘图区为 300 逻辑像素。技术长说明保持在参照帮助和更多层。

2026-10-31 视觉修正（用户反馈）：地图此前左右出血、仅下缘圆角，与 12px 页面边距的其他模块割裂。现行程详情地图与内容同栏（左右 12px、上 12px、下 8px），四角 20px 圆角，高度仍 300；充电详情地点图同步 20px 圆角并补 8px 下距；全屏 `DriveMapPage` 仍满宽、仅下缘 22px 圆角。`drive_detail_test` 改为断言地图左右边距与「距离」tile 一致。

2026-11-01 文案与图册同步：`c_gallery_render_test.dart` 的路线脚注断言改为现行文案「路线 · 非导航」（原 C05／原型为「路线示意 · 非导航」），并只在 100% 断言——≥150% 时该脚注按 `if (!large)` 整行不绘制，本次补上 200% 的「不出现」断言。**待办**：421fe61（AMap 接入）把说明带从「地图下方说明带」并入地图 hero 的叠加层，同时缩短了脚注文案；C05 的「路线示意 · 非导航」与降级说明带尚未恢复（原型 `prototype.js:1388`、`style.css:1407` 与 C10 证据 `latest-drive-detail-dark-200.png` 均为原文案），恢复与否由产品决定，同时需恢复被 421fe61 删除的 `drive_map_test` 级别断言。当前覆盖由 `c_gallery_render_test.dart`（100%）与 `drive_detail_test.dart` 的降级用例承担。

## 验证

- TDD：新增 App＋可控HTTP测试先失败（地图168位于标题72之后），实现后验证地图在路线之前、左右满幅（2026-10-31 改为 12px 页面边距，见上）；未新增内部测试接口。
- 定向 drive_detail_test、drive_map_test 与独立渲染共26项通过；0/1/null、局部恢复、404、304、切车/会话隔离、地图选点仍通过。
- flutter analyze：No issues found。
- 正式 Flutter 图册48张：normal/empty/missing × light/dark × 100/200 × map/result/chart/environment，位于 collage-renders/drive-detail。empty 指空序列，不伪造不存在的详情空态；missing 保留未知值。正常地图使用可控HTTP透明测试瓦片和合成坐标，仅证明满幅绘制与轨迹，不证明真实底图。空/缺失图展示未配置地图的真实降级。
- 检查代表图 normal-light-100-map、normal-dark-200-result、missing-light-200-environment，无横向溢出；渲染每个截屏均检查Flutter异常。

复现：MILEAF_FLUTTER_SDK 指向原项目 .tooling/flutter，以 tool/flutterw test --no-pub 执行 test/drive_detail_test.dart test/drive_map_test.dart test/collage_drive_detail_render_test.dart；渲染传入 MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/drive-detail 与 MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf 的 dart-define。

真实底图供应商/CRS/许可、双端网络、真实站点/真机/辅助功能外部验收继续待验。未推送、部署、改票或关闭工单；全量集成/双端构建留给#17。
