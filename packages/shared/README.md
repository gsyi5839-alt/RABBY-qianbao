# Rabby 共享包

扩展、Web、Admin 共用的核心逻辑与类型。

## 内容

- 类型定义（Chain、Account、Tx 等）
- 常量与配置
- 工具函数（地址、链、加密等）
- 业务逻辑抽象（可抽离自 src/background、src/utils）

## 使用

```ts
import { isSameAddress } from '@rabby/shared/utils';
import type { Chain } from '@rabby/shared/types';
```
