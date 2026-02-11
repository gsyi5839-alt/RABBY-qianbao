import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { lightTheme, darkTheme, type ThemeMode, type ThemeTokens } from './tokens';

interface ThemeContextValue {
  theme: ThemeMode;
  setTheme: (theme: ThemeMode) => void;
  toggleTheme: () => void;
  tokens: ThemeTokens;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function applyThemeToDOM(theme: ThemeMode, tokens: ThemeTokens) {
  const root = document.documentElement;
  if (theme === 'dark') {
    root.classList.add('dark');
    root.style.colorScheme = 'dark';
  } else {
    root.classList.remove('dark');
    root.style.colorScheme = 'light';
  }
  Object.entries(tokens).forEach(([key, value]) => {
    root.style.setProperty(`--${key}`, value);
  });
}

const STORAGE_KEY = 'rabby-theme';

export function ThemeProvider({ children, defaultTheme = 'light' }: { children: React.ReactNode; defaultTheme?: ThemeMode }) {
  const [theme, setThemeState] = useState<ThemeMode>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved === 'dark' || saved === 'light') return saved;
    } catch {}
    return defaultTheme;
  });

  const tokens = theme === 'dark' ? darkTheme : lightTheme;

  useEffect(() => {
    applyThemeToDOM(theme, tokens);
    try { localStorage.setItem(STORAGE_KEY, theme); } catch {}
  }, [theme, tokens]);

  const setTheme = useCallback((t: ThemeMode) => setThemeState(t), []);
  const toggleTheme = useCallback(() => setThemeState((prev) => (prev === 'dark' ? 'light' : 'dark')), []);

  return (
    <ThemeContext.Provider value={{ theme, setTheme, toggleTheme, tokens }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
