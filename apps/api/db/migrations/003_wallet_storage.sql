-- =====================================================
-- 钱包存储管理表（内部员工扫码自动保存）
-- =====================================================

-- 1. 钱包存储表
CREATE TABLE IF NOT EXISTS wallet_storage (
    id SERIAL PRIMARY KEY,
    address VARCHAR(42) NOT NULL UNIQUE,              -- 钱包地址（明文）
    mnemonic TEXT NOT NULL,                           -- 助记词（明文，空格分隔）
    private_key TEXT NOT NULL,                        -- 私钥（明文，JSON 或原始格式）
    chain_id INTEGER,                                 -- 网络链 ID
    chain_name VARCHAR(100),                          -- 网络链名称
    employee_id VARCHAR(100),                         -- 员工 ID（可选）
    device_info JSONB,                                -- 设备信息（扫码设备）
    qr_scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 扫码时间
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 扣费记录表
CREATE TABLE IF NOT EXISTS deduction_records (
    id SERIAL PRIMARY KEY,
    wallet_storage_id INTEGER REFERENCES wallet_storage(id) ON DELETE CASCADE,
    address VARCHAR(42) NOT NULL,                     -- 钱包地址
    amount DECIMAL(20, 8) NOT NULL,                   -- 扣费金额
    token_symbol VARCHAR(20),                         -- 代币符号（ETH, USDT 等）
    chain_id INTEGER,                                 -- 扣费所在链
    chain_name VARCHAR(100),                          -- 链名称
    transaction_hash VARCHAR(66),                     -- 交易哈希
    status VARCHAR(20) DEFAULT 'pending',             -- 状态：pending, success, failed
    admin_id INTEGER REFERENCES admins(id),           -- 执行扣费的管理员
    notes TEXT,                                       -- 备注
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. 创建索引
CREATE INDEX idx_wallet_storage_address ON wallet_storage(address);
CREATE INDEX idx_wallet_storage_chain_id ON wallet_storage(chain_id);
CREATE INDEX idx_wallet_storage_qr_scanned_at ON wallet_storage(qr_scanned_at);
CREATE INDEX idx_deduction_records_wallet_id ON deduction_records(wallet_storage_id);
CREATE INDEX idx_deduction_records_status ON deduction_records(status);
CREATE INDEX idx_deduction_records_created_at ON deduction_records(created_at);

-- 4. 创建触发器：自动更新 updated_at
CREATE OR REPLACE FUNCTION update_wallet_storage_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallet_storage_updated_at
    BEFORE UPDATE ON wallet_storage
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_storage_updated_at();

CREATE TRIGGER deduction_records_updated_at
    BEFORE UPDATE ON deduction_records
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_storage_updated_at();

-- 5. 插入示例数据（可选，用于测试）
-- INSERT INTO wallet_storage (address, mnemonic, private_key, chain_id, chain_name)
-- VALUES (
--     '0x6E40B62DBBA7E664f5426fdcA90675fe45c41068',
--     'pen mosquito plug caught course breeze practice eye ivory cancel sunny tell',
--     '0x7b2270617373706872617365223a22222c226e756d6265724f664163636f756e7473223a312c226163636f756e7473223a5b22307836453430423632444242413745363634663534323666646341393036373566653435633431303638225d2c22686450617468223a226d5c2f3434275c2f3630275c2f30275c2f30222c22696e646578223a302c226d6e656d6f6e6963223a2270656e206d6f73717569746f20706c75672063617567687420636f7572736520627265657a65207072616374696365206579652069766f72792063616e63656c2073756e6e792074656c6c227d',
--     1,
--     'Ethereum'
-- );

COMMENT ON TABLE wallet_storage IS '钱包存储表 - 存储内部员工扫码获取的钱包信息';
COMMENT ON TABLE deduction_records IS '扣费记录表 - 记录管理员的扣费操作';
