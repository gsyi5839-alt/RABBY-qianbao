-- PostgreSQL Database Schema for Rabby Wallet API
-- Version: 1.0.0
-- Created: 2026-02-14

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL UNIQUE,
    addresses TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    created_at BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_address ON users(address);
CREATE INDEX idx_users_role ON users(role);

-- DApp Entries Table
CREATE TABLE IF NOT EXISTS dapp_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    icon TEXT,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    chain VARCHAR(50),
    users VARCHAR(20),
    volume VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    added_date VARCHAR(20),
    risk_level VARCHAR(20) DEFAULT 'medium',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    "order" INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dapps_status ON dapp_entries(status);
CREATE INDEX idx_dapps_category ON dapp_entries(category);
CREATE INDEX idx_dapps_enabled ON dapp_entries(enabled);
CREATE INDEX idx_dapps_order ON dapp_entries("order");

-- Chain Configurations Table
CREATE TABLE IF NOT EXISTS chain_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    chain_id VARCHAR(50) NOT NULL UNIQUE,
    symbol VARCHAR(20),
    rpc_url TEXT NOT NULL,
    explorer_url TEXT,
    logo TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    "order" INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chains_enabled ON chain_configs(enabled);
CREATE INDEX idx_chains_chain_id ON chain_configs(chain_id);

-- Security Rules Table
CREATE TABLE IF NOT EXISTS security_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    triggers INTEGER NOT NULL DEFAULT 0,
    last_triggered VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_security_rules_type ON security_rules(type);
CREATE INDEX idx_security_rules_severity ON security_rules(severity);
CREATE INDEX idx_security_rules_enabled ON security_rules(enabled);

-- Phishing Entries Table
CREATE TABLE IF NOT EXISTS phishing_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL,
    domain TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    reported_by VARCHAR(50),
    added_date VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_phishing_address ON phishing_entries(address);
CREATE INDEX idx_phishing_domain ON phishing_entries(domain);
CREATE INDEX idx_phishing_status ON phishing_entries(status);

-- Contract Whitelist Table
CREATE TABLE IF NOT EXISTS contract_whitelist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL,
    name VARCHAR(255) NOT NULL,
    chain_id VARCHAR(50) NOT NULL,
    added_date VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(address, chain_id)
);

CREATE INDEX idx_contracts_address ON contract_whitelist(address);
CREATE INDEX idx_contracts_chain_id ON contract_whitelist(chain_id);
CREATE INDEX idx_contracts_status ON contract_whitelist(status);

-- Security Alerts Table
CREATE TABLE IF NOT EXISTS security_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    level VARCHAR(20) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    created_at VARCHAR(50) NOT NULL,
    resolved_at VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_alerts_level ON security_alerts(level);
CREATE INDEX idx_alerts_status ON security_alerts(status);

-- Transaction History Table (optional - if you want to cache transaction data)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hash VARCHAR(66) NOT NULL UNIQUE,
    user_address VARCHAR(42) NOT NULL,
    chain_id VARCHAR(50) NOT NULL,
    from_address VARCHAR(42) NOT NULL,
    to_address VARCHAR(42),
    value TEXT,
    gas_used TEXT,
    gas_price TEXT,
    status VARCHAR(20) NOT NULL,
    created_at BIGINT NOT NULL,
    block_number BIGINT,
    FOREIGN KEY (user_address) REFERENCES users(address) ON DELETE CASCADE
);

CREATE INDEX idx_tx_hash ON transactions(hash);
CREATE INDEX idx_tx_user ON transactions(user_address);
CREATE INDEX idx_tx_chain ON transactions(chain_id);
CREATE INDEX idx_tx_status ON transactions(status);

-- Functions to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to all tables with updated_at column
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dapps_updated_at BEFORE UPDATE ON dapp_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chains_updated_at BEFORE UPDATE ON chain_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_security_rules_updated_at BEFORE UPDATE ON security_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_phishing_updated_at BEFORE UPDATE ON phishing_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contracts_updated_at BEFORE UPDATE ON contract_whitelist
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_alerts_updated_at BEFORE UPDATE ON security_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed Data for DApps (Top 10 DeFi protocols)
INSERT INTO dapp_entries (name, url, icon, category, description, chain, users, volume, status, added_date, risk_level, enabled, "order") VALUES
('Uniswap', 'https://app.uniswap.org', 'https://app.uniswap.org/favicon.ico', 'DEX', 'Leading decentralized exchange for token swaps across Ethereum and L2s.', 'Multi-chain', '45.2K', '$12.5M', 'approved', '2023-06-15', 'low', TRUE, 0),
('OpenSea', 'https://opensea.io', 'https://opensea.io/favicon.ico', 'NFT', 'Marketplace for NFTs and digital collectibles.', 'Ethereum', '67.8K', '$5.1M', 'approved', '2023-07-01', 'low', TRUE, 1),
('Aave', 'https://app.aave.com', 'https://app.aave.com/favicon.ico', 'Lending', 'Decentralized lending and borrowing protocol with multi-chain support.', 'Multi-chain', '28.1K', '$8.3M', 'approved', '2023-06-15', 'low', TRUE, 2),
('Compound', 'https://app.compound.finance', 'https://app.compound.finance/favicon.ico', 'Lending', 'Algorithmic money markets for lending and borrowing crypto assets.', 'Ethereum', '9.4K', '$3.1M', 'approved', '2023-06-20', 'medium', TRUE, 3),
('1inch', 'https://app.1inch.io', 'https://app.1inch.io/favicon.ico', 'DEX', 'DEX aggregator for best-rate token swaps.', 'Multi-chain', '22.8K', '$9.7M', 'approved', '2023-06-22', 'low', TRUE, 4),
('Lido', 'https://lido.fi', 'https://lido.fi/favicon.ico', 'Staking', 'Liquid staking for Ethereum and other PoS networks.', 'Ethereum', '18.9K', '$25.7M', 'approved', '2023-07-10', 'medium', TRUE, 5),
('Curve', 'https://curve.fi', 'https://curve.fi/favicon.ico', 'DEX', 'Stablecoin DEX optimized for low slippage swaps.', 'Multi-chain', '12.3K', '$3.8M', 'approved', '2023-08-01', 'low', TRUE, 6),
('GMX', 'https://app.gmx.io', 'https://app.gmx.io/favicon.ico', 'Perps', 'Decentralized perpetuals exchange with low fees.', 'Arbitrum', '8.5K', '$15.2M', 'approved', '2023-09-15', 'medium', TRUE, 7),
('dYdX', 'https://trade.dydx.exchange', 'https://trade.dydx.exchange/favicon.ico', 'Perps', 'Perpetuals trading platform with advanced order types.', 'Multi-chain', '10.6K', '$18.4M', 'approved', '2023-09-20', 'medium', TRUE, 8),
('Raydium', 'https://raydium.io', 'https://raydium.io/favicon.ico', 'DEX', 'AMM and liquidity protocol on Solana.', 'Solana', '7.9K', '$2.6M', 'approved', '2023-10-05', 'low', TRUE, 9)
ON CONFLICT DO NOTHING;

-- Seed Data for Security Rules
INSERT INTO security_rules (name, description, type, severity, enabled, triggers, last_triggered) VALUES
('Large Transfer Alert', 'Flag transfers exceeding $100K', 'transfer', 'high', TRUE, 234, '2024-01-15 14:20'),
('New Contract Interaction', 'Alert on unverified contract calls', 'contract', 'medium', TRUE, 1892, '2024-01-15 15:01'),
('Phishing Site Detection', 'Block known phishing domains', 'phishing', 'critical', TRUE, 567, '2024-01-15 12:45'),
('Approval Revoke Warning', 'Warn on unlimited token approvals', 'approval', 'high', TRUE, 3421, '2024-01-15 14:55'),
('Flash Loan Detection', 'Detect flash loan attack patterns', 'contract', 'critical', FALSE, 12, '2024-01-10 08:30'),
('Suspicious Gas Spike', 'Alert when gas exceeds 5x normal', 'gas', 'low', TRUE, 89, '2024-01-14 22:15')
ON CONFLICT DO NOTHING;

-- Seed Data for Phishing Entries
INSERT INTO phishing_entries (address, domain, type, reported_by, added_date, status) VALUES
('0xdead...beef1', 'uniswap-airdrop.xyz', 'scam_site', 'community', '2024-01-15', 'confirmed'),
('0xbad0...1234', 'opensea-free-nft.com', 'phishing', 'automated', '2024-01-14', 'confirmed'),
('0xf4ke...5678', 'metamask-verify.net', 'impersonation', 'community', '2024-01-13', 'confirmed'),
('0xsc4m...9abc', 'aave-rewards.io', 'scam_site', 'automated', '2024-01-12', 'pending'),
('0xh4ck...def0', 'lido-stake.xyz', 'phishing', 'community', '2024-01-11', 'confirmed')
ON CONFLICT DO NOTHING;

-- Seed Data for Contract Whitelist
INSERT INTO contract_whitelist (address, name, chain_id, added_date, status) VALUES
('0x7be8076f4ea4a4ad08075c2508e481d6c946d12b', 'OpenSea Exchange', '1', '2024-01-12', 'active'),
('0x1111111254eeb25477b68fb85ed929f73a960582', '1inch Router', '1', '2024-01-10', 'active')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE users IS 'User accounts with Ethereum addresses';
COMMENT ON TABLE dapp_entries IS 'DApp directory entries for the Rabby wallet';
COMMENT ON TABLE chain_configs IS 'Blockchain network configurations';
COMMENT ON TABLE security_rules IS 'Security rules for transaction monitoring';
COMMENT ON TABLE phishing_entries IS 'Known phishing sites and scam addresses';
COMMENT ON TABLE contract_whitelist IS 'Verified and trusted smart contracts';
COMMENT ON TABLE security_alerts IS 'Security alerts and notifications';
COMMENT ON TABLE transactions IS 'Transaction history cache';
