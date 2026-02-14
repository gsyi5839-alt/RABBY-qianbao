import React from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * NoAddressPage — shown when wallet is booted but has no addresses.
 *
 * Mirrors the extension's NoAddress/index.tsx:
 *  - Prompts user to add their first address
 *  - Options to create or import a wallet
 */
const NoAddressPage: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <header className="bg-blue-600 px-6 pt-12 pb-8">
        <h1 className="text-xl font-bold text-white text-center">
          Add Your First Address
        </h1>
      </header>

      {/* Content */}
      <div className="flex-1 flex flex-col items-center px-6 pt-10">
        {/* Illustration */}
        <div className="w-32 h-32 bg-blue-50 rounded-full flex items-center justify-center mb-8">
          <svg
            className="w-16 h-16 text-blue-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M12 4v16m8-8H4"
            />
          </svg>
        </div>

        <h2 className="text-lg font-semibold text-gray-900 mb-3">
          No Address Found
        </h2>
        <p className="text-sm text-gray-500 text-center leading-6 mb-10 max-w-xs">
          You need at least one address to start using Rabby Wallet.
          Create a new wallet or import an existing one.
        </p>

        {/* Options */}
        <div className="w-full space-y-4">
          <button
            onClick={() => navigate('/new-user/guide')}
            className="w-full flex items-center gap-4 p-4 bg-blue-50 rounded-xl
                       hover:bg-blue-100 transition-colors text-left"
          >
            <div className="w-12 h-12 bg-blue-500 rounded-xl flex items-center justify-center flex-shrink-0">
              <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <div>
              <div className="text-base font-semibold text-gray-900">Create New Address</div>
              <div className="text-sm text-gray-500">Generate a new seed phrase</div>
            </div>
          </button>

          <button
            onClick={() => navigate('/new-user/import-list')}
            className="w-full flex items-center gap-4 p-4 bg-gray-50 rounded-xl
                       hover:bg-gray-100 transition-colors text-left"
          >
            <div className="w-12 h-12 bg-gray-500 rounded-xl flex items-center justify-center flex-shrink-0">
              <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                />
              </svg>
            </div>
            <div>
              <div className="text-base font-semibold text-gray-900">Import Address</div>
              <div className="text-sm text-gray-500">Seed phrase, private key, or hardware wallet</div>
            </div>
          </button>
        </div>
      </div>
    </div>
  );
};

export default NoAddressPage;
