import React, { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAccountStore } from '../../store/account';

const MINIMUM_PASSWORD_LENGTH = 8;

/**
 * CreatePasswordPage — first-time password setup.
 *
 * Mirrors the extension's CreatePassword.tsx:
 *  - Password input (min 8 characters)
 *  - Confirm password
 *  - Terms of Use agreement checkbox
 *  - Creates a boot password and navigates forward
 */
const CreatePasswordPage: React.FC = () => {
  const navigate = useNavigate();
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
      // In a real implementation, this would call wallet.boot(password)
      // For now, we simulate the boot process
      await new Promise((resolve) => setTimeout(resolve, 500));
      navigate('/no-address');
    } catch (err) {
      setErrors({ password: 'Failed to create password. Please try again.' });
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
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <header className="bg-gradient-to-b from-blue-600 to-blue-700 px-6 pt-12 pb-10 flex flex-col items-center">
        <div className="w-20 h-20 bg-white rounded-2xl flex items-center justify-center shadow-lg mb-4">
          <span className="text-blue-600 font-bold text-2xl">R</span>
        </div>
        <h1 className="text-2xl font-bold text-white text-center">
          Create Password
        </h1>
        <p className="text-sm text-white/80 text-center mt-2">
          It will be used to unlock your wallet and encrypt local data
        </p>
      </header>

      {/* Form */}
      <form onSubmit={handleSubmit} className="flex-1 flex flex-col px-6 pt-8">
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
                    ? 'border-red-500 focus:border-red-500'
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
                    ? 'border-red-500 focus:border-red-500'
                    : 'border-gray-200 focus:border-blue-500'
                }
                bg-white`}
            />
            {errors.confirm && (
              <p className="text-red-500 text-sm mt-2">{errors.confirm}</p>
            )}
          </div>
        </div>

        {/* Password strength hint */}
        {password && (
          <div className="mt-4 flex items-center gap-2">
            <div className="flex gap-1 flex-1">
              <div
                className={`h-1 flex-1 rounded ${
                  password.length >= 8 ? 'bg-green-400' : 'bg-gray-200'
                }`}
              />
              <div
                className={`h-1 flex-1 rounded ${
                  password.length >= 12 ? 'bg-green-400' : 'bg-gray-200'
                }`}
              />
              <div
                className={`h-1 flex-1 rounded ${
                  password.length >= 16 && /[!@#$%^&*]/.test(password)
                    ? 'bg-green-400'
                    : 'bg-gray-200'
                }`}
              />
            </div>
            <span className="text-xs text-gray-500">
              {password.length < 8
                ? 'Weak'
                : password.length < 12
                ? 'Medium'
                : 'Strong'}
            </span>
          </div>
        )}

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
        <div className="mt-auto pb-8 pt-6">
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
            {loading ? 'Creating...' : 'Next'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default CreatePasswordPage;
