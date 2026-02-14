# iOS Web App 开发规范

## 技术栈
- React 18 + TypeScript + Vite 5
- React Router 6
- Tailwind CSS (utility-first)
- Zustand (状态管理)
- dayjs (日期处理)
- bignumber.js (大数运算)

## 目录结构
```
apps/web/src/
├── types/              # TypeScript 类型定义
│   ├── index.ts        # 重新导出 @rabby/shared 类型
│   ├── account.ts      # 账户相关类型
│   ├── chain.ts        # 链相关类型
│   ├── token.ts        # 代币相关类型
│   └── transaction.ts  # 交易相关类型
├── constants/          # 常量定义
│   ├── index.ts        # 统一导出
│   ├── chains.ts       # 链枚举和配置
│   └── keyring.ts      # 密钥管理常量
├── utils/              # 工具函数
│   ├── index.ts        # 统一导出
│   ├── address.ts      # 地址处理
│   ├── format.ts       # 格式化
│   └── storage.ts      # 存储工具
├── services/           # 业务服务层
│   ├── api/            # API 客户端
│   │   ├── client.ts   # HTTP 客户端
│   │   ├── index.ts    # 统一导出
│   │   ├── balance.ts  # 余额 API
│   │   ├── token.ts    # 代币 API
│   │   ├── chain.ts    # 链 API
│   │   ├── swap.ts     # Swap API
│   │   └── bridge.ts   # Bridge API
│   ├── keyring/        # 密钥管理
│   │   ├── index.ts
│   │   ├── hdKeyring.ts
│   │   └── simpleKeyring.ts
│   └── storage/        # 存储抽象
│       └── index.ts
├── store/              # Zustand 状态管理
│   ├── index.ts        # 统一导出
│   ├── account.ts      # 账户状态
│   ├── chain.ts        # 链状态
│   ├── preference.ts   # 偏好设置状态
│   └── transaction.ts  # 交易状态
├── hooks/              # React Hooks
│   ├── index.ts        # 统一导出
│   ├── useWallet.ts    # 钱包操作
│   ├── useCurrentAccount.ts
│   ├── useCurrentBalance.ts
│   └── backgroundState/
│       └── useAccount.ts
├── components/         # 可复用组件
│   ├── ui/             # 基础 UI
│   │   ├── Button.tsx
│   │   ├── Modal.tsx
│   │   ├── Popup.tsx
│   │   ├── Loading.tsx
│   │   ├── Empty.tsx
│   │   ├── Toast.tsx
│   │   └── index.ts
│   ├── address/        # 地址相关
│   │   ├── AddressViewer.tsx
│   │   ├── NameAndAddress.tsx
│   │   └── index.ts
│   ├── chain/          # 链相关
│   │   ├── ChainIcon.tsx
│   │   ├── ChainSelector.tsx
│   │   └── index.ts
│   ├── token/          # 代币相关
│   │   ├── TokenWithChain.tsx
│   │   ├── TokenSelector.tsx
│   │   ├── TokenAmountInput.tsx
│   │   └── index.ts
│   └── layout/         # 布局
│       ├── PageHeader.tsx
│       ├── MainLayout.tsx
│       ├── StrayPage.tsx
│       └── index.ts
├── contexts/           # React Contexts
│   └── LanguageContext.tsx
├── i18n/               # 国际化
├── pages/              # 页面组件
│   ├── welcome/        # 欢迎/引导
│   ├── account/        # 账户创建/导入
│   ├── dashboard/      # 主页
│   ├── send/           # 发送
│   ├── receive/        # 接收
│   ├── swap/           # 兑换
│   ├── bridge/         # 跨链
│   ├── history/        # 历史
│   ├── nft/            # NFT
│   ├── settings/       # 设置
│   ├── approval/       # 审批
│   ├── gas-account/    # Gas代付
│   └── perps/          # 合约交易
├── App.tsx             # 应用入口 + 路由
├── main.tsx            # 渲染入口
└── index.css           # 全局样式
```

## 编码规范

### 命名
- 文件名: `camelCase.ts` (工具) / `PascalCase.tsx` (组件)
- 组件: `PascalCase`
- hooks: `use` 前缀, `camelCase`
- 常量: `UPPER_SNAKE_CASE`
- 类型/接口: `PascalCase`

### 组件规范
```tsx
// 使用函数组件 + TypeScript
interface Props {
  title: string;
  onClose?: () => void;
}

export const MyComponent: React.FC<Props> = ({ title, onClose }) => {
  return <div className="...">{title}</div>;
};
```

### 导入顺序
1. React / 第三方库
2. @rabby/shared 类型
3. services / store
4. hooks
5. components
6. utils / constants
7. 样式

### 状态管理 (Zustand)
```ts
import { create } from 'zustand';

interface AccountStore {
  currentAccount: Account | null;
  setCurrentAccount: (account: Account) => void;
}

export const useAccountStore = create<AccountStore>((set) => ({
  currentAccount: null,
  setCurrentAccount: (account) => set({ currentAccount: account }),
}));
```

### API 客户端
```ts
// 所有 API 调用通过 services/api/ 统一管理
// 使用 fetch + 统一错误处理
// Base URL: https://api.rabby.io
```

### 路由
```tsx
// 使用 React Router 6
// 路由定义集中在 App.tsx
// 需要认证的路由使用 ProtectedRoute 包裹
```

## 扩展源码参考路径
- 扩展 UI: `src/ui/views/` + `src/ui/component/`
- 扩展 Hooks: `src/ui/hooks/`
- 扩展服务: `src/background/service/`
- 扩展常量: `src/constant/`
- 扩展类型: `src/background/service/openapi.ts` (主要类型来源)
- 共享包: `packages/shared/src/`
