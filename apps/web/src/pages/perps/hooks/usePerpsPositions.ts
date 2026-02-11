import { useState, useEffect } from 'react';

export interface PerpsPosition {
  id: string;
  token: string;
  side: 'Long' | 'Short';
  entryPrice: number;
  markPrice: number;
  size: number;
  pnl: number;
}

export function usePerpsPositions() {
  const [positions, setPositions] = useState<PerpsPosition[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Returns empty positions - full SDK integration out of scope
    const timer = setTimeout(() => {
      setPositions([]);
      setLoading(false);
    }, 300);
    return () => clearTimeout(timer);
  }, []);

  return { positions, loading, error };
}
