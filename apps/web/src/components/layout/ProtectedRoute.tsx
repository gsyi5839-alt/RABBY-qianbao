import React from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAccountStore } from '../../store/account';

/**
 * ProtectedRoute — guards routes that require an unlocked wallet with at least one account.
 *
 * Redirect rules (matching the extension's PrivateRoute behaviour):
 *  1. Wallet is locked           -> /unlock
 *  2. No accounts exist at all   -> /welcome
 *  3. Otherwise                  -> render child routes via <Outlet />
 */
const ProtectedRoute: React.FC = () => {
  const location = useLocation();
  const { isLocked, accounts } = useAccountStore();

  // If the wallet is locked, send the user to the unlock screen,
  // preserving the original destination so we can redirect back after unlock.
  if (isLocked) {
    return <Navigate to="/unlock" state={{ from: location }} replace />;
  }

  // If there are zero accounts the user hasn't onboarded yet.
  if (!accounts || accounts.length === 0) {
    return <Navigate to="/welcome" replace />;
  }

  return <Outlet />;
};

export default ProtectedRoute;
