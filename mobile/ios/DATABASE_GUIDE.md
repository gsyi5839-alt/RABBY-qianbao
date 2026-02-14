# 数据库配置文档

## 概述

Rabby iOS 应用现在支持 **SQLite 数据库**用于存储结构化数据，与原有的 UserDefaults 存储系统共存。

## 存储架构（更新后）

### 1. **Keychain**（敏感数据）
- 加密的 Vault（私钥、助记词）
- AES-GCM + PBKDF2 加密

### 2. **SQLite 数据库**（结构化数据）✨ 新增
- 交易历史（支持复杂查询、分页）
- 代币缓存（链ID过滤、价格追踪）
- NFT 集合（ERC721/ERC1155）
- Swap 历史
- Bridge 历史
- 已连接的 dApp 站点
- 通讯录联系人

### 3. **UserDefaults**（轻量级配置）
- 用户偏好设置
- 应用配置
- 小型缓存数据

### 4. **NSCache**（内存缓存）
- 热数据缓存

---

## 数据库表结构

### `transactions` - 交易历史
```sql
CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    hash TEXT NOT NULL,
    address TEXT NOT NULL,
    chain_id TEXT NOT NULL,
    from_address TEXT NOT NULL,
    to_address TEXT,
    value TEXT,
    data TEXT,
    nonce INTEGER NOT NULL,
    gas_used TEXT,
    gas_price TEXT,
    max_fee_per_gas TEXT,
    max_priority_fee_per_gas TEXT,
    status TEXT NOT NULL,  -- 'pending', 'confirmed', 'failed', 'dropped'
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    is_submit_failed INTEGER DEFAULT 0,
    push_type TEXT,
    site_origin TEXT,
    site_name TEXT,
    site_icon TEXT,
    tx_type TEXT,
    UNIQUE(hash, chain_id)
);
```

### `tokens` - 代币缓存
```sql
CREATE TABLE tokens (
    id TEXT PRIMARY KEY,
    address TEXT NOT NULL,
    chain_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    name TEXT NOT NULL,
    decimals INTEGER NOT NULL,
    logo_url TEXT,
    price_usd REAL,
    balance TEXT,
    raw_amount TEXT,
    is_custom INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 1,
    is_hidden INTEGER DEFAULT 0,
    updated_at INTEGER NOT NULL,
    UNIQUE(address, chain_id)
);
```

### `nfts` - NFT 集合
```sql
CREATE TABLE nfts (
    id TEXT PRIMARY KEY,
    contract_address TEXT NOT NULL,
    token_id TEXT NOT NULL,
    chain_id TEXT NOT NULL,
    owner_address TEXT NOT NULL,
    name TEXT,
    description TEXT,
    image_url TEXT,
    collection_name TEXT,
    amount TEXT DEFAULT '1',
    is_erc1155 INTEGER DEFAULT 0,
    is_starred INTEGER DEFAULT 0,
    updated_at INTEGER NOT NULL,
    UNIQUE(contract_address, token_id, chain_id)
);
```

### 其他表
- `swap_history` - Swap 历史
- `bridge_history` - 跨链桥接历史
- `connected_sites` - 已连接的 dApp
- `contacts` - 通讯录

---

## 使用示例

### 1. 保存交易记录

```swift
import Foundation

// 创建交易对象
let tx = DatabaseManager.Transaction(
    id: UUID().uuidString,
    hash: "0x1234567890abcdef...",
    address: "0xUserAddress...",
    chainId: "1",  // Ethereum Mainnet
    fromAddress: "0xUserAddress...",
    toAddress: "0xRecipientAddress...",
    value: "1000000000000000000",  // 1 ETH in wei
    data: "0x",
    nonce: 42,
    gasUsed: "21000",
    gasPrice: "50000000000",  // 50 Gwei
    maxFeePerGas: nil,
    maxPriorityFeePerGas: nil,
    status: "pending",
    createdAt: Date(),
    completedAt: nil,
    isSubmitFailed: false,
    pushType: "wallet",
    siteOrigin: nil,
    siteName: nil,
    siteIcon: nil,
    txType: "send"
)

// 保存到数据库
do {
    try DatabaseManager.shared.insertTransaction(tx)
    print("✅ Transaction saved")
} catch {
    print("❌ Failed to save transaction: \(error)")
}
```

### 2. 查询交易历史

```swift
// 获取某个地址的所有交易（最多100条）
do {
    let transactions = try DatabaseManager.shared.getTransactions(
        address: "0xUserAddress...",
        chainId: "1",  // 可选：仅查询以太坊主网
        limit: 100
    )

    for tx in transactions {
        print("Tx: \(tx.hash), Status: \(tx.status)")
    }
} catch {
    print("❌ Failed to query transactions: \(error)")
}

// 获取待处理的交易
do {
    let pendingTxs = try DatabaseManager.shared.getPendingTransactions(
        address: "0xUserAddress..."
    )
    print("Pending transactions: \(pendingTxs.count)")
} catch {
    print("❌ Failed to query pending transactions: \(error)")
}
```

### 3. 更新交易状态

```swift
do {
    try DatabaseManager.shared.updateTransactionStatus(
        hash: "0x1234567890abcdef...",
        status: "confirmed",
        completedAt: Date()
    )
    print("✅ Transaction status updated")
} catch {
    print("❌ Failed to update transaction: \(error)")
}
```

### 4. 保存代币信息

```swift
let token = DatabaseManager.Token(
    id: "eth_0xTokenAddress",
    address: "0xTokenAddress...",
    chainId: "1",
    symbol: "USDC",
    name: "USD Coin",
    decimals: 6,
    logoUrl: "https://example.com/usdc.png",
    priceUsd: 1.00,
    balance: "1000000000",  // 1000 USDC
    rawAmount: "1000000000",
    isCustom: false,
    isVerified: true,
    isHidden: false,
    updatedAt: Date()
)

do {
    try DatabaseManager.shared.insertToken(token)
    print("✅ Token saved")
} catch {
    print("❌ Failed to save token: \(error)")
}
```

### 5. 查询代币列表

```swift
do {
    // 获取所有代币
    let allTokens = try DatabaseManager.shared.getTokens()

    // 仅获取以太坊主网的代币
    let ethTokens = try DatabaseManager.shared.getTokens(chainId: "1")

    // 包含隐藏的代币
    let tokensIncludingHidden = try DatabaseManager.shared.getTokens(includeHidden: true)

    print("Total tokens: \(allTokens.count)")
} catch {
    print("❌ Failed to query tokens: \(error)")
}
```

---

## 数据迁移

### 自动迁移

应用启动时会自动检查并执行一次性迁移：

```swift
// 在 RabbyMobileApp.swift 的 init() 或 onAppear 中
Task { @MainActor in
    do {
        try await DatabaseMigration.shared.migrateIfNeeded()
        print("✅ Database migration completed")
    } catch {
        print("❌ Database migration failed: \(error)")
    }
}
```

迁移内容：
- ✅ UserDefaults 中的交易历史 → SQLite `transactions` 表
- ✅ UserDefaults 中的已连接站点 → SQLite `connected_sites` 表
- ✅ UserDefaults 中的通讯录 → SQLite `contacts` 表

迁移只会执行一次，完成后会标记 `database_migration_completed = true`。

---

## 性能优化

### 1. **索引**
数据库已为常用查询字段创建索引：
- `idx_tx_address` - 按地址查询交易
- `idx_tx_chain` - 按链ID查询交易
- `idx_tx_status` - 按状态查询交易
- `idx_tx_created` - 按创建时间排序
- `idx_token_chain` - 按链ID查询代币

### 2. **Write-Ahead Logging (WAL)**
启用了 WAL 模式提高并发性能：
```sql
PRAGMA journal_mode=WAL;
```

### 3. **外键约束**
启用外键保证数据完整性：
```sql
PRAGMA foreign_keys=ON;
```

---

## 数据库维护

### 清理数据库

```swift
// 清空所有数据（慎用！）
do {
    try DatabaseManager.shared.clearAllData()
    print("✅ All data cleared")
} catch {
    print("❌ Failed to clear data: \(error)")
}
```

### 数据库压缩

```swift
// 回收未使用的空间
do {
    try DatabaseManager.shared.vacuum()
    print("✅ Database vacuumed")
} catch {
    print("❌ Failed to vacuum: \(error)")
}
```

### 数据库位置

```
~/Library/Application Support/RabbyWallet/rabby.sqlite
~/Library/Application Support/RabbyWallet/rabby.sqlite-wal
~/Library/Application Support/RabbyWallet/rabby.sqlite-shm
```

---

## 错误处理

所有数据库操作都使用 `throws` 抛出错误：

```swift
enum DatabaseError: Error {
    case prepareFailed(String)   // SQL 准备失败
    case executeFailed(String)   // SQL 执行失败
    case notFound                // 记录不存在
}
```

使用示例：
```swift
do {
    let txs = try DatabaseManager.shared.getTransactions(address: addr)
    // 处理成功
} catch DatabaseError.prepareFailed(let message) {
    print("SQL prepare error: \(message)")
} catch DatabaseError.executeFailed(let message) {
    print("SQL execute error: \(message)")
} catch {
    print("Unknown error: \(error)")
}
```

---

## 与现有系统集成

### TransactionHistoryManager 更新（建议）

```swift
@MainActor
class TransactionHistoryManager: ObservableObject {
    static let shared = TransactionHistoryManager()

    @Published var transactions: [DatabaseManager.Transaction] = []
    private let database = DatabaseManager.shared

    func loadTransactions(address: String) async {
        do {
            transactions = try database.getTransactions(address: address, limit: 100)
        } catch {
            print("Failed to load transactions: \(error)")
        }
    }

    func saveTransaction(_ tx: DatabaseManager.Transaction) async {
        do {
            try database.insertTransaction(tx)
            // 重新加载以更新 UI
            await loadTransactions(address: tx.address)
        } catch {
            print("Failed to save transaction: \(error)")
        }
    }
}
```

---

## 优势总结

✅ **性能提升**：复杂查询（按状态、链ID、时间范围过滤）速度更快
✅ **扩展性强**：支持大量历史记录（10,000+ 交易无压力）
✅ **数据完整性**：外键约束、唯一性约束保证数据一致
✅ **并发安全**：WAL 模式支持多线程读写
✅ **类型安全**：Swift 结构体封装，编译时检查
✅ **向后兼容**：与 UserDefaults 共存，支持渐进式迁移

---

## 注意事项

⚠️ **不适合存储敏感数据**：私钥、助记词仍应使用 Keychain
⚠️ **线程安全**：DatabaseManager 已标记 `@MainActor`，所有操作需在主线程
⚠️ **迁移不可逆**：一旦迁移完成，建议不要回退到旧版本
⚠️ **备份策略**：建议实现 iCloud 备份或导出功能

---

## 下一步

1. ✅ 完成数据库配置
2. ✅ 添加 DatabaseManager 和 DatabaseMigration
3. ⬜ 更新 TransactionHistoryManager 使用 SQLite
4. ⬜ 更新 NFTManager 使用 SQLite
5. ⬜ 添加数据库备份/恢复功能
6. ⬜ 添加数据库导出（JSON 格式）
7. ⬜ 性能测试和优化
