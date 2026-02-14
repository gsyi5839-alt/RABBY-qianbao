import { useCallback, useEffect, useLayoutEffect, useState } from 'react';
import { usePreferenceStore } from '../store/preference';
import type { ThemeMode, Language } from '../store/preference';

/**
 * Preference settings hook.
 *
 * Provides read/write access to all user preferences
 * including theme, language, and security settings.
 * Changes are automatically persisted through the Zustand persist middleware.
 *
 * Modeled after the extension's usePreference / useThemeModeOnMain hooks.
 */
export function usePreference() {
  const theme = usePreferenceStore((s) => s.theme);
  const language = usePreferenceStore((s) => s.language);
  const autoLockTime = usePreferenceStore((s) => s.autoLockTime);
  const isShowTestnet = usePreferenceStore((s) => s.isShowTestnet);
  const hiddenBalance = usePreferenceStore((s) => s.hiddenBalance);
  const isEnabledWhitelist = usePreferenceStore((s) => s.isEnabledWhitelist);
  const isEnabledDappAccount = usePreferenceStore(
    (s) => s.isEnabledDappAccount
  );
  const pinnedChain = usePreferenceStore((s) => s.pinnedChain);
  const reserveGasOnSendToken = usePreferenceStore(
    (s) => s.reserveGasOnSendToken
  );

  const setTheme = usePreferenceStore((s) => s.setTheme);
  const setLanguage = usePreferenceStore((s) => s.setLanguage);
  const setAutoLockTime = usePreferenceStore((s) => s.setAutoLockTime);
  const setShowTestnet = usePreferenceStore((s) => s.setShowTestnet);
  const setHiddenBalance = usePreferenceStore((s) => s.setHiddenBalance);
  const toggleWhitelist = usePreferenceStore((s) => s.toggleWhitelist);
  const toggleDappAccount = usePreferenceStore((s) => s.toggleDappAccount);
  const setPinnedChain = usePreferenceStore((s) => s.setPinnedChain);
  const setReserveGasOnSendToken = usePreferenceStore(
    (s) => s.setReserveGasOnSendToken
  );

  return {
    // State
    theme,
    language,
    autoLockTime,
    isShowTestnet,
    hiddenBalance,
    isEnabledWhitelist,
    isEnabledDappAccount,
    pinnedChain,
    reserveGasOnSendToken,

    // Actions
    setTheme,
    setLanguage,
    setAutoLockTime,
    setShowTestnet,
    setHiddenBalance,
    toggleWhitelist,
    toggleDappAccount,
    setPinnedChain,
    setReserveGasOnSendToken,
  };
}

/**
 * Detects system dark mode preference.
 */
function useIsDarkMode(): boolean {
  const [isDarkMode, setIsDarkMode] = useState(() => {
    try {
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    } catch {
      return false;
    }
  });

  useEffect(() => {
    const mqList = window.matchMedia('(prefers-color-scheme: dark)');

    const listener = (event: MediaQueryListEvent) => {
      setIsDarkMode(event.matches);
    };

    mqList.addEventListener('change', listener);
    return () => {
      mqList.removeEventListener('change', listener);
    };
  }, []);

  return isDarkMode;
}

/**
 * Resolves whether the app should be in dark mode
 * based on the user's theme preference and system setting.
 */
function isFinalDarkMode(themeMode: ThemeMode, isDarkOnSystem: boolean): boolean {
  if (themeMode === 'dark') return true;
  if (themeMode === 'system' && isDarkOnSystem) return true;
  return false;
}

/**
 * Theme mode hook that applies the dark/light class to the document root.
 * Should be used once at the app root level.
 *
 * Modeled after the extension's useThemeModeOnMain.
 */
export function useThemeModeOnMain() {
  const theme = usePreferenceStore((s) => s.theme);
  const isDarkOnSystem = useIsDarkMode();

  useLayoutEffect(() => {
    const isDark = isFinalDarkMode(theme, isDarkOnSystem);
    const root = document.documentElement;

    root.classList.add('no-transitions');
    if (isDark) {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }

    requestAnimationFrame(() => {
      root.classList.remove('no-transitions');
    });
  }, [theme, isDarkOnSystem]);
}

/**
 * Simple hook that returns whether the current theme is dark.
 */
export function useThemeMode(): { isDarkTheme: boolean } {
  const theme = usePreferenceStore((s) => s.theme);
  const isDarkOnSystem = useIsDarkMode();

  return {
    isDarkTheme: isFinalDarkMode(theme, isDarkOnSystem),
  };
}
