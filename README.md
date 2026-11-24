# 行笺 · Mileaf Mobile

行笺是面向 TeslaMate 用户的 Android 和 iOS 客户端。通过自托管的 [Mileaf Server](https://github.com/wynnok/MileafServer)，用图表、地图和关键数字阅读车辆状态、行程、充电和长期趋势。

当前源码版本为 **0.1.3+4**，最低运行版本为 Android 7.0（API 24）和 iOS 15。首版已完成维护者真机验证并收口，GitHub 当前提供源码，暂无官方安装包或商店发布。验收记录见 [首版 Issue](https://github.com/wynnok/MileafMobile/issues/1) 和 [双端集成 Issue](https://github.com/wynnok/MileafMobile/issues/17)。

## 能做什么

- **概览**查看最近一次采集的车况、电量和续航，比较期间里程、能耗和补能。
- **行程**按日期查找记录，查看路线及速度、电量、海拔曲线。
- **充电**浏览会话与地点账目，查看起止电量、充电功率、AC/DC 构成和费用覆盖。站点显式启用后，可补录缺失费用。
- **统计**从总览进入驾驶节奏、能耗、补能、续航、停放和原始统计指标，按期间比较并下钻到记录。
- **多车与外观**在同一站点切换车辆，支持系统浅深色、字体放大与减少动态效果。现行配色见 [天蓝与薄荷](docs/adr/0021-sky-mint-palette.md)。

行笺使用站点访问口令，业务数据默认只读。车辆状态来自 TeslaMate 最近的采样，App 无需 Tesla 账号凭据或手机定位权限。

## 连接站点

1. 在已有 TeslaMate 的环境中部署 [Mileaf Server](https://github.com/wynnok/MileafServer)，按其文档完成站点配置。
2. 在行笺输入可访问的服务根地址。使用反向代理时，保留站点的路径前缀。
3. 使用站点访问口令登录。首次部署可在 App 选择「首次设置站点口令」。登录后在顶部选择车辆。
4. 如需高德地图，在设置里填入对应平台的 Key 并确认使用地图服务。缺少配置或底图加载失败时，行程仍可显示路线示意和过程曲线。参见 [Key 申请](docs/tutorial/amap-key-application.md)和 [App 内配置](docs/tutorial/amap-key-settings.md)。

## 从源码构建

项目使用 Flutter **3.47.7** 和 Dart **3.13.5**。将 Flutter SDK 准备在 `.tooling/flutter`，或设置 `MILEAF_FLUTTER_SDK` 指向已准备好的 SDK。完整环境、JDK 与平台依赖说明见 [工具链](docs/implementation/toolchain.md)。

```sh
git clone https://github.com/wynnok/MileafMobile.git
cd MileafMobile
# 准备项目 SDK 后运行
tool/flutterw pub get
tool/flutterw analyze --no-pub lib test
tool/flutterw test --no-pub
```

仓库支持的原生构建入口在 macOS 上运行。先按 [构建隔离说明](docs/implementation/build-isolation.md)准备项目 Android SDK 和受保护的主机 SDK。主机 SDK 可通过 `MILEAF_HOST_ANDROID_SDK` 指定。Android 还需要 `JAVA_HOME`，iOS 需要 Xcode 和 CocoaPods。

```sh
tool/flutterw android assembleRelease \
  -Ptarget-platform=android-arm64 -Psplit-per-abi=true -Pforce-version-code-ignoring-abi=true

tool/flutterw build ios --release --no-codesign
```

Android 产物为 `build/app/outputs/apk/release/app-arm64-v8a-release.apk`，使用开发签名。iOS 命令生成未签名产物，安装需要自行配置平台签名。

## 文档与反馈

- [项目文档索引](docs/README.md)收录产品范围、API 契约、设计决定和实施记录。
- [开发约定](AGENTS.md)说明仓库结构、验证命令和本地环境约束。
- 通过 [GitHub Issues](https://github.com/wynnok/MileafMobile/issues)反馈问题。请附 App 版本、设备与系统版本、复现步骤，以及相关的 Mileaf Server 版本。可用脱敏截图或合成数据说明问题。

## 许可证

行笺源码采用 **GNU Affero General Public License v3.0**（`AGPL-3.0-only`）。许可证全文见 [LICENSE](LICENSE)。

Copyright (c) 2026 wynnok

随包 Inter 字体采用 [SIL Open Font License](assets/fonts/OFL.txt)，高德地图 SDK 适用其自身的许可条款。
