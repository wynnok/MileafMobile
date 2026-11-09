# 自备高德地图 Key 实施记录

- 日期 2026-11-09
- 工作分支 `main`，审查基线 `1808f57ea85e137ccdbf11c4e9a1fb110f2f1898`
- 用户确认 ADR 后授权继续完成实施，Spec、Ticket、教程与实现一并交付。

## 已交付

| 任务 | 结果与证据 |
| --- | --- |
| MK01 本机配置 | [MapKeyController](../../lib/src/map/map_key.dart) 独立安全存储、启动恢复、进程 Key 快照、清除、错误恢复与并发互斥 |
| MK02 设置表单 | [MapPrivacyPage](../../lib/src/map/map_privacy_page.dart) 使用正式主题与共享组件，提供遮挡输入、更换、取消、清除确认与重启提示 |
| MK03 申请帮助 | 双端 `getBinding` 读取安装包实际包名／签名 SHA-1 或 Bundle ID，逐项复制与失败重试 |
| MK04 原生接入 | [Android](../../android/app/src/main/kotlin/app/mileaf/mileaf/map/AmapPlatformView.kt) 与 [iOS](../../ios/Runner/AppDelegate.swift) 在同意后接收用户 Key，`getProcessKey` 支持同进程 Engine 重建恢复，旧构建注入退出使用 |
| MK05 地图降级 | [MapPanel](../../lib/src/map/map_panel.dart) 缺配置直接速写、统一设置入口、清除卸载、旧代次回调隔离。入口沿用 `MileafDataRow`，修复仅标题导航行缺失箭头的问题并保留禁用行行为 |
| MK06 教程 | [申请教程](../tutorial/amap-key-application.md)、[设置教程](../tutorial/amap-key-settings.md)，README 已增加入口 |
| MK07 验证 | 配置、组件、正式渲染、双端编译及独立双轴审查，结果见下文 |

设计依据见 [ADR 0008](../adr/0008-user-amap-key.md)、[Spec](../specs/user-amap-key.md) 与 [Ticket](../specs/user-amap-key-tickets.md)。

## 自动化与渲染

- `test/map_key_test.dart` 覆盖保存、更换、清除、格式、失败保留、冷启动、同进程 Engine 重建、读取重试、销毁和并发互斥。
- `test/map_key_page_test.dart` 覆盖缺配置阻止地图创建、详情进入设置、保存返回、清除后旧回调、延迟绑定读取与复制、320 宽双倍字号、iOS 标签及保存失败恢复、读取失败恢复。
- 已有隐私同意测试显式注入合成 Key，继续检验原来的同意门和大字号排版。共享测试夹具位于 `test/support/map_key_fixture.dart`。
- 正式 Flutter 组件 [图册](map-key-renders/README.md) 共 12 张，浅深各含未配置、已保存、待重启、申请帮助、320 宽双倍字号与键盘展开。
- 最终 `tool/flutterw analyze --no-pub` 无诊断。`tool/flutterw test --no-pub` 为 468 通过、7 跳过、0 失败，额外夹具复验 22 通过。格式与 `git diff --check` 通过，交付文档相对链接检查通过。

## 双端隔离编译

Android 使用项目既有 `tool/flutterw android assembleDebug`，Gradle 由项目隔离入口启动，最终复验 `BUILD SUCCESSFUL in 41s`，完整入口退出 0。

iOS 当前环境缺少 CocoaPods，`tool/flutterw build ios --release --no-codesign` 在依赖检查阶段停止。项目已有 `ios/Pods`，且 `Podfile.lock` 与 `Pods/Manifest.lock` 一致，本次没有依赖变更。改用同一 `tool/build-sandbox.sb` 与 `tool/build-sandbox-probe.rb`，在四项探针全部通过后运行无签名原生编译。

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build/ios-map-key-derived CODE_SIGNING_ALLOWED=NO build
```

该命令由相同进程沙箱包裹，沿用项目缓存环境与主机 SDK 保护。实际结果为 `BUILD SUCCEEDED`。产物位于 `build/ios-map-key-derived/Build/Products/Release-iphoneos/Runner.app`。CocoaPods 缺失仍是完整 Flutter iOS 构建入口的环境限制，原生编译结果与该限制分别记录。

## 双轴审查

### Standards

独立审查发现异步存储完成后可能通知已销毁控制器。已增加 `_disposed` 防护并以延迟恢复回归验证，复核结清。剩余硬性问题 0，判断性问题 0。

### Spec

独立审查发现 Android 同进程重建 FlutterEngine 后，Dart 可能丢失 SDK 进程 Key 快照。已加入双端 `getProcessKey`，恢复阶段同步原生状态，新增更换与清除后 Engine 重建回归，复核结清。剩余问题 0。

## 外部待验

真实 Key 授权、真机安全存储持久化与清除、双端真实底图、CRS、大陆网络及性能保持独立验收。截图使用合成配置。构建覆盖源码编译。
