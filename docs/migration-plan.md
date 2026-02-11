# Rabby 扩展迁移与全栈开发计划

## 一、新架构概览

```
Rabby 项目
├── apps/
│   ├── web/          # 前端用户端（Web 钱包）
│   ├── admin/        # 管理系统（运营后台）
│   └── api/          # 后端 API 服务
├── packages/
│   └── shared/       # 共享逻辑与类型
├── extensions/       # 迁移后的浏览器扩展
└── src/              # 原有扩展代码（迁移参考）
```

## 二、迁移策略

### 2.1 共享逻辑抽取

| 来源 | 抽取到 | 说明 |
|------|--------|------|
| `src/constant/` | `packages/shared` | 常量、链配置、ABI |
| `src/types/` | `packages/shared` | 类型定义 |
| `src/utils/` | `packages/shared` | 地址、链、加密等工具 |
| `src/background/utils/` | `packages/shared` | 通用工具 |
| `@debank/common` 链数据 | `packages/shared` 或 API | 链列表可服务端下发 |

### 2.2 扩展迁移步骤

1. **Phase 1：建立 packages/shared**
   - 抽取类型、常量、纯工具函数
   - 扩展与 Web 同时引用

2. **Phase 2：建立 apps/api**
   - 实现用户、链、交易、安全规则等 API
   - 扩展逐步替换对 `api.rabby.io` 的直接调用

3. **Phase 3：extensions 目录**
   - 将 `src/background`、`src/content-script`、`src/ui` 迁移到 `extensions/`
   - 保持原有架构，改为引用 `@rabby/shared` 和 `@rabby/api`

4. **Phase 4：apps/web 与 apps/admin**
   - Web 端复用 shared 与 API
   - Admin 提供运营配置与监控

### 2.3 扩展保留能力

- **Background**：钥匙环、签名、权限、会话
- **Content Script + PageProvider**：Dapp 注入与通信
- **Chrome Storage**：本地加密存储
- **硬件钱包**：仍需扩展的 WebUSB/HID 等能力

## 三、前后端对接

### 3.1 API 设计方向

- **REST / GraphQL**：用户、链、交易、安全规则
- **鉴权**：JWT / Session，管理端需 RBAC
- **WebSocket**：实时通知、交易状态

### 3.2 扩展与 API

- 扩展通过 `fetch` 调用 `apps/api`
- 支持自托管 API 地址配置
- 与现有 `openapiService` 封装兼容

## 四、管理系统功能规划

1. **用户与地址**：注册量、活跃地址、链分布
2. **链配置**：支持链列表、RPC、排序
3. **安全规则**：黑白名单、合约风险规则
4. **审计**：交易、签名、异常行为
5. **系统**：API Key、日志、告警配置

## 五、依赖与 Monorepo

建议使用 **Yarn Workspaces** 或 **pnpm workspace**：

```json
// 根 package.json
{
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ]
}
```

## 六、开发顺序建议

1. `packages/shared` 落地
2. `apps/api` 基础框架与核心接口
3. `apps/admin` 登录与基础配置
4. `extensions` 迁移并接入 shared
5. `apps/web` 用户端
6. 扩展与 API 深度集成
