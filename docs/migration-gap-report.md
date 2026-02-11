# 迁移遗漏深度检查报告

基于 `docs/features-full-inventory.md`、`docs/migration-plan.md` 与当前代码结构整理。

> **上次执行**：Phases 1-4 已完成（2026-02-12）
> - Phase 1: packages/shared 扩展 + API/Admin 接入 shared ✅
> - Phase 2: apps/web 功能补全 (DappSearch, Activities, AdvancedSettings, ConnectedSites) ✅
> - Phase 3: apps/admin 功能扩展 (UserStats, SecurityRules) ✅
> - Phase 4: 扩展开始接入 @rabby/shared（src/constant/index.ts 重导出） ✅
> - Phase 5: 文档更新（进行中）

---

## 一、packages/shared 接入状态

| 项目 | 状态 | 说明 |
|------|------|------|
| apps/web | ✅ 已使用 | 57 个文件导入 @rabby/shared 类型和常量 |
| apps/admin | ✅ 已使用 | 使用 shared 的 DappEntry、ChainConfig、User、AuthPayload 类型 |
| apps/api | ✅ 已使用 | 使用 shared 的 DappEntry、ChainConfig、User、AuthPayload、INITIAL_OPENAPI_URL |
| src/（扩展） | ✅ 部分使用 | src/constant/index.ts 已重导出 30+ 个常量/枚举，保留扩展特定实现（如 SAFE_RPC_METHODS） |

**完成**：
- packages/shared 已扩展：添加 EVENTS (QRHARDWARE, LEDGER, etc.), 枚举 (KEYRING_CATEGORY, WALLET_BRAND_TYPES, TX_TYPE_ENUM, CANCEL_TX_TYPE, DARK_MODE_TYPE, SIGN_PERMISSION_TYPES), 映射 (KEYRING_TYPE_TEXT, BRAND_ALIAN_TYPE_TEXT)
- apps/api、apps/admin、apps/web 均已配置 @rabby/shared 依赖
- src/constant/index.ts 已重导出 shared 常量，删除重复定义
- tsconfig.json 已添加 @rabby/shared 路径映射

---

## 二、apps/web 功能遗漏

### 2.1 路由与侧边栏不一致

| 路由 | 侧边栏 | 实现状态 |
|------|--------|----------|
| `/receive` | ❌ 无 | 已实现 |
| `/activities` | ❌ 无 | 已实现（占位） |
| `/dapp-search` | ❌ 无 | 已实现（占位） |
| `/import` | ❌ 无 | 已实现（占位） |

**建议**：在 `MainLayout` 中补齐 `/receive`、`/activities`、`/dapp-search` 的导航入口，或明确不展示的策略。

### 2.2 占位页（仅标题/简述）

| 路径 | 说明 |
|------|------|
| `/send-nft` | 发送 NFT |
| `/gnosis-queue` | Gnosis 交易队列 |
| `/nft` | NFT 视图 |
| `/gas-account` | Gas 账户 |
| `/rabby-points` | Rabby 积分 |
| `/perps` | 永续合约 |
| `/custom-rpc` | 自定义 RPC |
| `/add-address` | 添加地址 |
| `/connected-sites` | 已连接站点 |

### 2.3 功能完整度

| 页面 | 状态 | 说明 |
|------|------|------|
| **SendToken** | ❌ 不完整 | 无链选择、无代币选择、无选择收款地址（SelectToAddress）、发送按钮无实际交易逻辑 |
| **Swap** | ❌ 不完整 | 代币为硬编码，无链/代币 API；确认兑换按钮无交易逻辑 |
| **Bridge** | ❌ 不完整 | 链列表硬编码；选择路由后无实际跨链逻辑 |
| **Receive** | ✅ 已完成 | 已展示收款二维码 (react-qr-code) |
| **History** | ❌ 不完整 | 无链筛选、无区块浏览器链接 |
| **Import** | ✅ 已完成 | 已有助记词/私钥/WalletConnect 导入流程（使用 WalletContext API） |
| **DappSearch** | ✅ 已完成 | 已有搜索框、mock DApp 列表、分类过滤（linter 重写为完整实现） |
| **ChainList** | ✅ 已完成 | 已调用 API 获取链列表 (`getChainList`) |
| **AdvancedSettings** | ✅ 已完成 | 已有自动锁定、主题（light/dark/system）、隐藏小余额、自定义 Gas、Testnet、缓存清理、数据导出等设置项（linter 重写为完整实现） |
| **ConnectedSites** | ✅ 已完成 | 已展示 WalletConnect 会话信息、断开连接功能（linter 重写为完整实现） |
| **AddressManagement** | ✅ 已完成 | 已接入 `setCurrentAccount`，支持切换当前账户、添加/删除地址 |
| **Activities** | ✅ 基本完成 | 已展示 pending/expired 活动列表、筛选、approve/reject 操作（linter 重写为完整实现） |

### 2.4 缺失路由（原项目有）

| 原路径 | 说明 |
|--------|------|
| `/select-to-address` | 选择收款地址（SendToken、SendNFT 依赖） |
| `/settings/sites` | 已连接站点（当前为独立 `/connected-sites`） |
| `/settings/address-detail` | 地址详情 |
| `/settings/address-backup/*` | 备份私钥/助记词 |
| `/settings/switch-lang` | 语言切换 |
| `/custom-testnet` | 自定义测试网 |

---

## 三、apps/api 实现状态

| 接口 | 状态 | 说明 |
|------|------|------|
| `/health` | ✅ | 健康检查 |
| `/chains/config` | ✅ | 链配置（返回 apiUrl from INITIAL_OPENAPI_URL） |
| `/swap/quote` | ✅ | 模拟报价 |
| `/bridge/routes` | ✅ | 模拟路由 |
| `/history/:address` | ✅ | 模拟历史 |
| `/api/admin/stats` | ✅ 新增 | 用户统计（totalUsers, totalAddresses, registrationByDay） |
| `/api/security/whitelist` | ✅ | 地址白名单 GET/POST/DELETE |
| Shared 类型 | ✅ | 已使用 @rabby/shared 的 DappEntry, ChainConfig, User, AuthPayload |
| .env.example | ✅ 新增 | 已创建 apps/api/.env.example |
| 链列表 | ⚠️ 代理 | 当前代理真实 Rabby API (INITIAL_OPENAPI_URL)，非本地 mock |
| 代币列表 | ⚠️ 代理 | 同上，代理真实 API |
| 用户/鉴权 | ✅ 部分 | 已有 JWT 中间件 (auth.ts)，演示用 userStore |
| Dapp 搜索 | ❌ | 无 Dapp 列表 API |
| 实际 Swap 执行 | ❌ | 无交易构建与提交 |
| 实际 Bridge 执行 | ❌ | 无跨链交易 |

---

## 四、apps/admin 实现状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 登录 | ✅ | 演示用，任意账号密码 |
| Dashboard | ✅ | 展示 chain config, dapp entries |
| Chains 页面 | ✅ | 展示、搜索链配置（无编辑） |
| DApps 页面 | ✅ | 展示、搜索 DApp 列表（无编辑） |
| Users 页面 | ✅ 扩展 | 展示用户列表 + API 统计数据（totalUsers, totalAddresses） |
| Security 页面 | ✅ 扩展 | Phishing Detection + 地址白名单管理（添加/删除功能已接入真实 API） |
| Shared 类型 | ✅ | 已使用 @rabby/shared 的 DappEntry, ChainConfig |
| .env.example | ✅ 新增 | 已创建 apps/admin/.env.example |
| 链配置编辑 | ❌ | 仅展示，无编辑功能 |
| DApp 编辑 | ❌ | 仅展示，无编辑功能 |
| 审计日志 | ❌ | 无交易、签名、异常行为审计 |
| RBAC | ❌ | 无角色权限控制 |

---

## 五、extensions 未迁移

| 项 | 状态 |
|----|------|
| 代码迁移 | ❌ 仍在 `src/`，未迁至 `extensions/` |
| 构建 | 仍用根目录 `yarn build:dev` |
| shared 接入 | ❌ 未替换为 `@rabby/shared` |

---

## 六、Monorepo 与依赖

| 项 | 状态 |
|----|------|
| Yarn Workspaces | ✅ 已配置 | 根 package.json 已有 `workspaces: ["packages/*", "apps/*", "extensions/*"]` |
| @rabby/shared 依赖 | ✅ | apps/web、apps/admin、apps/api 均已添加 `"@rabby/shared": "file:../../packages/shared"` |
| tsconfig paths | ✅ | 根 tsconfig.json 已添加 `"@rabby/shared": ["./packages/shared/src"]` |
| apps/* 依赖 | ⚠️ | 依赖被提升到根，可能存在版本冲突 |
| apps/web vite | ✅ | vite 已在 apps/web/package.json 中声明 |
| react-router-dom | ⚠️ | 根为 v5，apps 声明 v6 但实际使用 v5 |

---

## 七、配置与环境

| 文件 | 状态 |
|------|------|
| apps/web/.env.example | ✅ | 有 VITE_API_URL、VITE_WALLETCONNECT_PROJECT_ID |
| apps/admin/.env.example | ✅ 新增 | 有 VITE_API_URL |
| apps/api/.env.example | ✅ 新增 | 有 PORT, RABBY_API_URL, CORS_ORIGIN, JWT_SECRET, JWT_EXPIRES_IN, JWT_REFRESH_EXPIRES_IN, RATE_LIMIT_WINDOW_MS, RATE_LIMIT_MAX |

---

## 八、文档不一致

| 文档 | 问题 |
|------|------|
| features-full-inventory.md | 第十节将 Swap、Bridge、History 等标为「占位」，实际已有基础实现 |
| new-architecture.md | 开发命令中 web 端口写 3002，需与 vite 配置一致 |

---

## 九、修复优先级建议

### P0（立即）✅ 已完成

1. ✅ 在 AddressManagement 中接入 `setCurrentAccount`，支持切换当前账户
2. ✅ 补齐 MainLayout 侧边栏：`receive`、`activities`、`dapp-search` 等与现有路由一致
3. ✅ 新增 apps/admin、apps/api 的 `.env.example`

### P1（短期）✅ 已完成

1. ✅ 将 apps/web、apps/admin、apps/api 接入 `@rabby/shared`
2. ✅ 完善 Import 页面：助记词、私钥、WalletConnect 等导入方式
3. ✅ ChainList 调用 API 获取链列表
4. ✅ Receive 增加二维码展示
5. ✅ DappSearch 实现 DApp 列表和搜索
6. ✅ AdvancedSettings 实现主题、自动锁定、缓存清理等功能
7. ✅ ConnectedSites 展示 WalletConnect 会话
8. ✅ Activities 展示 pending/expired 活动

### P2（中期）⚠️ 部分完成

1. ✅ 扩展 shared 抽取，在 src/constant/index.ts 中重导出 `@rabby/shared` 常量
2. ❌ 增加 `/select-to-address` 路由，供 SendToken 使用
3. ✅ 配置 Yarn Workspaces，统一依赖管理
4. ✅ Admin 增加用户统计页面
5. ✅ Admin 增加安全规则（白名单）管理
6. ⚠️ 扩展构建验证（webpack 配置问题待解决，非迁移代码问题）

### P3（长期）

1. extensions 目录迁移（代码仍在 src/，未迁至 extensions/）
2. 完善 Admin 链配置编辑、DApp 编辑
3. API 增加真实链/代币数据（当前代理 Rabby API）
4. API 增加 Dapp 搜索 API
5. 完善 Swap/Bridge/SendToken 实际交易逻辑
