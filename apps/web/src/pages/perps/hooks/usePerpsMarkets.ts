import { useState, useEffect } from 'react';

interface MarketEntry {
  symbol: string;
  price: number;
  change24h: number;
  volume24h: number;
}

const MOCK_MARKETS: MarketEntry[] = [
  { symbol: 'BTC', price: 67000, change24h: 2.5, volume24h: 1200000000 },
  { symbol: 'ETH', price: 3500, change24h: -1.2, volume24h: 800000000 },
  { symbol: 'SOL', price: 180, change24h: 5.1, volume24h: 400000000 },
  { symbol: 'ARB', price: 1.15, change24h: -0.8, volume24h: 120000000 },
  { symbol: 'DOGE', price: 0.15, change24h: 3.2, volume24h: 250000000 },
  { symbol: 'AVAX', price: 38, change24h: 1.7, volume24h: 180000000 },
  { symbol: 'MATIC', price: 0.72, change24h: -2.1, volume24h: 95000000 },
  { symbol: 'LINK', price: 14.5, change24h: 0.9, volume24h: 110000000 },
];

export function usePerpsMarkets() {
  const [markets, setMarkets] = useState<MarketEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Simulate API fetch with mock data
    const timer = setTimeout(() => {
      setMarkets(MOCK_MARKETS);
      setLoading(false);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  return { markets, loading, error };
}
