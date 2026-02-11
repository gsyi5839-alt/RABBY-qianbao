import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';

const STORAGE_KEY = 'rabby_web_settings';

type ThemeMode = 'light' | 'dark' | 'system';

interface SettingsState {
  theme: ThemeMode;
  lang: string;
  autoLockMinutes: number;
}

const defaultSettings: SettingsState = {
  theme: 'light',
  lang: 'zh',
  autoLockMinutes: 5,
};

function getEffectiveTheme(theme: ThemeMode): 'light' | 'dark' {
  if (theme === 'system') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  return theme;
}

function applyTheme(theme: 'light' | 'dark') {
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.classList.toggle('dark', theme === 'dark');
}

interface SettingsContextValue extends SettingsState {
  effectiveTheme: 'light' | 'dark';
  setTheme: (theme: ThemeMode) => void;
  setLang: (lang: string) => void;
  setAutoLockMinutes: (minutes: number) => void;
}

const SettingsContext = createContext<SettingsContextValue | null>(null);

export function SettingsProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<SettingsState>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved);
        return { ...defaultSettings, ...parsed };
      }
    } catch {}
    return defaultSettings;
  });

  const [effectiveTheme, setEffectiveTheme] = useState<'light' | 'dark'>(
    () => getEffectiveTheme(state.theme)
  );

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));

    const effective = getEffectiveTheme(state.theme);
    setEffectiveTheme(effective);
    applyTheme(effective);

    if (state.theme === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = (e: MediaQueryListEvent) => {
        const newTheme = e.matches ? 'dark' : 'light';
        setEffectiveTheme(newTheme);
        applyTheme(newTheme);
      };
      mq.addEventListener('change', handler);
      return () => mq.removeEventListener('change', handler);
    }
  }, [state]);

  const setTheme = useCallback((theme: ThemeMode) => {
    setState((s) => ({ ...s, theme }));
  }, []);

  const setLang = useCallback((lang: string) => {
    setState((s) => ({ ...s, lang }));
  }, []);

  const setAutoLockMinutes = useCallback((autoLockMinutes: number) => {
    setState((s) => ({ ...s, autoLockMinutes }));
  }, []);

  return (
    <SettingsContext.Provider
      value={{
        ...state,
        effectiveTheme,
        setTheme,
        setLang,
        setAutoLockMinutes,
      }}
    >
      {children}
    </SettingsContext.Provider>
  );
}

export function useSettings() {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error('useSettings must be used within SettingsProvider');
  return ctx;
}
