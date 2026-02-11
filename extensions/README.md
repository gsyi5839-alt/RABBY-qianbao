# Rabby 扩展（迁移规划）

扩展代码当前仍位于 `src/`，构建沿用根目录的 `yarn build:dev` / `yarn build:pro`。

## 接入 shared

在 `src/` 中可将部分引用改为 `@rabby/shared`：

1. 在根 `package.json` 添加：`"@rabby/shared": "file:./packages/shared"`
2. 在需要处：`import { isSameAddress, INITIAL_OPENAPI_URL } from '@rabby/shared'`

## 迁移步骤（参考 docs/migration-plan.md）

1. 抽取类型与工具到 `packages/shared` ✅
2. 在 `src/` 中逐步替换为 `@rabby/shared` 引用
3. 可选：将 `src/` 目录迁移到 `extensions/` 并调整构建
