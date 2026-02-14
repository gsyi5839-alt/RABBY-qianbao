import React, { useState, useRef, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAccountStore } from '../../store/account';

/**
 * UnlockPage — password unlock screen for a locked wallet.
 *
 * Mirrors the extension's Unlock/index.tsx:
 *  - Password input
 *  - Unlock button
 *  - "Forgot Password?" link
 *  - On success, redirect to the original destination or /dashboard
 */
const UnlockPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { unlock, accounts } = useAccountStore();

  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  // Auto-focus input on mount
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!password) {
      setError('Password is required');
      return;
    }

    setLoading(true);
    try {
      // In a real implementation, this would call wallet.unlock(password)
      // For now, we simulate the unlock process
      await new Promise((resolve) => setTimeout(resolve, 300));
      unlock();

      // Redirect to the page the user originally tried to visit, or dashboard
      const from = (location.state as any)?.from?.pathname || '/dashboard';
      navigate(from, { replace: true });
    } catch (err) {
      setError('Incorrect password');
    } finally {
      setLoading(false);
    }
  };

  // If user has no accounts, they should go to welcome instead
  useEffect(() => {
    if (!accounts || accounts.length === 0) {
      navigate('/welcome', { replace: true });
    }
  }, [accounts, navigate]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100 flex flex-col relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-32 -right-32 w-96 h-96 bg-blue-100 rounded-full opacity-30" />
        <div className="absolute -bottom-32 -left-32 w-96 h-96 bg-blue-50 rounded-full opacity-40" />
      </div>

      {/* Content */}
      <div className="relative z-10 flex-1 flex flex-col items-center pt-20 px-6">
        {/* Logo */}
        <div className="w-24 h-24 bg-white rounded-2xl flex items-center justify-center shadow-lg mb-4">
          <span className="text-blue-600 font-bold text-3xl">R</span>
        </div>

        <h1 className="text-2xl font-semibold text-gray-900 mt-3 text-center">
          Welcome Back
        </h1>
        <p className="text-sm text-gray-500 mt-3 mx-8 text-center leading-5">
          Enter your password to unlock your wallet
        </p>

        {/* Form */}
        <form onSubmit={handleSubmit} className="w-full mt-8">
          <div>
            <input
              ref={inputRef}
              type="password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setError('');
              }}
              placeholder="Enter password"
              spellCheck={false}
              className={`w-full h-14 px-4 text-base rounded-xl outline-none transition-colors
                bg-white border
                ${
                  error
                    ? 'border-red-400 focus:border-red-500'
                    : 'border-gray-200 focus:border-blue-500'
                }
                placeholder-gray-400`}
            />
            {error && (
              <p className="text-red-500 text-sm mt-3 font-medium">{error}</p>
            )}
          </div>
        </form>
      </div>

      {/* Footer */}
      <footer className="relative z-10 px-6 pb-8 text-center">
        <button
          onClick={handleSubmit as any}
          disabled={loading || !password}
          className={`w-full h-14 text-lg font-semibold rounded-xl transition-all mb-5
            ${
              loading || !password
                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                : 'bg-blue-500 text-white hover:bg-blue-600 active:scale-[0.98]'
            }`}
        >
          {loading ? 'Unlocking...' : 'Unlock'}
        </button>

        <button
          type="button"
          className="text-gray-500 text-sm font-medium hover:underline"
          onClick={() => {
            // In a real implementation, navigate to forgot-password flow
            alert('Forgot password functionality will be available in a future update.');
          }}
        >
          Forgot Password?
        </button>
      </footer>
    </div>
  );
};

export default UnlockPage;
