import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { WalletProvider } from './contexts/WalletContext';
import { SettingsProvider } from './contexts/SettingsContext';
import { ChainProvider } from './contexts/ChainContext';
import { BalanceProvider } from './contexts/BalanceContext';
import { TokenProvider } from './contexts/TokenContext';
import { TransactionProvider } from './contexts/TransactionContext';
import MainLayout from './layouts/MainLayout';
import PlaceholderPage from './components/PlaceholderPage';

// Pages - directory-based modules
import Dashboard from './pages/dashboard';
import History from './pages/history';
import SendToken from './pages/send-token';
import SwapPage from './pages/swap';
import BridgePage from './pages/bridge';
import NFTPage from './pages/nft';
import ApprovalsPage from './pages/approvals';
import GasAccountPage from './pages/gas-account';
import RabbyPointsPage from './pages/rabby-points';
import SendNFTPage from './pages/send-nft';
import GnosisQueuePage from './pages/gnosis-queue';
import CustomRPCPage from './pages/custom-rpc';
import PerpsPage from './pages/perps';
import WelcomePage from './pages/welcome';

// Pages - flat files (kept as-is)
import Receive from './pages/Receive';
import Activities from './pages/Activities';
import DappSearch from './pages/DappSearch';
import Import from './pages/Import';
import SelectToAddress from './pages/SelectToAddress';
import Settings from './pages/Settings';
import AddressManagement from './pages/settings/AddressManagement';
import ChainList from './pages/settings/ChainList';
import ConnectedSites from './pages/settings/ConnectedSites';
import AdvancedSettings from './pages/settings/AdvancedSettings';

export default function App() {
  return (
    <SettingsProvider>
      <ChainProvider>
        <WalletProvider>
          <BalanceProvider>
            <TokenProvider>
              <TransactionProvider>
                <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
                  <Routes>
                    <Route path="/welcome" element={<WelcomePage />} />
                    <Route
                      path="/unlock"
                      element={<PlaceholderPage title="Unlock" description="Enter your password to unlock the wallet." />}
                    />
                    <Route
                      path="/forgot-password"
                      element={<PlaceholderPage title="Forgot Password" description="Recover access to your wallet." />}
                    />
                    <Route
                      path="/create-password"
                      element={<PlaceholderPage title="Create Password" description="Set a new password for your wallet." />}
                    />
                    <Route path="/" element={<MainLayout />}>
                      <Route index element={<Navigate to="/dashboard" replace />} />
                      <Route path="dashboard" element={<Dashboard />} />
                      <Route
                        path="dashboard/token-detail"
                        element={<PlaceholderPage title="Token Detail" description="Detailed token analytics and history." />}
                      />
                      <Route path="send-token" element={<SendToken />} />
                      <Route path="send-nft" element={<SendNFTPage />} />
                      <Route path="receive" element={<Receive />} />
                      <Route path="select-to-address" element={<SelectToAddress />} />
                      <Route path="swap" element={<SwapPage />} />
                      <Route path="dex-swap" element={<Navigate to="/swap" replace />} />
                      <Route path="bridge" element={<BridgePage />} />
                      <Route path="history" element={<History />} />
                      <Route
                        path="signed-text-history"
                        element={<PlaceholderPage title="Signed Text History" description="Review past signed messages." />}
                      />
                      <Route path="activities" element={<Activities />} />
                      <Route path="approval" element={<ApprovalsPage />} />
                      <Route path="approvals" element={<Navigate to="/approval" replace />} />
                      <Route path="token-approval" element={<ApprovalsPage variant="token" />} />
                      <Route path="nft-approval" element={<ApprovalsPage variant="nft" />} />
                      <Route path="nft-view" element={<NFTPage />} />
                      <Route path="nft" element={<Navigate to="/nft-view" replace />} />
                      <Route path="dapp-search" element={<DappSearch />} />
                      <Route path="connected-sites" element={<ConnectedSites />} />
                      <Route
                        path="request-permission"
                        element={<PlaceholderPage title="Permission Request" description="Review connection permissions." />}
                      />
                      <Route path="import/*" element={<Import />} />
                      <Route
                        path="add-address"
                        element={<PlaceholderPage title="Add Address" description="Add a new wallet address." />}
                      />
                      <Route
                        path="select-address"
                        element={<PlaceholderPage title="Select Address" description="Choose an address to continue." />}
                      />
                      <Route
                        path="import-success"
                        element={<PlaceholderPage title="Import Success" description="Your wallet is ready to use." />}
                      />
                      <Route path="address-management" element={<AddressManagement />} />
                      <Route
                        path="address-detail"
                        element={<PlaceholderPage title="Address Detail" description="Review address balances and history." />}
                      />
                      <Route
                        path="address-backup"
                        element={<PlaceholderPage title="Address Backup" description="Backup your private keys or seed phrase." />}
                      />
                      <Route path="settings" element={<Settings />}>
                        <Route path="address" element={<AddressManagement />} />
                        <Route path="chain-list" element={<ChainList />} />
                        <Route path="custom-rpc" element={<CustomRPCPage />} />
                        <Route
                          path="custom-testnet"
                          element={<PlaceholderPage title="Custom Testnet" description="Add or edit testnet configurations." />}
                        />
                        <Route path="sites" element={<ConnectedSites />} />
                        <Route path="advance" element={<AdvancedSettings />} />
                        <Route path="advanced" element={<Navigate to="/settings/advance" replace />} />
                        <Route
                          path="language"
                          element={<PlaceholderPage title="Language" description="Switch display language." />}
                        />
                        <Route
                          path="whitelist"
                          element={<PlaceholderPage title="Whitelist" description="Manage trusted addresses." />}
                        />
                        <Route
                          path="contacts"
                          element={<PlaceholderPage title="Contacts" description="Manage your address book." />}
                        />
                      </Route>
                      <Route path="custom-rpc" element={<CustomRPCPage />} />
                      <Route
                        path="custom-testnet"
                        element={<PlaceholderPage title="Custom Testnet" description="Add or edit testnet configurations." />}
                      />
                      <Route path="gas-account" element={<GasAccountPage />} />
                      <Route path="rabby-points" element={<RabbyPointsPage />} />
                      <Route path="perps" element={<PerpsPage />} />
                      <Route path="gnosis-queue" element={<GnosisQueuePage />} />
                      <Route path="*" element={<Navigate to="/dashboard" replace />} />
                    </Route>
                  </Routes>
                </BrowserRouter>
              </TransactionProvider>
            </TokenProvider>
          </BalanceProvider>
        </WalletProvider>
      </ChainProvider>
    </SettingsProvider>
  );
}
