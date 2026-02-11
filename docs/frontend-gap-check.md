# 前端遗漏功能检查报告（apps/web）

基于当前代码与 `features-full-inventory.md` 对比，截至检查时点。

> **全面迁移已执行**：Settings 已连接站点、AdvancedSettings、SelectToAddress、History 区块链接、SendToken 选择地址、DappSearch API、Swap/Bridge 链从 API、Dashboard 导入入口、MainLayout 导入入口。

---

## 一、已实现（含 P0/P1 修复）

| 页面 | 状态 | 说明 |
|------|------|------|
| MainLayout | ✅ | 侧边栏含 首页/发送/收款/Swap/跨链/历史/活动/Dapp 搜索/设置 |
| Welcome | ✅ | 欢迎页 + 进入钱包 + 导入钱包入口 |
| Dashboard | ✅ | 资产概览（静态）、发送/Swap/收款按钮 |
| AddressManagement | ✅ | 地址列表、切换当前账户、isSameAddress |
| ChainList | ✅ | 调用 API 获取链列表 |
| Receive | ✅ | 收款二维码 + 地址展示 |
| Import | ✅ | WalletConnect 连接 + 助记词/私钥占位说明 |
| Swap | ✅ | 报价表单、获取报价、确认兑换按钮（无实际交易） |
| Bridge | ✅ | 路由表单、获取路由、选择按钮（无实际跨链） |
| History | ✅ | 列表展示、API 拉取、分页 |

---

## 二、仍有遗漏

### 2.1 功能不完整

| 页面 | 缺失项 |
|------|--------|
| **SendToken** | 无链选择、无代币选择、无「选择收款地址」按钮、发送按钮无交易逻辑 |
| **Swap** | 代币硬编码、无链选择、「确认兑换」无实际交易 |
| **Bridge** | 链硬编码、「选择」路由无实际跨链 |
| **History** | 无链筛选、交易哈希无区块浏览器链接 |
| **DappSearch** | 仅搜索框，无搜索逻辑与 Dapp 列表 |
| **Activities** | 仅「暂无活动」占位，无数据与筛选 |
| **AdvancedSettings** | 仅文案，无自动锁定/主题/语言切换 |

### 2.2 路由/入口缺失

| 路径 | 说明 |
|------|------|
| `/select-to-address` | 选择收款地址，SendToken 依赖 |
| `/settings/sites` | 已连接站点（当前 `/connected-sites` 为独立占位） |

### 2.3 Settings 子菜单不完整

当前：地址管理、链列表、高级设置  
缺失：**已连接站点**（对应原项目 `/settings/sites`）

### 2.4 占位页（未实现）

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

### 2.5 UX 细节

| 项 | 说明 |
|------|------|
| Dashboard 未连接 | 无「导入钱包」快捷入口（仅 Welcome 有） |
| Import | 侧边栏无入口，需从 Welcome 或手动输入 `/import` |
| History | 交易哈希应可点击跳转区块浏览器 |
| 链/代币 | Swap、Bridge、SendToken 的链/代币未从 API 获取 |

---

## 三、建议优先级

### 可立刻补齐（小改动）

1. Settings 增加「已连接站点」子菜单，指向 `/settings/sites` 或复用 `/connected-sites` 内容
2. Dashboard 未连接时增加「导入钱包」按钮
3. MainLayout 侧边栏增加「导入」入口（或放在设置下）
4. History 交易哈希增加区块浏览器链接（需链 scanLink，可先写死 eth 主网）

### 短期可做

1. AdvancedSettings：自动锁定时间、主题切换、语言选择（可先存 localStorage）
2. DappSearch：接入简单 Dapp 列表 API 或静态数据
3. /select-to-address：基础页面，从通讯录/输入地址选择
4. SendToken：增加「选择收款地址」按钮，跳转 select-to-address

### 需后端/深度开发

1. SendToken/Swap/Bridge 实际交易逻辑（依赖 WalletConnect 签名）
2. 链/代币从 API 动态获取
3. Activities 真实活动数据
4. 已连接站点数据与权限管理
