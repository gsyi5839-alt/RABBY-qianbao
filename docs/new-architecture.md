# Rabby 新架构说明

## 目录结构

```
Rabby-0.93.77/
├── apps/
│   ├── web/           # 前端 Web 应用（用户钱包）
│   ├── admin/         # 管理系统（运营后台）
│   └── api/           # 后端 API 服务
├── packages/
│   └── shared/        # 共享逻辑（类型、常量、工具）
├── extensions/        # 迁移后的浏览器扩展
├── src/               # 原有扩展源码（迁移参考）
├── build/             # 原有扩展构建
├── docs/
│   ├── new-architecture.md   # 本文件
│   └── migration-plan.md    # 迁移计划
└── package.json       # 根配置（可配置 workspaces）
```

## 模块职责

| 模块 | 职责 |
|------|------|
| **apps/web** | Web 端钱包，账户、资产、Swap、Dapp 连接 |
| **apps/admin** | 管理后台，链配置、安全规则、用户统计、审计 |
| **apps/api** | 后端服务，用户、链、交易、安全规则、Swap 等 API |
| **packages/shared** | 跨项目共享的类型、常量、工具函数 |
| **extensions** | 浏览器扩展，保持 Dapp 注入与本地签名能力 |

## 数据流

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Extension  │     │   Web App   │     │   Admin     │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                    │                    │
       │     ┌──────────────┼────────────────────┘
       │     │              │
       ▼     ▼              ▼
┌─────────────────────────────────────────────────┐
│              apps/api (后端)                       │
│  - 用户/会话  - 链配置  - 交易  - 安全规则  - Swap   │
└─────────────────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│  Database   │  (PostgreSQL / Redis 等)
└─────────────┘
```

## 扩展与 Web 的差异

| 能力 | 扩展 | Web |
|------|------|-----|
| 本地签名 | ✅ 私钥在扩展内 | 需 WalletConnect / 托管方案 |
| Dapp 注入 | ✅ window.ethereum | 通过 WalletConnect |
| 硬件钱包 | ✅ WebUSB/HID | 需移动端或扩展桥接 |
| 存储 | Chrome Storage | 服务端 + 本地 |

扩展迁移后仍作为「可注入 Dapp 的完整钱包」；Web 端侧重展示与便捷操作，复杂签名可依赖扩展或 WalletConnect。

## 开发命令

在项目根目录执行：

| 命令 | 说明 |
|------|------|
| `yarn shared:build` | 构建 shared 包 |
| `yarn api:dev` | 启动 API (http://localhost:3000) |
| `yarn api:build` | 构建 API |
| `yarn admin:dev` | 启动管理后台 (http://localhost:3001) |
| `yarn admin:build` | 构建管理后台 |
| `yarn web:dev` | 启动 Web 端 (http://localhost:3002) |
| `yarn web:build` | 构建 Web 端 |
| `yarn build:dev` | 构建扩展（原有命令） |
