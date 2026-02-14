import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

export type Language = 'en' | 'zh';

interface LanguageContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

// Detect language based on browser settings and IP region hint
async function detectLanguage(): Promise<Language> {
  // First check browser language
  const browserLang = navigator.language.toLowerCase();

  // Chinese language check
  if (browserLang.startsWith('zh')) {
    return 'zh';
  }

  // For other languages, try IP-based detection
  try {
    const response = await fetch('https://ipapi.co/json/');
    if (response.ok) {
      const data = await response.json();
      // China, Hong Kong, Taiwan, Macau use Chinese
      const chineseRegions = ['CN', 'HK', 'TW', 'MO'];
      if (data.country_code && chineseRegions.includes(data.country_code)) {
        return 'zh';
      }
    }
  } catch (error) {
    console.warn('IP detection failed, using browser language');
  }

  return 'en';
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>('en');
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    // Check localStorage first
    const savedLang = localStorage.getItem('rabby-language') as Language | null;
    if (savedLang && (savedLang === 'en' || savedLang === 'zh')) {
      setLanguageState(savedLang);
      setIsInitialized(true);
      return;
    }

    // Auto-detect language
    detectLanguage().then((detectedLang) => {
      setLanguageState(detectedLang);
      localStorage.setItem('rabby-language', detectedLang);
      setIsInitialized(true);
    });
  }, []);

  const setLanguage = (lang: Language) => {
    setLanguageState(lang);
    localStorage.setItem('rabby-language', lang);
  };

  // Don't render until language is determined (to avoid flash)
  if (!isInitialized) {
    return null;
  }

  return (
    <LanguageContext.Provider value={{ language, setLanguage }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useLanguage must be used within LanguageProvider');
  }
  return context;
}
