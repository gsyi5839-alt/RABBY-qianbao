import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * CreateSeedPhrasePage — guides the user through creating a new seed phrase.
 *
 * Mirrors the extension's NewUserImport/CreateSeedPhrase.tsx:
 *  Step 1: Show tips about seed phrase safety
 *  Step 2: Display the generated 12-word seed phrase
 *  Step 3: Verify by filling in selected words
 */

// Generate a fake 12-word seed phrase for demonstration.
// In production, this would use a proper BIP39 library (e.g. @scure/bip39).
function generateDemoMnemonic(): string[] {
  const words = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent',
    'absorb', 'abstract', 'absurd', 'abuse', 'access', 'accident',
    'account', 'accuse', 'achieve', 'acid', 'acquire', 'across',
    'action', 'actor', 'actress', 'actual', 'adapt', 'add',
  ];
  const result: string[] = [];
  for (let i = 0; i < 12; i++) {
    result.push(words[Math.floor(Math.random() * words.length)]);
  }
  return result;
}

const CreateSeedPhrasePage: React.FC = () => {
  const navigate = useNavigate();
  const [phase, setPhase] = useState<'tips' | 'show' | 'verify'>('tips');
  const [backedUp, setBackedUp] = useState(false);

  // Generate mnemonic once
  const mnemonic = useMemo(() => generateDemoMnemonic(), []);

  // Verification: pick 3 random indices for the user to fill in
  const verifyIndices = useMemo(() => {
    const indices: number[] = [];
    while (indices.length < 3) {
      const idx = Math.floor(Math.random() * 12);
      if (!indices.includes(idx)) indices.push(idx);
    }
    return indices.sort((a, b) => a - b);
  }, []);

  const [verifyInputs, setVerifyInputs] = useState<Record<number, string>>({});
  const [verifyError, setVerifyError] = useState('');

  const handleVerify = () => {
    const allCorrect = verifyIndices.every(
      (idx) => verifyInputs[idx]?.trim().toLowerCase() === mnemonic[idx]
    );
    if (allCorrect) {
      // Store the mnemonic in session and proceed to set-password
      navigate('/new-user/set-password?isCreated=true');
    } else {
      setVerifyError('Some words are incorrect. Please check and try again.');
    }
  };

  const tips = [
    'Your seed phrase is the ONLY way to recover your wallet. Write it down and store it in a safe place.',
    'Never share your seed phrase with anyone. Rabby will never ask for it.',
    'If you lose your seed phrase, your funds will be permanently lost.',
  ];

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <header className="flex items-center px-4 pt-12 pb-4">
        <button
          onClick={() => {
            if (phase === 'verify') setPhase('show');
            else if (phase === 'show') setPhase('tips');
            else navigate(-1);
          }}
          className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100"
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="flex-1 text-xl font-semibold text-gray-900 text-center pr-10">
          Create New Address
        </h1>
      </header>

      {/* Step indicator */}
      <div className="flex gap-2 px-6 mb-6">
        {['tips', 'show', 'verify'].map((step, idx) => (
          <div
            key={step}
            className={`h-1 flex-1 rounded-full transition-colors ${
              idx <= ['tips', 'show', 'verify'].indexOf(phase)
                ? 'bg-blue-500'
                : 'bg-gray-200'
            }`}
          />
        ))}
      </div>

      {/* Tips Phase */}
      {phase === 'tips' && (
        <div className="flex-1 flex flex-col px-6 pb-8">
          {/* Info icon */}
          <div className="w-14 h-14 bg-blue-50 rounded-full flex items-center justify-center mx-auto mt-4">
            <svg className="w-7 h-7 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>

          <p className="text-base text-blue-500 text-center mt-4 mb-6 font-medium">
            Before you start, please read the following tips carefully
          </p>

          <div className="space-y-4">
            {tips.map((tip, index) => (
              <div key={index} className="flex gap-3 px-3">
                <div className="w-2 h-2 bg-blue-500 rounded-full mt-2 flex-shrink-0" />
                <p className="text-sm text-gray-700 leading-5">{tip}</p>
              </div>
            ))}
          </div>

          <div className="mt-auto pt-8">
            <button
              onClick={() => setPhase('show')}
              className="w-full h-14 bg-blue-500 text-white font-semibold text-lg rounded-xl
                         hover:bg-blue-600 active:scale-[0.98] transition-all"
            >
              Show Seed Phrase
            </button>
          </div>
        </div>
      )}

      {/* Show Seed Phrase Phase */}
      {phase === 'show' && (
        <div className="flex-1 flex flex-col px-6 pb-8">
          <p className="text-sm text-gray-500 text-center mb-6">
            Write down these 12 words in order and keep them safe
          </p>

          <div className="grid grid-cols-3 gap-3">
            {mnemonic.map((word, index) => (
              <div
                key={index}
                className="flex items-center gap-2 px-3 py-3 bg-gray-50 rounded-lg border border-gray-100"
              >
                <span className="text-xs text-gray-400 w-5">{index + 1}.</span>
                <span className="text-sm font-medium text-gray-900">{word}</span>
              </div>
            ))}
          </div>

          {/* Confirmation checkbox */}
          <div
            className="flex items-center gap-3 mt-8 cursor-pointer"
            onClick={() => setBackedUp(!backedUp)}
          >
            <div
              className={`w-5 h-5 rounded flex items-center justify-center flex-shrink-0 border-2 transition-colors
                ${backedUp ? 'bg-blue-500 border-blue-500' : 'bg-white border-gray-300'}`}
            >
              {backedUp && (
                <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                </svg>
              )}
            </div>
            <span className="text-sm text-gray-700">
              I have backed up my seed phrase in a safe place
            </span>
          </div>

          <div className="mt-auto pt-6">
            <button
              onClick={() => setPhase('verify')}
              disabled={!backedUp}
              className={`w-full h-14 font-semibold text-lg rounded-xl transition-all
                ${
                  backedUp
                    ? 'bg-blue-500 text-white hover:bg-blue-600 active:scale-[0.98]'
                    : 'bg-gray-300 text-gray-500 cursor-not-allowed'
                }`}
            >
              Next - Verify
            </button>
          </div>
        </div>
      )}

      {/* Verify Phase */}
      {phase === 'verify' && (
        <div className="flex-1 flex flex-col px-6 pb-8">
          <p className="text-sm text-gray-500 text-center mb-6">
            Fill in the missing words to verify your backup
          </p>

          <div className="grid grid-cols-3 gap-3">
            {mnemonic.map((word, index) => {
              const isVerify = verifyIndices.includes(index);
              return (
                <div
                  key={index}
                  className={`flex items-center gap-2 px-3 py-3 rounded-lg border
                    ${isVerify ? 'border-blue-300 bg-blue-50' : 'border-gray-100 bg-gray-50'}`}
                >
                  <span className="text-xs text-gray-400 w-5">{index + 1}.</span>
                  {isVerify ? (
                    <input
                      type="text"
                      value={verifyInputs[index] || ''}
                      onChange={(e) => {
                        setVerifyInputs({ ...verifyInputs, [index]: e.target.value });
                        setVerifyError('');
                      }}
                      placeholder="?"
                      className="flex-1 bg-transparent text-sm font-medium text-gray-900 outline-none placeholder-blue-300 w-full"
                      autoFocus={index === verifyIndices[0]}
                    />
                  ) : (
                    <span className="text-sm font-medium text-gray-900">{word}</span>
                  )}
                </div>
              );
            })}
          </div>

          {verifyError && (
            <p className="text-red-500 text-sm mt-4 text-center">{verifyError}</p>
          )}

          <div className="mt-auto pt-6">
            <button
              onClick={handleVerify}
              className="w-full h-14 bg-blue-500 text-white font-semibold text-lg rounded-xl
                         hover:bg-blue-600 active:scale-[0.98] transition-all"
            >
              Confirm
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default CreateSeedPhrasePage;
