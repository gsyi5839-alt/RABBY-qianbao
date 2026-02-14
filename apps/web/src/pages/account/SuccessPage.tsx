import React from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

/**
 * SuccessPage — shown after successful wallet creation or import.
 *
 * Mirrors the extension's NewUserImport/Success.tsx:
 *  - Success checkmark icon
 *  - Congratulations text
 *  - "Start Using" button -> /dashboard
 */
const SuccessPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const isCreated = searchParams.get('isCreated') === 'true';

  return (
    <div className="min-h-screen bg-white flex flex-col items-center px-6">
      {/* Success icon */}
      <div className="mt-32 w-20 h-20 bg-green-100 rounded-full flex items-center justify-center">
        <svg className="w-10 h-10 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
        </svg>
      </div>

      {/* Title */}
      <h1 className="mt-6 text-2xl font-semibold text-gray-900 text-center">
        {isCreated ? 'Wallet Created Successfully!' : 'Wallet Imported Successfully!'}
      </h1>

      {/* Description */}
      <p className="mt-3 text-sm text-gray-500 text-center leading-6 max-w-xs">
        {isCreated
          ? 'Your new wallet has been created. You can now start exploring DeFi with Rabby.'
          : 'Your wallet has been imported. All your assets are now accessible in Rabby.'}
      </p>

      {/* Account preview placeholder */}
      <div className="w-full mt-8 p-4 bg-gray-50 rounded-xl border border-gray-100">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
            <span className="text-blue-500 font-bold text-sm">A1</span>
          </div>
          <div>
            <div className="text-sm font-medium text-gray-900">Account 1</div>
            <div className="text-xs text-gray-400 font-mono">0x1234...5678</div>
          </div>
        </div>
      </div>

      {/* Start button */}
      <div className="w-full mt-auto pb-8 pt-10">
        <button
          onClick={() => navigate('/dashboard', { replace: true })}
          className="w-full h-14 bg-blue-500 text-white font-semibold text-lg rounded-xl
                     hover:bg-blue-600 active:scale-[0.98] transition-all"
        >
          Start Using Rabby
        </button>
      </div>
    </div>
  );
};

export default SuccessPage;
