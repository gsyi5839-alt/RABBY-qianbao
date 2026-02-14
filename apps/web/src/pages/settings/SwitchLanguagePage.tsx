import React from 'react';
import clsx from 'clsx';
import { PageHeader } from '../../components/layout';
import { usePreference } from '../../hooks';
import type { Language } from '../../store/preference';

// ---------------------------------------------------------------------------
// Language options
// ---------------------------------------------------------------------------
const LANGUAGES: { code: Language; name: string; nativeName: string }[] = [
  { code: 'en', name: 'English', nativeName: 'English' },
  { code: 'zh', name: 'Chinese', nativeName: '\u4e2d\u6587' },
];

// ---------------------------------------------------------------------------
// Switch Language Page
// ---------------------------------------------------------------------------
const SwitchLanguagePage: React.FC = () => {
  const { language, setLanguage } = usePreference();

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Language" />

      <div className="flex-1 px-4 pb-4">
        <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden divide-y divide-[var(--r-neutral-line)]">
          {LANGUAGES.map((lang) => {
            const isActive = language === lang.code;
            return (
              <button
                key={lang.code}
                className="w-full flex items-center justify-between px-4 py-4 min-h-[52px]"
                onClick={() => setLanguage(lang.code)}
              >
                <div className="flex flex-col items-start">
                  <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                    {lang.name}
                  </span>
                  <span className="text-xs text-[var(--r-neutral-foot)]">
                    {lang.nativeName}
                  </span>
                </div>
                {isActive && <CheckIcon />}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default SwitchLanguagePage;

// ---------------------------------------------------------------------------
// Check Icon
// ---------------------------------------------------------------------------
const CheckIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path
      d="M5 10l4 4 6-7"
      stroke="var(--rabby-brand)"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
