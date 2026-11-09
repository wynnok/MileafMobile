# 自备高德地图 Key 实施任务

依据 [ADR 0008](../adr/0008-user-amap-key.md) 与 [设计 Spec](user-amap-key.md)，本轮按用户「确认。继续完成实施」授权执行，任务以本文本地追踪。

| 编号 | 范围与对应文件 | 验收标准 |
| --- | --- | --- |
| MK01 | `map_key.dart`、`main.dart` 本机配置 | 独立安全存储，冷启动恢复；保存与删除失败保留原值；并发写入互斥；更换后显示待重启 |
| MK02 | `map_privacy_page.dart` 设置表单 | 遵循现有浅深主题与 token；默认遮挡；显式更换、取消、清除确认；错误保留输入；键盘和 200% 字号可达 |
| MK03 | `MainActivity.kt`、`AppDelegate.swift` 绑定信息 | 当前安装包包名与签名 SHA-1 或 Bundle ID 可复制，失败可重试；读取身份过程独立于地图 SDK |
| MK04 | 双端平台适配器、原生视图与构建配置 | 用户 Key 在原生地图创建前注入；同意门生效；进程锁定 Key；旧构建注入来源退出使用 |
| MK05 | `map_panel.dart`、`overview_page.dart` 地图入口 | 统一地图设置入口；无 Key 直接速写；清除卸载地图；加载失败可重试及进入设置；空坐标语义保留 |
| MK06 | `docs/tutorial/` | 申请与设置教程完整覆盖双端、绑定、保存、更换、清除、隐私与常见错误，配合正式页面截图 |
| MK07 | `test/map_key*` 与实施记录 | 配置与组件回归、浅深真实 Flutter 渲染、全量 analyze/test、双端隔离构建和双轴代码审查，记录实际结果与外部待验 |

交付状态与证据统一记录在 [实施记录](../implementation/user-amap-key.md)。
