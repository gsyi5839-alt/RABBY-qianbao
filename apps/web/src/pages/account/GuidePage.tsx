import React from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * GuidePage — new user onboarding hub.
 *
 * Mirrors the extension's NewUserImport/Guide.tsx:
 *  - Rabby logo
 *  - "Create New Address" button -> /new-user/create-seed-phrase
 *  - "Import Address" button -> /new-user/import-list
 */
const GuidePage: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white flex flex-col items-center px-6">
      {/* Logo */}
      <div className="mt-24 w-24 h-24 bg-white rounded-2xl flex items-center justify-center shadow-lg">
        <span className="text-blue-600 font-bold text-3xl">R</span>
      </div>

      {/* Title & Description */}
      <h1 className="mt-4 text-2xl font-semibold text-gray-900 text-center">
        Rabby Wallet
      </h1>
      <p className="mt-3 text-sm text-gray-500 text-center max-w-xs leading-5">
        The game-changing wallet for Ethereum and all EVM chains.
        Secure, intuitive, and feature-rich.
      </p>

      {/* Buttons */}
      <div className="w-full mt-20 space-y-4">
        <button
          onClick={() => navigate('/new-user/create-seed-phrase')}
          className="w-full h-14 bg-blue-500 text-white font-semibold text-lg rounded-xl
                     shadow-sm hover:bg-blue-600 active:scale-[0.98] transition-all"
        >
          Create New Address
        </button>

        <button
          onClick={() => navigate('/new-user/import-list')}
          className="w-full h-14 bg-transparent border-2 border-blue-500 text-blue-500 font-semibold text-lg rounded-xl
                     hover:bg-blue-50 active:scale-[0.98] transition-all"
        >
          Import Address
        </button>
      </div>

      {/* Back link */}
      <button
        onClick={() => navigate(-1)}
        className="mt-8 text-sm text-gray-400 hover:text-gray-600 transition-colors"
      >
        Go Back
      </button>
    </div>
  );
};

export default GuidePage;
