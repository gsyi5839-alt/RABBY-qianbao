import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * ImportListPage — list of import methods.
 *
 * Mirrors the extension's NewUserImport/ImportList.tsx:
 *  - Seed Phrase
 *  - Private Key
 *  - Hardware Wallet (placeholder)
 *  - Watch Mode (placeholder)
 *  - "More" toggle for additional options
 */

interface ImportOption {
  id: string;
  name: string;
  description: string;
  icon: string;
  path: string;
  available: boolean;
}

const importOptions: ImportOption[] = [
  {
    id: 'seed-phrase',
    name: 'Seed Phrase',
    description: 'Import with 12 or 24 word recovery phrase',
    icon: 'M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z',
    path: '/new-user/import/seed-phrase',
    available: true,
  },
  {
    id: 'private-key',
    name: 'Private Key',
    description: 'Import with a private key string',
    icon: 'M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z',
    path: '/new-user/import/private-key',
    available: true,
  },
  {
    id: 'hardware',
    name: 'Hardware Wallet',
    description: 'Ledger, Trezor, OneKey, Keystone...',
    icon: 'M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z',
    path: '/new-user/set-password',
    available: false,
  },
  {
    id: 'watch',
    name: 'Watch Mode',
    description: 'Watch any address without private key',
    icon: 'M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z',
    path: '/new-user/set-password',
    available: false,
  },
  {
    id: 'safe',
    name: 'Safe (Gnosis)',
    description: 'Import a Gnosis Safe multi-sig',
    icon: 'M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z',
    path: '/new-user/set-password',
    available: false,
  },
];

const ImportListPage: React.FC = () => {
  const navigate = useNavigate();
  const [showMore, setShowMore] = useState(false);

  const visibleOptions = showMore ? importOptions : importOptions.slice(0, 3);

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <header className="flex items-center px-4 pt-12 pb-6">
        <button
          onClick={() => navigate(-1)}
          className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="flex-1 text-xl font-semibold text-gray-900 text-center pr-10">
          Import Address
        </h1>
      </header>

      {/* Import options */}
      <div className="flex-1 px-6 pb-8">
        <div className="space-y-4 mt-4">
          {visibleOptions.map((option) => (
            <button
              key={option.id}
              onClick={() => {
                if (option.available) {
                  navigate(option.path);
                }
              }}
              disabled={!option.available}
              className={`w-full flex items-center gap-4 p-4 rounded-xl transition-colors text-left
                ${
                  option.available
                    ? 'bg-gray-50 hover:bg-gray-100'
                    : 'bg-gray-50 opacity-50 cursor-not-allowed'
                }`}
            >
              <div
                className={`w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0
                  ${option.available ? 'bg-blue-100' : 'bg-gray-200'}`}
              >
                <svg
                  className={`w-6 h-6 ${option.available ? 'text-blue-500' : 'text-gray-400'}`}
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={option.icon} />
                </svg>
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-base font-semibold text-gray-900">
                    {option.name}
                  </span>
                  {!option.available && (
                    <span className="text-xs bg-gray-200 text-gray-500 px-2 py-0.5 rounded-full">
                      Coming Soon
                    </span>
                  )}
                </div>
                <p className="text-sm text-gray-500 mt-0.5">{option.description}</p>
              </div>
              {option.available && (
                <svg className="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              )}
            </button>
          ))}
        </div>

        {/* Show more toggle */}
        {!showMore && importOptions.length > 3 && (
          <button
            onClick={() => setShowMore(true)}
            className="w-full flex items-center justify-center gap-1.5 mt-6 text-sm text-gray-400 hover:text-gray-600 transition-colors"
          >
            <span>More</span>
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>
        )}
      </div>
    </div>
  );
};

export default ImportListPage;
