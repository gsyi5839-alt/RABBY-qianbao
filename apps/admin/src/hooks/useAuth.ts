import { useState, useCallback } from 'react';

const TOKEN_KEY = 'rabby_admin_token';

export function useAuth() {
  const [token, setTokenState] = useState<string | null>(
    () => localStorage.getItem(TOKEN_KEY)
  );

  const login = useCallback((t: string) => {
    localStorage.setItem(TOKEN_KEY, t);
    setTokenState(t);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    setTokenState(null);
  }, []);

  return { token, login, logout };
}
