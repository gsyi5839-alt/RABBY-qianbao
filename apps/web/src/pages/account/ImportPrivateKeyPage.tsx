import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * ImportPrivateKeyPage — import wallet via private key.
 *
 * Mirrors the extension's NewUserImport/ImportPrivateKey.tsx:
 *  - Private key input field (password type)
 *  - Format validation (hex string, 64 chars or 0x-prefixed 66 chars)
 *  - On success, navigates to set-password
 */
const ImportPrivateKeyPage: React.FC = () => {
  const navigate = useNavigate();
  const [privateKey, setPrivateKey] = useState('');
  const [error, setError] = useState('');

  const validatePrivateKey = (key: string): boolean => {
    const trimmed = key.trim();
    // Accept 0x-prefixed or bare hex, must be 64 hex chars
    const hex = trimmed.startsWith('0x') ? trimmed.slice(2) : trimmed;
    return /^[0-9a-fA-F]{64}$/.test(hex);
  };

  const handleSubmit = () => {
    if (!privateKey.trim()) {
      setError('Please enter your private key');
      return;
    }

    if (!validatePrivateKey(privateKey)) {
      setError('Not a valid private key. Please check the format.');
      return;
    }

    // In production, this would store the key in session state
    navigate('/new-user/set-password');
  };

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
          Import Private Key
        </h1>
      </header>

      {/* Step indicator */}
      <div className="flex gap-2 px-6 mb-4">
        <div className="h-1 flex-1 rounded-full bg-blue-500" />
        <div className="h-1 flex-1 rounded-full bg-gray-200" />
      </div>

      <div className="flex-1 flex flex-col px-6 pb-8">
        <div className="mt-4">
          <input
            type="password"
            value={privateKey}
            onChange={(e) => {
              setPrivateKey(e.target.value);
              setError('');
            }}
            placeholder="Enter your private key"
            autoFocus
            spellCheck={false}
            autoComplete="off"
            className={`w-full h-13 px-4 py-3 text-base border rounded-xl outline-none transition-colors
              ${
                error
                  ? 'border-red-400 focus:border-red-500'
                  : 'border-gray-200 focus:border-blue-500'
              }
              bg-white`}
          />
          {error && (
            <p className="text-red-500 text-sm mt-3">{error}</p>
          )}
        </div>

        {/* FAQ section */}
        <div className="mt-8 space-y-5">
          <div>
            <h3 className="text-sm font-semibold text-gray-700 mb-1">
              What is a private key?
            </h3>
            <p className="text-sm text-gray-500 leading-5">
              A private key is a 256-bit hexadecimal string that grants full access to your wallet.
              It is the most direct way to prove ownership of your assets.
            </p>
          </div>
          <div>
            <h3 className="text-sm font-semibold text-gray-700 mb-1">
              Is it safe to import in Rabby?
            </h3>
            <p className="text-sm text-gray-500 leading-5">
              Rabby stores your private key locally with AES encryption, protected by your password.
              It never leaves your device.
            </p>
          </div>
        </div>

        {/* Submit */}
        <div className="mt-auto pt-6">
          <button
            onClick={handleSubmit}
            disabled={!privateKey.trim()}
            className={`w-full h-14 font-semibold text-lg rounded-xl transition-all
              ${
                privateKey.trim()
                  ? 'bg-blue-500 text-white hover:bg-blue-600 active:scale-[0.98]'
                  : 'bg-gray-300 text-gray-500 cursor-not-allowed'
              }`}
          >
            Confirm
          </button>
        </div>
      </div>
    </div>
  );
};

export default ImportPrivateKeyPage;
