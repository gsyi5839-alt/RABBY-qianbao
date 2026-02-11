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
import { useAuth } from './hooks/useAuth';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  if (!token) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<ProtectedRoute><AdminLayout /></ProtectedRoute>}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="chains" element={<ChainsPage />} />
          <Route path="tokens" element={<TokensPage />} />
          <Route path="security" element={<SecurityPage />} />
          <Route path="dapps" element={<DappsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="system" element={<SystemPage />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
