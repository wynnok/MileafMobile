# #16：隔离性能数据准备

仅用 Python 3.12 标准库生成和核验合成 CSV。App 不导入这些文件，也不依赖本机 MileafServer 符号链接。公开边界是 `data.py generate/verify/load` 与其 CSV/manifest 产物；测试不调用私有生成行函数、不 mock 数据库。Docker边界只使用本任务失败CLI哨兵记录假参数/环境，明确拒绝镜像检查，绝不模拟装载通过；据此验证显式本地socket和空配置/环境隔离。

## 项目内环境与命令

在仓库根执行。只复用已有 Python 3.12，不下载解释器、不安装全局包；无 Python 依赖。每个命令显式把 `UV_PROJECT_ENVIRONMENT` 锁到当前 checkout 的 `tool/performance/.venv`，覆盖继承的外部环境目标；所有 run 显式加 `--no-env-file`，不继承 `UV_ENV_FILE` 自动加载生产配置。首次由可用的既有解释器创建本工具 `.venv`，示例路径须换为本机已有 Python 3.12：

```sh
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv venv --no-managed-python --no-python-downloads \
  --python /path/to/existing/python3.12 tool/performance/.venv
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv sync --project tool/performance --locked --offline --no-python-downloads
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv run --no-env-file --project tool/performance --locked --offline --no-python-downloads \
  python tool/performance/data.py generate
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv run --no-env-file --project tool/performance --locked --offline --no-python-downloads \
  python tool/performance/data.py verify
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv run --no-env-file --project tool/performance --locked --offline --no-python-downloads \
  python -m unittest discover -s tool/performance/tests -v
```

默认输出 `.cache/performance-data/`。`--output` 只能指向当前 checkout `.cache/` 下的新目录；已有目录不覆盖，拒绝 `..` 和路径/产物符号链接。失败生成的部分目录不冒充有效集，不自动删除既有数据；换一个新目录重新生成或经确认后清理。不要把产物提交 Git。

固定默认 `--seed 27 --anchor 2026-03-15T12:00:00Z`，不读取当前时间。同 seed/anchor 的 CSV、schema、manifest 逐字一致。采集前可显式选择临近实测日期的 **UTC 整秒 anchor** 和新目录，例如 `generate --output .cache/performance-october --anchor 2026-10-25T00:00:00Z`。记录 anchor、App/Server 实际时钟和查询区间；默认冻结日期不保证未来“最近30天”有数据。

## 数据、来源与边界

固定为 50,000 行程、500,000 位置、5,000 充电会话和每会话20点、共100,000充电采样，另含单车设置、休眠状态及固件记录。行程每15分钟一条、持续5分钟，跨度约521天；每10条行程后一个8分钟充电会话。它是性能合成负载，不是物理能量模型或真实车辆指标对账样本。

manifest 保存 seed/anchor、Server commit、schema/migration SHA-256、每个文件 SHA-256、精确行数、完整查询区间和固定资源别名：

- 车辆 `3`；行程 `149999` 为最近的固定密集详情，20,000个单调真实时间点，预期未来通过 `/v1/drives/149999/series?fields=speed,battery,elevation&points=200` 核验后端实际降采样。离线核验不能证明 API 已返回200点。
- 充电 `100000`–`104999`，page size=20，可进行多页游标验收；尚未运行真实 API 翻页。
- CSV 保留行程起终点外键、位置所属车辆/行程、充电位置及采样会话外键。`verify` 独立读取真实完整 CSV，检查摘要、列/行数、唯一ID、引用、UTC时间格式与范围、单调采样、首尾端点、密集资源规模和常用指标范围；重算文件摘要不能绕过这些结构检查。摘要用于复现与意外损坏检测，不是数字签名。

来源固定于 [Mileaf Server 146cb3b](https://github.com/wynnok/MileafServer/tree/146cb3b9a16af3d632b04ed8d197d0f2243d9b71)：

| 来源 | 用途 | SHA-256 |
| --- | --- | --- |
| `tests/fixtures/schema.sql` | 逐字 vendor 到 `frozen/`，TeslaMate v4.3.0 的独立转录只读 API 投影，并非完整生产库 dump | `ecffecdcfbbd6bbf38083a761845d46fdee8b0e72b1e95a3ce980e7c2ea74425` |
| `tests/fixtures/migration_versions.txt` | 逐字 vendor 到 `frozen/`，冻结兼容版本集合 | `ea850d1b038c4af950db32e7a0939aa5ebe8f1dcefe5e56dcd592f3451038868` |
| `tests/fixtures/performance.py` | 参考其固定种子、COPY和稠密详情思路；此工具独立扩大规模、生成CSV并增加离线核验，不导入/修改源文件 | `d11c8ae517083e756800769b3e1b33cc54968165a3b7b0eac30eadf042fd3dce` |

## 可选临时数据库装载（尚未实测）

生成/装载不读取现有生产 DSN、`.env`、Settings 或 credential，不导入后端 runtime；测试数据只能使用本任务新建本地隔离测试库。Docker 必须由人工事先提供已运行环境与本地缓存 `postgres:16-alpine` 镜像。Docker CLI 默认使用本地 `unix:///var/run/docker.sock`，可通过显式 `--docker-socket /绝对/本地/socket` 指定本地Unix socket（拒绝TCP/SSH/DSN及相对路径），每次使用项目缓存内新建空配置目录并移除 Docker 环境配置，不继承 `DOCKER_HOST`/`DOCKER_CONTEXT`/`DOCKER_CONFIG`、TLS路径或宿主凭据配置；本地 socket 不存在或不可用就失败，不改用远程daemon。本机历史OrbStack端点为 `$HOME/.orbstack/run/docker.sock`，当前服务停运/socket不存在；未来仅在人工提供的本地测试环境运行时，可对load显式追加 `--docker-socket "$HOME/.orbstack/run/docker.sock"`，无需更改全局socket链接。本入口不会启动 Docker/OrbStack、拉镜像、接收 DSN/既有容器/宿主挂载，或连接真实数据库：

```sh
UV_CACHE_DIR="$PWD/.cache/uv" UV_PROJECT_ENVIRONMENT="$PWD/tool/performance/.venv" uv run --no-env-file --project tool/performance --locked --offline --no-python-downloads \
  python tool/performance/data.py load
```

`load --preflight` 只在显式/默认本地socket检查cached镜像，不创建数据库；可用它核对入口条件，成功仍不代表装载通过。

先完整离线核验，然后仅创建随机任务名/标签的全新 `--rm --pull=never --network none` 容器，数据放容器 tmpfs，不发布端口、不挂宿主目录。无网络的容器内部使用 trust 认证，经 `docker exec` 的 Unix socket 装载，不形成对宿主可访问的无口令数据库。只在事务内把行程的两个循环外键改为延迟检查，COPY后 COMMIT 强制验证原始引用；不修改 vendor schema 或参考仓库。创建仅有 public SELECT 权限的 reader，以只读事务验证各表计数，ANALYZE固定规划器统计，结束只清理匹配本次唯一标签的容器。无 keep 入口，不保留运行服务；异常无法确认清理时失败退出，不输出成功报告。

成功才在项目 `.cache/performance-load-<随机任务ID>.json` 写入实际镜像ID、manifest摘要、数据库计数与容器清理状态。命令输出不含 DSN、密码、token、响应体或轨迹；Docker/psql输出仅在内存内部处理。若装载失败，退出非零，不能把离线测试成功写成数据库已通过。

**当前 Docker 停运，尚未实际装载。** 未来真实 Server/200点采样与 App 设备运行需要另外准备获授权的隔离服务；本入口故意不启动或常驻 Server。沿用同一冻结 schema/manifest，先核对数据库计数、reader权限、API实际200点与分页，保存证据后才进入设备计时。profile/release、80ms RTT/10–2Mbps、每指标每平台至少30次、OS与raster/present关联等协议见 `docs/implementation/performance.md`，当前样本仍 N=0。
