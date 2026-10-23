# Ticket #5：已有站点登录与会话交接

## 当前行为

连接检查成功后显式进入登录；仅 POST auth/login，不猜测初始化状态，不自动重试 POST。口令输入在提交时清空，不写入设置、日志或安全存储。成功后读取顶层 vehicles 数组，展示命名车、车型/末四位及车辆 ID 回退。无车不发任何车辆业务请求。

安全存储依赖固定 flutter_secure_storage 11.2.0：Android 默认 Keystore 加密实现；iOS Keychain unlocked_this_device，不启用同步、生物识别或后台读取。应用仅有自己的 Keychain access group，三种构建配置均引用同一 entitlements。Android 禁用备份，另外排除 shared preferences 云备份/设备迁移，防止密文脱离设备密钥。

## 后续切片的接口契约

- SessionController 是唯一当前会话拥有者；MileafApp 持有其生命周期并在恢复前台时校验到期。LoginPage、VehiclePage 独立，后续初始化、替换站点、概览页面各自独立，避免把业务全部加入主 App。
- SiteSession 绑定准确 SiteAddress（含端口/代理前缀）、token、UTC expiresAt 和 generation。业务读取先捕获 current，再使用 request(capturedSession, path)。此方法仅 GET，继承 MileafApi 的可信 HTTP、禁止跳转、15 秒截止时间与证书校验；不得另建不受策略约束的客户端。
- 所有异步结果在更新 UI/缓存前检查 isCurrent(capturedSession)。旧响应仍可能到达，但不得更新新代次。当前 401 清空 vehicles、current，递增代次并返回登录；旧 401 无此权力。后续业务缓存/选车也必须订阅代次失效，不能只比较车辆 ID。
- 安全存储是一条 JSON 记录：有效时包含 site、token、expires_at；失效时原子替换为仅 site。保留地址便于重新登录，但不保留旧凭据。restore 允许仅地址记录。普通 preferences 不存 token。App 测试中的 MemorySessionStore 仅代表存储边界，不证明原生加密。
- 所有写入通过控制器内部串行队列；当前 401 与下一次登录即使交错，也依次清除旧记录、写入新记录。新增退出/替换操作必须加入同一队列与代次体系，不能自行并行写多个安全键或直接绕过控制器写 store。
- useSite 仅用于未登录阶段从连接页进入登录，不能用作替换已授权连接的提交接口。候选站点失败保留旧站点属于 #7，本票没有提前实现。
- loading/message 是现有登录和 vehicles 界面状态；后续业务资源应有独立加载/错误状态，不能复用其覆盖整屏。
- 429 的 Retry-After 支持秒数和 HTTP 日期；仅等待期过后恢复手动登录，绝不自动提交。缺少或无效值不编造倒计时。

## OpenAPI 来源与复现

认证与 vehicles 的 DTO 由 tool/generate_auth_contract.dart 从固定 OpenAPI 生成，涵盖 Credentials、LoginResponse、Vehicle 及其引用闭包。运行 `tool/flutterw dart tool/generate_auth_contract.dart` 可重现生成结果；生成器调用同一项目 Dart formatter。必填缺失、nullable、错误类型、非数组和带时区时间被明确处理，未知不变成零。

固定源为 docs/contracts 的快照及其来源元数据（Server 146cb3b9a16af3d632b04ed8d197d0f2243d9b71）。test/fixtures/vehicles.json 来自该版本实际认证 HTTP ASGI + 隔离 PostgreSQL 合成数据，固定时间 2026-03-15T12:00Z；非用户数据，不含认证响应/token。App 测试实际消费此样本，不手工重写成简化字段集合。

## 已验证与待验

App + 可控 HTTP 测试覆盖登录/恢复、401、本地到期、旧 401 最后返回、0/1/多车辆、名称与标识回退、429、口令错误、非法响应与重试，并继承原有网络策略测试。固定后端响应已在 App 层解码。

待验：双端 release 构建、真实站点登录→车辆读取、Android/iPhone 安全存储写入→杀进程→恢复，以及失效后不再恢复旧授权。未连接真机/真实站点，平台配置不等于验收通过，Ticket #5 保持开放。用户 2026-10-23 明确批准代码与自动化先行，外部验收保留待验；不改变原生阻塞关系。
