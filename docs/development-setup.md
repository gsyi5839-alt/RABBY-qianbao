# Rabby 开发环境设置指南

本文档说明如何设置和运行 Rabby Monorepo 的各个应用。

---

## 前置要求

- **Node.js**: v18+ 推荐
- **Yarn**: v1.22+
- **Git**

---

## 安装步骤

### 1. 克隆仓库

```bash
git clone <repository-url>
cd Rabby-0.93.77
```

### 2. 安装依赖

```bash
yarn install
```

此命令将：
- 安装根目录依赖
- 安装 workspaces 中所有包的依赖（packages/*, apps/*）
- 运行 patch-package 应用补丁

### 3. 构建 shared 包

```bash
yarn --cwd packages/shared build
```

或从根目录：

```bash
cd packages/shared && yarn build && cd ../..
```

这将生成 `packages/shared/dist/` 目录，供其他应用引用。

---

## 运行各应用

### apps/web（Web 钱包前端）

#### 开发模式

```bash
yarn --cwd apps/web dev
```

默认运行在 `http://localhost:5173`

#### 构建

```bash
yarn --cwd apps/web build
```

#### 环境变量

复制 `.env.example` 并根据需要修改：

```bash
cd apps/web
cp .env.example .env
```

**关键变量**：
- `VITE_API_URL`: API 服务地址（默认 `http://localhost:3001`）
- `VITE_WALLETCONNECT_PROJECT_ID`: WalletConnect Project ID

---

### apps/api（后端 API 服务）

#### 开发模式

```bash
yarn --cwd apps/api dev
```

默认运行在 `http://localhost:3001`

#### 构建

```bash
yarn --cwd apps/api build
```

#### 生产运行

```bash
yarn --cwd apps/api start
```

#### 环境变量

复制 `.env.example` 并根据需要修改：

```bash
cd apps/api
cp .env.example .env
```

**关键变量**：
- `PORT`: 服务端口（默认 3001）
- `RABBY_API_URL`: Rabby 官方 API 地址（默认使用 `@rabby/shared` 的 `INITIAL_OPENAPI_URL`）
- `CORS_ORIGIN`: 允许的 CORS 来源（开发时可用 `*`，生产建议具体域名）
- `JWT_SECRET`: JWT 签名密钥（生产环境必须设置）
- `JWT_EXPIRES_IN`: Token 过期时间（默认 1h）
- `JWT_REFRESH_EXPIRES_IN`: Refresh Token 过期时间（默认 7d）
- `RATE_LIMIT_WINDOW_MS`: 速率限制窗口（毫秒，默认 15min）
- `RATE_LIMIT_MAX`: 窗口内最大请求数（默认 100）

---

### apps/admin（管理后台）

#### 开发模式

```bash
yarn --cwd apps/admin dev
```

默认运行在 `http://localhost:5174`

#### 构建

```bash
yarn --cwd apps/admin build
```

#### 环境变量

复制 `.env.example` 并根据需要修改：

```bash
cd apps/admin
cp .env.example .env
```

**关键变量**：
- `VITE_API_URL`: API 服务地址（默认 `http://localhost:3001`）

---

### 扩展（Extension）

#### 开发构建

```bash
yarn build:dev
```

生成的扩展位于 `dist/` 目录，可在浏览器中加载。

#### 生产构建

```bash
yarn build:pro
```

#### Chrome 加载扩展

1. 打开 Chrome 扩展管理页面：`chrome://extensions/`
2. 启用"开发者模式"
3. 点击"加载已解压的扩展程序"
4. 选择 `dist/` 目录

**注意**：当前扩展构建存在 webpack 配置兼容性问题（terser-webpack-plugin、NormalModuleFactory），与 Phases 1-4 迁移代码无关。TypeScript 编译本身无错误。

---

## Workspace 结构

```
Rabby-0.93.77/
├── packages/
│   └── shared/             # 共享类型、常量、工具
│       ├── src/
│       │   ├── types/      # TypeScript 类型定义
│       │   ├── constants/  # 常量和枚举
│       │   └── utils/      # 工具函数
│       └── package.json
├── apps/
│   ├── web/                # Web 钱包前端（Vite + React）
│   ├── api/                # 后端 API（Express）
│   └── admin/              # 管理后台（Vite + React）
├── extensions/             # （计划中）扩展代码迁移目标
└── src/                    # 当前扩展代码（待迁移到 extensions/）
```

---

## 常用命令

### 全局命令（根目录）

```bash
# 安装所有依赖
yarn install

# 构建 shared 包
yarn --cwd packages/shared build

# 同时启动所有开发服务（需自行配置 concurrently）
# yarn dev:all
```

### 子应用命令

```bash
# apps/web
yarn --cwd apps/web dev        # 开发服务器
yarn --cwd apps/web build      # 构建生产版本
yarn --cwd apps/web preview    # 预览构建结果

# apps/api
yarn --cwd apps/api dev        # 开发服务器（nodemon）
yarn --cwd apps/api build      # 构建（TypeScript 编译）
yarn --cwd apps/api start      # 生产运行

# apps/admin
yarn --cwd apps/admin dev      # 开发服务器
yarn --cwd apps/admin build    # 构建生产版本
yarn --cwd apps/admin preview  # 预览构建结果
```

---

## 开发工作流

### 修改 shared 包后

1. 重新构建 shared：

```bash
yarn --cwd packages/shared build
```

2. 重启依赖 shared 的应用（web/api/admin）

### 并行开发

推荐在不同终端窗口运行：

```bash
# Terminal 1: API 服务
yarn --cwd apps/api dev

# Terminal 2: Web 前端
yarn --cwd apps/web dev

# Terminal 3: Admin 后台
yarn --cwd apps/admin dev
```

---

## 迁移状态

| 组件 | 状态 | 说明 |
|------|------|------|
| packages/shared | ✅ | 已扩展类型和常量，apps/* 已接入 |
| apps/web | ✅ | 已接入 shared，主要功能页面完成 |
| apps/api | ✅ | 已接入 shared，统计、白名单 API 已实现 |
| apps/admin | ✅ | 已接入 shared，用户统计、安全规则页面已完成 |
| src/ (扩展) | ⚠️ 部分 | src/constant/index.ts 已重导出 shared 常量 |
| extensions/ | ❌ | 未开始，代码仍在 src/ |

详细进度见 `docs/migration-gap-report.md`。

---

## 故障排除

### `Cannot find module '@rabby/shared'`

确保已构建 shared 包：

```bash
yarn --cwd packages/shared build
```

### `vite: command not found` (apps/web 或 apps/admin)

确保已在对应子应用目录安装依赖：

```bash
yarn --cwd apps/web install
# 或
yarn --cwd apps/admin install
```

### API 无法连接

1. 检查 apps/api 是否在运行
2. 检查 apps/web/.env 中的 `VITE_API_URL` 是否正确
3. 检查 apps/api 的 CORS 配置（`CORS_ORIGIN`）

### 扩展构建失败

当前存在 webpack 配置兼容性问题（terser-webpack-plugin、NormalModuleFactory）。这与 Phases 1-4 的迁移代码无关，是预存的配置问题。TypeScript 编译本身无错误。

---

## 参考文档

- [Migration Gap Report](./migration-gap-report.md) - 迁移进度和遗漏项
- [Migration Plan](./migration-plan.md) - 迁移计划
- [New Architecture](./new-architecture.md) - 新架构设计
- [Features Full Inventory](./features-full-inventory.md) - 完整功能清单
