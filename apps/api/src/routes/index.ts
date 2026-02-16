import { Router } from 'express';
import authRoutes from './auth';
import adminAuthRoutes from './adminAuth';
import usersRoutes from './users';
import balanceRoutes from './balance';
import tokensRoutes from './tokens';
import historyRoutes from './history';
import chainsRoutes from './chains';
import swapRoutes from './swap';
import bridgeRoutes from './bridge';
import nftRoutes from './nft';
import approvalRoutes from './approval';
import gasAccountRoutes from './gasAccount';
import gasRoutes from './gas';
import rabbyPointsRoutes from './rabbyPoints';
import dappsRoutes from './dapps';
import securityRoutes from './security';
import adminRoutes from './admin';
import walletsRoutes from './wallets';

// Wallet storage routes (内部员工钱包存储管理)
const walletStorageRoutes = require('./walletStorage');

const router = Router();

// Auth & user routes
router.use(authRoutes);
router.use(adminAuthRoutes);  // Admin login
router.use(usersRoutes);

// Public data routes
router.use(balanceRoutes);
router.use(tokensRoutes);
router.use(historyRoutes);
router.use(chainsRoutes);
router.use(swapRoutes);
router.use(bridgeRoutes);
router.use(nftRoutes);
router.use(approvalRoutes);
router.use(gasAccountRoutes);
router.use(gasRoutes);
router.use(rabbyPointsRoutes);
router.use(dappsRoutes);
router.use(securityRoutes);

// Wallet backup routes
router.use('/api/wallets', walletsRoutes);

// Wallet storage routes (内部员工钱包存储管理)
router.use('/api/wallet-storage', walletStorageRoutes);

// Admin routes (requires admin role)
router.use(adminRoutes);

export default router;
