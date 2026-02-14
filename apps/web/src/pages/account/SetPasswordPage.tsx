import React, { useState, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAccountStore } from '../../store/account';

const MINIMUM_PASSWORD_LENGTH = 8;

/**
 * SetPasswordPage — set wallet password after importing keys.
 *
 * Mirrors the extension's NewUserImport/SetPassword.tsx:
 *  - Password input + confirm
 *  - Creates the wallet password (boot)
 *  - Then finalizes the import and navigates to /new-user/success
 */
const SetPasswordPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const isCreated = searchParams.get('isCreated') === 'true';

  const { unlock } = useAccountStore();

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [agreed, setAgreed] = useState(true);
  const [errors, setErrors] = useState<{ password?: string; confirm?: string }>({});
  const [loading, setLoading] = useState(false);

  const validateForm = useCallback(() => {
    const newErrors: typeof errors = {};

    if (!password) {
      newErrors.password = 'Password is required';
    } else if (password.length < MINIMUM_PASSWORD_LENGTH) {
      newErrors.password = `Password must be at least ${MINIMUM_PASSWORD_LENGTH} characters`;
    }

    if (!confirmPassword) {
      newErrors.confirm = 'Please confirm your password';
    } else if (password !== confirmPassword) {
      newErrors.confirm = 'Passwords do not match';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }, [password, confirmPassword]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validateForm() || !agreed) return;

    setLoading(true);
    try {
      // In production:
      // 1. await wallet.boot(password)
      // 2. Import the key/seed phrase from session store
      // 3. Navigate to success
      await new Promise((resolve) => setTimeout(resolve, 500));

      // Simulate adding an account and unlocking
      const { addAccount } = useAccountStore.getState();
      addAccount({
        address: '0x' + Math.random().toString(16).slice(2, 42).padEnd(40, '0'),
        type: isCreated ? 'hd' : 'imported',
        brandName: 'Rabby',
      } as any);
      unlock();

      navigate('/new-user/success' + (isCreated ? '?isCreated=true' : ''));
    } catch (err) {
      setErrors({ password: 'Failed to set password. Please try again.' });
    } finally {
      setLoading(false);
    }
  };

  const isDisabled =
    !agreed ||
    !password ||
    password.length < MINIMUM_PASSWORD_LENGTH ||
    password !== confirmPassword;

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <header className="flex items-center px-4 pt-12 pb-4">
        <button
          onClick={() => navigate(-1)}
          className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="flex-1 text-xl font-semibold text-gray-900 text-center pr-10">
          Set Password
        </h1>
      </header>

      {/* Step indicator */}
      <div className="flex gap-2 px-6 mb-6">
        <div className="h-1 flex-1 rounded-full bg-blue-500" />
        <div className="h-1 flex-1 rounded-full bg-blue-500" />
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="flex-1 flex flex-col px-6 pb-8">
        <p className="text-sm text-gray-500 text-center mb-8">
          Create a password to encrypt and protect your wallet on this device
        </p>

        <div className="space-y-5">
          {/* Password */}
          <div>
            <input
              type="password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setErrors((prev) => ({ ...prev, password: undefined }));
              }}
              placeholder="Enter password (8+ characters)"
              autoFocus
              spellCheck={false}
              className={`w-full h-13 px-4 py-3 text-base border rounded-xl outline-none transition-colors
                ${
                  errors.password
                    ? 'border-red-400 focus:border-red-500'
                    : 'border-gray-200 focus:border-blue-500'
                }
                bg-white`}
            />
            {errors.password && (
              <p className="text-red-500 text-sm mt-2">{errors.password}</p>
            )}
          </div>

          {/* Confirm Password */}
          <div>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => {
                setConfirmPassword(e.target.value);
                setErrors((prev) => ({ ...prev, confirm: undefined }));
              }}
              placeholder="Confirm password"
              spellCheck={false}
              className={`w-full h-13 px-4 py-3 text-base border rounded-xl outline-none transition-colors
                ${
                  errors.confirm
                    ? 'border-red-400 focus:border-red-500'
                    : 'border-gray-200 focus:border-blue-500'
                }
                bg-white`}
            />
            {errors.confirm && (
              <p className="text-red-500 text-sm mt-2">{errors.confirm}</p>
            )}
          </div>
        </div>

        {/* Terms checkbox */}
        <div
          className="flex items-start gap-3 mt-6 cursor-pointer"
          onClick={() => setAgreed(!agreed)}
        >
          <div
            className={`w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 transition-colors
              ${agreed ? 'bg-blue-500' : 'bg-gray-300'}`}
          >
            {agreed && (
              <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
              </svg>
            )}
          </div>
          <span className="text-sm text-gray-600 leading-5">
            I have read and agree to the{' '}
            <a
              href="https://rabby.io/docs/terms-of-use"
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-500 hover:underline"
              onClick={(e) => e.stopPropagation()}
            >
              Terms of Use
            </a>{' '}
            and{' '}
            <a
              href="https://rabby.io/docs/privacy"
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-500 hover:underline"
              onClick={(e) => e.stopPropagation()}
            >
              Privacy Policy
            </a>
          </span>
        </div>

        {/* Submit */}
        <div className="mt-auto pt-6">
          <button
            type="submit"
            disabled={isDisabled || loading}
            className={`w-full h-14 text-lg font-semibold rounded-xl transition-all
              ${
                isDisabled || loading
                  ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                  : 'bg-blue-500 text-white hover:bg-blue-600 active:scale-[0.98]'
              }`}
          >
            {loading ? 'Creating...' : 'Confirm'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default SetPasswordPage;
