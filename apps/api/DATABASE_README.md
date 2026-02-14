# PostgreSQL 数据库配置指南

## ✅ 已完成的工作

### 1. 数据库架构
- ✅ 完整的 PostgreSQL schema (`db/schema.sql`)
- ✅ 8 张表：users, dapp_entries, chain_configs, security_rules, phishing_entries, contract_whitelist, security_alerts, transactions
- ✅ 自动更新 `updated_at` 触发器
- ✅ 完整的索引优化
- ✅ 种子数据（10个DApp, 6条安全规则等）

### 2. 数据库管理器
- ✅ Database class (`src/services/database.ts`)
- ✅ 连接池管理（最大20个连接）
- ✅ 查询助手函数
- ✅ 事务支持
- ✅ 慢查询日志（>1s）
- ✅ 连接健康检查

### 3. UserStore 迁移
- ✅ 从内存存储改为 PostgreSQL
- ✅ 所有方法改为 async
- ✅ 保留 NonceStore（内存存储临时 nonce）

### 4. 开发工具
- ✅ Docker Compose 配置（PostgreSQL + pgAdmin）
- ✅ 环境变量示例 (`.env.example`)
- ✅ 自动执行 schema.sql 初始化

### 5. 配置文件
- ✅ 更新 `package.json`（添加 `pg` 和 `@types/pg`）
- ✅ 更新 `config.ts`（添加数据库配置）

---

## 🚀 快速开始

### 方案 1：使用 Docker（推荐）

#### 1. 启动 PostgreSQL 和 pgAdmin
```bash
cd apps/api
docker-compose up -d
```

这将启动：
- **PostgreSQL**：http://localhost:5432
- **pgAdmin**：http://localhost:5050（用户名：`admin@rabby.local`，密码：`admin`）

#### 2. 验证数据库连接
```bash
# 进入 PostgreSQL 容器
docker exec -it rabby_postgres psql -U rabby_user -d rabby_db

# 查看所有表
\dt

# 查看种子数据
SELECT COUNT(*) FROM dapp_entries;  -- 应该返回 10
SELECT COUNT(*) FROM security_rules; -- 应该返回 6
\q
```

#### 3. 安装依赖
```bash
cd apps/api
yarn install  # 或 npm install
```

#### 4. 创建 .env 文件
```bash
cp .env.example .env
```

确保 `.env` 中数据库配置为：
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=rabby_db
DATABASE_USER=rabby_user
DATABASE_PASSWORD=rabby_password
```

#### 5. 启动 API 服务器
```bash
yarn dev
```

查看启动日志，应该看到：
```
✅ Database connected at: 2026-02-14T...
Rabby API running on http://localhost:3001
```

---

### 方案 2：本地 PostgreSQL（手动安装）

#### 1. 安装 PostgreSQL
```bash
# macOS (Homebrew)
brew install postgresql@16
brew services start postgresql@16

# Ubuntu/Debian
sudo apt-get install postgresql-16

# Windows
# 下载安装包：https://www.postgresql.org/download/windows/
```

#### 2. 创建数据库和用户
```bash
# 进入 PostgreSQL shell
psql postgres

# 创建用户和数据库
CREATE USER rabby_user WITH PASSWORD 'rabby_password';
CREATE DATABASE rabby_db OWNER rabby_user;
GRANT ALL PRIVILEGES ON DATABASE rabby_db TO rabby_user;
\q
```

#### 3. 初始化数据库 schema
```bash
cd apps/api
psql -U rabby_user -d rabby_db < db/schema.sql
```

#### 4. 配置和启动（同方案1的步骤3-5）

---

## 📂 数据库结构

### 核心表

#### `users` - 用户表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| address | VARCHAR(42) | 主要以太坊地址（唯一） |
| addresses | TEXT[] | 所有关联地址数组 |
| role | VARCHAR(20) | 用户角色 (user/admin) |
| created_at | BIGINT | 创建时间戳（毫秒） |

#### `dapp_entries` - DApp 目录
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(255) | DApp 名称 |
| url | TEXT | DApp URL |
| category | VARCHAR(50) | 分类 (DEX/NFT/Lending/Staking/Perps) |
| status | VARCHAR(20) | 状态 (approved/pending/rejected) |
| risk_level | VARCHAR(20) | 风险等级 (low/medium/high) |
| enabled | BOOLEAN | 是否启用 |
| order | INTEGER | 排序号 |

#### `security_rules` - 安全规则
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(255) | 规则名称 |
| type | VARCHAR(50) | 类型 (transfer/contract/phishing/approval/gas) |
| severity | VARCHAR(20) | 严重性 (low/medium/high/critical) |
| enabled | BOOLEAN | 是否启用 |
| triggers | INTEGER | 触发次数 |

#### `phishing_entries` - 钓鱼网站黑名单
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| address | VARCHAR(42) | 钓鱼地址 |
| domain | TEXT | 钓鱼域名 |
| type | VARCHAR(50) | 类型 (scam_site/phishing/impersonation) |
| status | VARCHAR(20) | 状态 (confirmed/pending) |

完整 schema 请查看 `apps/api/db/schema.sql`

---

## 🔧 API 使用示例

### UserStore（已更新为 PostgreSQL）

```typescript
import { userStore } from './services/userStore';

// 创建用户（异步）
const user = await userStore.create('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');

// 查找用户
const foundUser = await userStore.findByAddress('0x742d35Cc...');
const userById = await userStore.findById('some-uuid');

// 添加地址
await userStore.addAddress(user.id, '0xAnotherAddress...');

// 获取所有用户（分页）
const users = await userStore.getAll(100, 0);  // limit=100, offset=0

// 统计用户数
const count = await userStore.count();
```

### Database 直接查询

```typescript
import { db } from './services/database';

// 简单查询
const result = await db.query(
  'SELECT * FROM dapp_entries WHERE category = $1 AND enabled = true',
  ['DEX']
);

// 事务
const result = await db.transaction(async (client) => {
  await client.query('INSERT INTO users (address, role) VALUES ($1, $2)', ['0x123...', 'user']);
  await client.query('INSERT INTO dapp_entries (name, url) VALUES ($1, $2)', ['MyDApp', 'https://...']);
  return { success: true };
});
```

---

## 🔄 迁移现有 Stores

### AdminStore - TODO
需要迁移：
- `dapps` Map → `dapp_entries` 表
- `chains` Map → `chain_configs` 表

### SecurityStore - TODO
需要迁移：
- `rules` Map → `security_rules` 表
- `phishing` Map → `phishing_entries` 表
- `contracts` Map → `contract_whitelist` 表
- `alerts` Map → `security_alerts` 表

---

## 🛠️ 数据库管理命令

### 连接数据库
```bash
# Docker
docker exec -it rabby_postgres psql -U rabby_user -d rabby_db

# 本地
psql -U rabby_user -d rabby_db
```

### 常用 SQL 命令
```sql
-- 查看所有表
\dt

-- 查看表结构
\d users

-- 查看索引
\di

-- 查询示例
SELECT * FROM dapp_entries WHERE enabled = true ORDER BY "order";
SELECT * FROM users LIMIT 10;
SELECT * FROM security_rules WHERE severity = 'critical';

-- 统计
SELECT category, COUNT(*) FROM dapp_entries GROUP BY category;
SELECT COUNT(*) FROM users;
```

### 备份和恢复
```bash
# 备份
pg_dump -U rabby_user rabby_db > backup_$(date +%Y%m%d).sql

# 恢复
psql -U rabby_user -d rabby_db < backup_20260214.sql
```

---

## 📊 pgAdmin 使用

访问 http://localhost:5050

1. 登录：
   - Email: `admin@rabby.local`
   - Password: `admin`

2. 添加服务器：
   - Name: Rabby Database
   - Host: `postgres`（Docker 内部网络）或 `localhost`（本地）
   - Port: `5432`
   - Database: `rabby_db`
   - Username: `rabby_user`
   - Password: `rabby_password`

3. 功能：
   - 可视化查询编辑器
   - 表数据浏览
   - 性能分析
   - 数据导入/导出

---

## 🚨 故障排除

### 问题 1：连接被拒绝
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**解决方案**：
- 检查 PostgreSQL 是否运行：`docker ps` 或 `brew services list`
- 检查端口是否占用：`lsof -i :5432`
- 查看 Docker 日志：`docker logs rabby_postgres`

### 问题 2：认证失败
```
Error: password authentication failed for user "rabby_user"
```

**解决方案**：
- 检查 `.env` 中的密码是否正确
- 检查 `docker-compose.yml` 中的环境变量
- 重新创建容器：`docker-compose down -v && docker-compose up -d`

### 问题 3：表不存在
```
Error: relation "users" does not exist
```

**解决方案**：
```bash
# 手动执行 schema.sql
docker exec -i rabby_postgres psql -U rabby_user -d rabby_db < db/schema.sql
```

### 问题 4：慢查询
查看慢查询日志（>1秒的查询会自动打印）：
```
⚠️ Slow query (1523ms): SELECT * FROM transactions WHERE...
```

**优化建议**：
- 添加索引
- 使用 `LIMIT` 限制结果数量
- 使用 `EXPLAIN ANALYZE` 分析查询计划

---

## 🔐 生产环境配置

### 1. 强密码
```env
DATABASE_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 64)
```

### 2. SSL 连接
更新 `src/services/database.ts`：
```typescript
new Pool({
  ...config.database,
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/ca-certificate.crt').toString(),
  }
});
```

### 3. 连接池优化
```typescript
max: 20,              // 根据服务器性能调整
idleTimeoutMillis: 30000,
connectionTimeoutMillis: 2000,
```

### 4. 定期备份
```bash
# Cron job (每天凌晨2点备份)
0 2 * * * pg_dump -U rabby_user rabby_db | gzip > /backups/rabby_$(date +\%Y\%m\%d).sql.gz
```

---

## 📈 性能监控

### 连接池统计
```typescript
import { db } from './services/database';

console.log(db.getStats());
// {
//   totalCount: 5,    // 总连接数
//   idleCount: 3,     // 空闲连接数
//   waitingCount: 0   // 等待连接数
// }
```

### 查询性能
所有查询会自动记录执行时间，超过 1 秒的查询会打印警告。

---

## 📝 下一步

1. ✅ UserStore 已迁移
2. ⬜ 迁移 AdminStore（dapps, chains）
3. ⬜ 迁移 SecurityStore（rules, phishing, contracts, alerts）
4. ⬜ 更新所有路由处理 async/await
5. ⬜ 添加数据库迁移工具（自动版本管理）
6. ⬜ 添加单元测试
7. ⬜ 配置 CI/CD 自动化测试

---

## 🆘 需要帮助？

- 查看 PostgreSQL 文档：https://www.postgresql.org/docs/
- 查看 node-postgres 文档：https://node-postgres.com/
- 查看项目 issue：https://github.com/your-repo/issues
