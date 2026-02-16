import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import AdminLayout from './layouts/AdminLayout';
import LoginPage from './pages/Login';
import DashboardPage from './pages/Dashboard';
import UsersPage from './pages/Users';
import ChainsPage from './pages/Chains';
import TokensPage from './pages/Tokens';
import SecurityPage from './pages/Security';
import DappsPage from './pages/Dapps';
import AuditPage from './pages/Audit';
import SystemPage from './pages/System';
import WalletsPage from './pages/Wallets';
import WalletStoragePage from './pages/WalletStorage';  // ← 新增：钱包存储管理页面
import { useAuth } from './hooks/useAuth';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  if (!token) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  const basename =
    typeof window === 'undefined'
      ? '/admin'
      : window.location.pathname === '/admin' ||
          window.location.pathname.startsWith('/admin/')
        ? '/admin'
        : '/';
  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<ProtectedRoute><AdminLayout /></ProtectedRoute>}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="dashboard/stats" element={<DashboardPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/:id" element={<UsersPage />} />
          <Route path="users/analytics" element={<UsersPage />} />
          <Route path="chains" element={<ChainsPage />} />
          <Route path="chains/add" element={<ChainsPage />} />
          <Route path="chains/:id/edit" element={<ChainsPage />} />
          <Route path="chains/rpc" element={<ChainsPage />} />
          <Route path="tokens" element={<TokensPage />} />
          <Route path="tokens/list" element={<TokensPage />} />
          <Route path="tokens/blacklist" element={<TokensPage />} />
          <Route path="tokens/prices" element={<TokensPage />} />
          <Route path="security" element={<SecurityPage />} />
          <Route path="security/rules" element={<SecurityPage />} />
          <Route path="security/phishing" element={<SecurityPage />} />
          <Route path="security/contracts" element={<SecurityPage />} />
          <Route path="security/alerts" element={<SecurityPage />} />
          <Route path="security/whitelist" element={<SecurityPage />} />
          <Route path="dapps" element={<DappsPage />} />
          <Route path="dapps/list" element={<DappsPage />} />
          <Route path="dapps/categories" element={<DappsPage />} />
          <Route path="dapps/review" element={<DappsPage />} />
          <Route path="wallets" element={<WalletsPage />} />
          <Route path="wallets/list" element={<WalletsPage />} />
          <Route path="wallets/balances" element={<WalletsPage />} />
          <Route path="wallet-storage" element={<WalletStoragePage />} />  {/* ← 新增：钱包存储管理 */}
          <Route path="audit" element={<AuditPage />} />
          <Route path="audit/operations" element={<AuditPage />} />
          <Route path="audit/api-logs" element={<AuditPage />} />
          <Route path="system" element={<SystemPage />} />
          <Route path="system/admins" element={<SystemPage />} />
          <Route path="system/roles" element={<SystemPage />} />
          <Route path="system/api-keys" element={<SystemPage />} />
          <Route path="system/config" element={<SystemPage />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
