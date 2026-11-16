# 两会话合并检查与 arm64 安装包（2026-11-16）

## 1 输入状态

| 项 | 值 |
| --- | --- |
| 分支 | `main`（本地领先 `origin/main` 3 个提交） |
| HEAD | `fb01a28` 重排行程详情：对照电量改为折叠动作行，驾驶与环境改为细分隔事实表 |
| 工作区规模 | 1560 条变更路径（840 条已暂存、731 条未暂存，其余为新增文档/图册） |
| 构建目的 | 合并检查两个并行会话的代码后，产出 arm64 release APK |

## 2 两个会话各自改了什么

| 会话 | 文件域 | 状态 |
| --- | --- | --- |
| A「Apple 焕新 / 行程详情」 | `tokens.dart`、`semantic.dart`、`nav_bar.dart`、`top_bar.dart`、`components.dart`、页面级 widget、`drive_detail_page.dart`、`sample_chart.dart`、Apple 焕新文档与图册 | 部分已提交（`fb01a28`），其余在工作区（含 840 条暂存） |
| B「概览图表头重排」（本次会话） | `charts.dart`、`overview_page.dart`、`sample_chart.dart`、`drive_detail_page.dart`、四个测试文件、`docs/implementation/overview-chart-header*`、`AGENTS.md`、`.hallmark/log.json` | 全部在工作区，未提交 |

### 重叠与结论

`sample_chart.dart` 与 `drive_detail_page.dart` 被两个会话先后编辑。核查 `git show fb01a28` 后确认：**A 的提交已经包含 B 的这两处改动**（`subtitle` 移除、提示语改走 `trailing`、图下重复单位行删除），A 在同一个提交里继续做了 `ExpansionTile → MileafDisclosure` 的重排。两段改动是叠加关系，没有出现「两个版本互相覆盖、其中一版丢失」。

`charts.dart` 全程只有 B 修改（会话开始时该文件是干净的），A 的 token 层改动（`MileafRadius.surface`、`MileafSpace`、字号）被 B 的组件以 token 形式消费，而不是重复定义。

## 3 合并检查结果

| 检查 | 结果 |
| --- | --- |
| 冲突标记（`<<<<<<<` / `>>>>>>>`） | 无 |
| `git diff --check`（空白/行尾） | 无输出 |
| 遗留调试代码（`PROBE`） | 无（`ui_ux_u0x` 里的 `debugPrint` 是既有测试） |
| 重复定义 | `_ChartHeading` / `_ChartLegend` / `_LegendMark` 各一处 |
| `tool/flutterw analyze --no-pub`（全项目） | 无诊断 |
| `tool/flutterw test --no-pub`（全量，两会话代码合并后） | **754 通过 / 33 跳过 / 0 失败** |
| 渲染抽查 | 概览、行程、统计、充电详情、行程详情在合并代码下的正式渲染一致（图册见 `overview-chart-header-renders/`、`apple-design-renewal-renders/`） |

结论：两会话代码可以合并，无冲突、无覆盖丢失，分析与测试通过。

## 4 arm64 安装包

构建入口沿用 [构建进程隔离验证](build-isolation.md)：`tool/flutterw` 在 `sandbox-exec` 下运行 Gradle，前置探针为 `LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`，宿主 SDK 与项目 SDK 分离。

```sh
MILEAF_HOST_ANDROID_SDK=<host android sdk> \
  tool/flutterw build apk --release --split-per-abi --no-pub
```

| 产物 | 大小 | 说明 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 67,012,659 B（64 MiB） | **本次交付**：只含 `arm64-v8a` |
| `app-armeabi-v7a-release.apk` | 53.5 MB | 32 位 ARM，附产 |
| `app-x86_64-release.apk` | 33.2 MB | 模拟器，附产 |
| `app-release.apk` | 91.4 MB | 三 ABI 通用包（`--target-platform android-arm64` 在本机 Flutter 上没有生效，仍打三套 ABI，故改用 `--split-per-abi`） |

arm64 包的事实：

- `packageName=app.mileaf.mileaf`，`versionName=0.1.3`，`versionCode=2004`（`--split-per-abi` 按 ABI 自动加 2000；通用包是 4）
- `minSdk=24`，`targetSdk=36`，`compileSdk=36`
- `sha256=7e17d377ddabdf7a2e8497c3f847931318eefda9f8d80680c831d0dc498480af`
- 签名 = `CN=Android Debug`（`android/app/build.gradle.kts` 的 release 用 debug keystore，属研发签名，不可上架）
- 体积主要来自 `libAMapSDK_MAP_v11_3_100.so` 34.4 MB、`libflutter.so` 11.7 MB、`libapp.so` 8.8 MB
- 图标字体已 tree-shake（1,645,184 → 3,032 B）

## 5 边界

- 未安装到真机，未做设备网络/地图/安全存储验收；构建成功不等于外部验收（#11/#16/#17 仍待）。
- 未签名上架、未推送、未提交。工作区仍有会话 A 的大量暂存与未暂存改动，提交时机由用户决定。
- `.dsh-tmp/`（5.6 MB，11:53–12:07 的渲染中间产物）是上一会话遗留的未跟踪目录，本次未删除。
