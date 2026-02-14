import { LanguageProvider } from './contexts/LanguageContext';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';

// ── Existing public pages ──
import LandingPage from './pages/LandingPage';
import MultiChainWalletPage from './pages/MultiChainWalletPage';

// ── Welcome / Onboarding ──
import { WelcomePage } from './pages/welcome';

// ── Account pages (auth + new-user flow) ──
import {
  CreatePasswordPage,
  UnlockPage,
  NoAddressPage,
  GuidePage,
  ImportListPage,
  CreateSeedPhrasePage,
  ImportSeedPhrasePage,
  ImportPrivateKeyPage,
  SetPasswordPage,
  SuccessPage,
} from './pages/account';

// ── Dashboard ──
import { DashboardPage } from './pages/dashboard';

// ── Layout / Guards ──
import ProtectedRoute from './components/layout/ProtectedRoute';

// ── Send / Receive / NFT pages ──
import { SendTokenPage } from './pages/send';
import { ReceivePage } from './pages/receive';
import { SendNFTPage } from './pages/send-nft';
import { SelectToAddressPage } from './pages/select-address';

// ── History & Approval pages ──
import { HistoryPage } from './pages/history';
import { ApprovalPage } from './pages/approval';

// ── Swap & Bridge ──
import { SwapPage } from './pages/swap';
import { BridgePage } from './pages/bridge';

// ── NFT ──
import { NFTPage } from './pages/nft';

// ── Settings ──
import {
  SettingsPage,
  AddressManagementPage,
  ChainListPage,
  ConnectedSitesPage,
  AdvancedSettingsPage,
  SwitchLanguagePage,
} from './pages/settings';

// ── Generic placeholder for unfinished routes ──
import Placeholder from './pages/Placeholder';

export default function App() {
  return (
    <LanguageProvider>
      <Router>
        <Routes>
          {/* ────────────────────────────────────────────
              Public routes (no auth required)
          ──────────────────────────────────────────── */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/multi-chain" element={<MultiChainWalletPage />} />

          {/* Welcome / onboarding */}
          <Route path="/welcome" element={<WelcomePage />} />
          <Route path="/password" element={<CreatePasswordPage />} />
          <Route path="/unlock" element={<UnlockPage />} />
          <Route path="/no-address" element={<NoAddressPage />} />

          {/* ────────────────────────────────────────────
              New-user guided flow
              (mirrors extension /new-user/* routes)
          ──────────────────────────────────────────── */}
          <Route path="/new-user/guide" element={<GuidePage />} />
          <Route path="/new-user/import-list" element={<ImportListPage />} />
          <Route path="/new-user/create-seed-phrase" element={<CreateSeedPhrasePage />} />
          <Route path="/new-user/import/seed-phrase" element={<ImportSeedPhrasePage />} />
          <Route path="/new-user/import/private-key" element={<ImportPrivateKeyPage />} />
          <Route path="/new-user/set-password" element={<SetPasswordPage />} />
          <Route path="/new-user/import/:type/set-password" element={<SetPasswordPage />} />
          <Route path="/new-user/success" element={<SuccessPage />} />
          <Route path="/new-user/backup-seed-phrase" element={<Placeholder title="Backup Seed Phrase" />} />
          <Route path="/new-user/ready" element={<Placeholder title="Ready to Use" />} />
          <Route path="/new-user/import/select-address" element={<Placeholder title="Select Address" />} />

          {/* ────────────────────────────────────────────
              Protected routes (require unlocked wallet)
          ──────────────────────────────────────────── */}
          <Route element={<ProtectedRoute />}>
            {/* Dashboard */}
            <Route path="/dashboard" element={<DashboardPage />} />

            {/* Send & Receive */}
            <Route path="/send-token" element={<SendTokenPage />} />
            <Route path="/send-nft" element={<SendNFTPage />} />
            <Route path="/select-to-address" element={<SelectToAddressPage />} />
            <Route path="/receive" element={<ReceivePage />} />

            {/* Swap & Bridge */}
            <Route path="/dex-swap" element={<SwapPage />} />
            <Route path="/bridge" element={<BridgePage />} />

            {/* History & Activities */}
            <Route path="/history" element={<HistoryPage />} />
            <Route path="/history/filter-scam" element={<HistoryPage isFilterScam />} />
            <Route path="/activities" element={<HistoryPage />} />

            {/* NFT */}
            <Route path="/nft" element={<NFTPage />} />

            {/* Approvals */}
            <Route path="/approval" element={<ApprovalPage />} />
            <Route path="/token-approval" element={<ApprovalPage />} />
            <Route path="/nft-approval" element={<ApprovalPage />} />

            {/* Address management */}
            <Route path="/add-address" element={<Placeholder title="Add Address" />} />
            <Route path="/switch-address" element={<Placeholder title="Switch Address" />} />

            {/* Import (post-auth) */}
            <Route path="/import" element={<Placeholder title="Import" />} />
            <Route path="/import/key" element={<Placeholder title="Import Private Key" />} />
            <Route path="/import/json" element={<Placeholder title="Import KeyStore" />} />
            <Route path="/import/mnemonics" element={<Placeholder title="Import Seed Phrase" />} />
            <Route path="/import/select-address" element={<Placeholder title="Select Address" />} />
            <Route path="/import/hardware" element={<Placeholder title="Import Hardware" />} />
            <Route path="/import/hardware/ledger-connect" element={<Placeholder title="Ledger Connect" />} />
            <Route path="/import/hardware/trezor-connect" element={<Placeholder title="Trezor Connect" />} />
            <Route path="/import/hardware/onekey" element={<Placeholder title="OneKey Connect" />} />
            <Route path="/import/hardware/imkey-connect" element={<Placeholder title="imKey Connect" />} />
            <Route path="/import/hardware/keystone" element={<Placeholder title="Keystone Connect" />} />
            <Route path="/import/hardware/qrcode" element={<Placeholder title="QR Code Connect" />} />
            <Route path="/import/watch-address" element={<Placeholder title="Watch Address" />} />
            <Route path="/import/wallet-connect" element={<Placeholder title="WalletConnect" />} />
            <Route path="/import/gnosis" element={<Placeholder title="Import Gnosis" />} />
            <Route path="/import/cobo-argus" element={<Placeholder title="Import Cobo Argus" />} />
            <Route path="/import/coinbase" element={<Placeholder title="Import Coinbase" />} />
            <Route path="/import/metamask" element={<Placeholder title="Import MetaMask" />} />
            <Route path="/import/success" element={<Placeholder title="Import Success" />} />
            <Route path="/popup/import/success" element={<Placeholder title="Import Success" />} />
            <Route path="/import/add-from-current-seed-phrase" element={<Placeholder title="Add From Seed Phrase" />} />
            <Route path="/mnemonics/create" element={<Placeholder title="Create Mnemonics" />} />

            {/* Settings */}
            <Route path="/settings/address" element={<AddressManagementPage />} />
            <Route path="/settings/address-detail" element={<Placeholder title="Address Detail" />} />
            <Route path="/settings/address-backup/private-key" element={<Placeholder title="Backup Private Key" />} />
            <Route path="/settings/address-backup/mneonics" element={<Placeholder title="Backup Mnemonics" />} />
            <Route path="/settings/sites" element={<ConnectedSitesPage />} />
            <Route path="/settings/chain-list" element={<ChainListPage />} />
            <Route path="/settings/switch-lang" element={<SwitchLanguagePage />} />
            <Route path="/settings/advanced" element={<AdvancedSettingsPage />} />
            <Route path="/settings/*" element={<SettingsPage />} />

            {/* DApp & Search */}
            <Route path="/dapp-search" element={<Placeholder title="DApp Search" />} />
            <Route path="/metamask-mode-dapps" element={<Placeholder title="MetaMask Mode DApps" />} />
            <Route path="/metamask-mode-dapps/list" element={<Placeholder title="MetaMask DApps List" />} />

            {/* Utility */}
            <Route path="/custom-rpc" element={<Placeholder title="Custom RPC" />} />
            <Route path="/custom-testnet" element={<Placeholder title="Custom Testnet" />} />
            <Route path="/request-permission" element={<Placeholder title="Request Permission" />} />
            <Route path="/whitelist-input" element={<Placeholder title="Whitelist Input" />} />

            {/* Rabby Points & Gas */}
            <Route path="/rabby-points" element={<Placeholder title="Rabby Points" />} />
            <Route path="/gas-account" element={<Placeholder title="Gas Account" />} />
            <Route path="/gnosis-queue" element={<Placeholder title="Gnosis Queue" />} />

            {/* Ecology */}
            <Route path="/ecology/:chainId" element={<Placeholder title="Ecology" />} />

            {/* Perps */}
            <Route path="/perps" element={<Placeholder title="Perps" />} />
            <Route path="/perps/single-coin/:coin" element={<Placeholder title="Perps - Coin" />} />
            <Route path="/perps/explore" element={<Placeholder title="Perps - Explore" />} />
            <Route path="/perps/history/:coin" element={<Placeholder title="Perps - History" />} />
          </Route>

          {/* ────────────────────────────────────────────
              Catch-all: redirect unknown routes to landing
          ──────────────────────────────────────────── */}
          <Route path="*" element={<Placeholder title="Page Not Found" />} />
        </Routes>
      </Router>
    </LanguageProvider>
  );
}
