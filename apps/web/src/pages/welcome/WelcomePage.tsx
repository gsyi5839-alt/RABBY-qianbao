import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * WelcomePage — the first screen new users see.
 *
 * Mirrors the extension's Welcome.tsx with a two-step onboarding splash:
 *  Step 1: Introduction to Rabby Wallet
 *  Step 2: Call-to-action buttons (Create / Import)
 *
 * Mobile-first full-screen design using Tailwind CSS.
 */
const WelcomePage: React.FC = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState<1 | 2>(1);

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-600 to-blue-800 flex flex-col">
      {/* Header logo area */}
      <div className="flex items-center justify-center pt-16 pb-8">
        <div className="w-24 h-24 bg-white rounded-2xl flex items-center justify-center shadow-lg">
          <span className="text-blue-600 font-bold text-3xl">R</span>
        </div>
      </div>

      {step === 1 ? (
        <section className="flex-1 flex flex-col px-6 pb-8">
          <h1 className="text-2xl font-bold text-white text-center mb-3">
            Welcome to Rabby Wallet
          </h1>
          <p className="text-sm text-white/80 text-center leading-6 mb-10">
            The game-changing wallet for Ethereum and all EVM chains.
            Multi-chain support made easy.
          </p>

          {/* Illustration placeholder */}
          <div className="mx-auto w-80 h-48 bg-white/10 rounded-xl flex items-center justify-center">
            <span className="text-white/60 text-sm">Multi-chain Overview</span>
          </div>

          <div className="mt-auto pt-10">
            <button
              onClick={() => setStep(2)}
              className="w-full h-14 bg-white text-blue-600 font-semibold text-lg rounded-xl
                         hover:bg-blue-50 active:scale-[0.98] transition-all"
            >
              Next
            </button>
          </div>
        </section>
      ) : (
        <section className="flex-1 flex flex-col px-6 pb-8">
          <h1 className="text-2xl font-bold text-white text-center mb-3">
            Pre-sign Security
          </h1>
          <p className="text-sm text-white/80 text-center leading-6 mb-10">
            Rabby checks every transaction before you sign.
            Stay safe with built-in risk detection.
          </p>

          {/* Illustration placeholder */}
          <div className="mx-auto w-80 h-48 bg-white/10 rounded-xl flex items-center justify-center">
            <span className="text-white/60 text-sm">Security Preview</span>
          </div>

          <div className="mt-auto pt-10 flex flex-col gap-4">
            <button
              onClick={() => navigate('/new-user/guide')}
              className="w-full h-14 bg-white text-blue-600 font-semibold text-lg rounded-xl
                         hover:bg-blue-50 active:scale-[0.98] transition-all"
            >
              Create New Wallet
            </button>
            <button
              onClick={() => navigate('/new-user/import-list')}
              className="w-full h-14 bg-transparent border-2 border-white text-white font-semibold text-lg rounded-xl
                         hover:bg-white/10 active:scale-[0.98] transition-all"
            >
              Import Existing Wallet
            </button>
          </div>
        </section>
      )}

      {/* Step indicator */}
      <div className="flex justify-center gap-2 pb-8">
        <div
          className={`w-2 h-2 rounded-full transition-colors ${
            step === 1 ? 'bg-white' : 'bg-white/40'
          }`}
        />
        <div
          className={`w-2 h-2 rounded-full transition-colors ${
            step === 2 ? 'bg-white' : 'bg-white/40'
          }`}
        />
      </div>
    </div>
  );
};

export default WelcomePage;
