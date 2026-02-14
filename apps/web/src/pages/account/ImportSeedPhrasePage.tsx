import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * ImportSeedPhrasePage — import wallet via seed phrase (mnemonic).
 *
 * Mirrors the extension's NewUserImport/ImportSeedPhrase.tsx:
 *  - 12 or 24 word input grid
 *  - Paste support (auto-splits by space/newline)
 *  - Validates mnemonic format
 *  - On success, navigates to set-password
 */
const ImportSeedPhrasePage: React.FC = () => {
  const navigate = useNavigate();
  const [wordCount, setWordCount] = useState<12 | 24>(12);
  const [words, setWords] = useState<string[]>(Array(12).fill(''));
  const [error, setError] = useState('');

  const handleWordChange = (index: number, value: string) => {
    // If pasting multiple words
    const trimmed = value.trim();
    if (trimmed.includes(' ') || trimmed.includes('\n')) {
      const pastedWords = trimmed.split(/[\s\n]+/).filter(Boolean);
      const newWords = [...words];
      for (let i = 0; i < pastedWords.length && index + i < wordCount; i++) {
        newWords[index + i] = pastedWords[i].toLowerCase();
      }
      setWords(newWords);
      setError('');
      return;
    }

    const newWords = [...words];
    newWords[index] = value.toLowerCase();
    setWords(newWords);
    setError('');
  };

  const handleWordCountChange = (count: 12 | 24) => {
    setWordCount(count);
    if (count > words.length) {
      setWords([...words, ...Array(count - words.length).fill('')]);
    } else {
      setWords(words.slice(0, count));
    }
    setError('');
  };

  const handleSubmit = () => {
    const filledWords = words.filter((w) => w.trim());
    if (filledWords.length !== wordCount) {
      setError(`Please fill in all ${wordCount} words`);
      return;
    }

    // Basic validation: check that all words are alphabetic and reasonable length
    const invalid = words.find((w) => !/^[a-z]+$/.test(w.trim()));
    if (invalid) {
      setError('The seed phrase contains invalid words. Please check and try again.');
      return;
    }

    // In production, validate with bip39.validateMnemonic
    navigate('/new-user/set-password');
  };

  const isComplete = words.filter((w) => w.trim()).length === wordCount;

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
          Import Seed Phrase
        </h1>
      </header>

      {/* Step indicator */}
      <div className="flex gap-2 px-6 mb-4">
        <div className="h-1 flex-1 rounded-full bg-blue-500" />
        <div className="h-1 flex-1 rounded-full bg-gray-200" />
      </div>

      <div className="flex-1 flex flex-col px-6 pb-8">
        {/* Word count toggle */}
        <div className="flex gap-2 mb-6">
          {([12, 24] as const).map((count) => (
            <button
              key={count}
              onClick={() => handleWordCountChange(count)}
              className={`flex-1 h-10 rounded-lg text-sm font-medium transition-colors
                ${
                  wordCount === count
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
            >
              {count} Words
            </button>
          ))}
        </div>

        {/* Word grid */}
        <div className={`grid gap-2 ${wordCount === 24 ? 'grid-cols-4' : 'grid-cols-3'}`}>
          {words.map((word, index) => (
            <div
              key={index}
              className="flex items-center gap-1 border border-gray-200 rounded-lg px-2 py-2.5
                         focus-within:border-blue-400 transition-colors"
            >
              <span className="text-xs text-gray-400 w-5 flex-shrink-0">{index + 1}.</span>
              <input
                type="text"
                value={word}
                onChange={(e) => handleWordChange(index, e.target.value)}
                className="flex-1 text-sm text-gray-900 outline-none bg-transparent w-full min-w-0"
                spellCheck={false}
                autoComplete="off"
                autoFocus={index === 0}
              />
            </div>
          ))}
        </div>

        {error && (
          <p className="text-red-500 text-sm mt-4 text-center">{error}</p>
        )}

        {/* Submit */}
        <div className="mt-auto pt-6">
          <button
            onClick={handleSubmit}
            disabled={!isComplete}
            className={`w-full h-14 font-semibold text-lg rounded-xl transition-all
              ${
                isComplete
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

export default ImportSeedPhrasePage;
