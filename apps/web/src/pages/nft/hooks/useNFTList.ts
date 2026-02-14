import { useState, useEffect, useMemo, useCallback } from 'react';
import type { NFTCollection, NFTItem } from '@rabby/shared';
import { useCurrentAccount } from '../../../hooks';
import { useChainStore } from '../../../store/chain';

/** Persisted starred collection ids */
const STARRED_KEY = 'rabby-nft-starred';

function loadStarred(): string[] {
  try {
    return JSON.parse(localStorage.getItem(STARRED_KEY) || '[]');
  } catch {
    return [];
  }
}

function saveStarred(ids: string[]) {
  localStorage.setItem(STARRED_KEY, JSON.stringify(ids));
}

// ---------------------------------------------------------------------------
// Mock data generator (will be replaced by real API)
// ---------------------------------------------------------------------------
function buildMockCollections(): NFTCollection[] {
  const chains = ['eth', 'bsc', 'polygon', 'arb'];
  const names = [
    'Bored Ape Yacht Club',
    'CryptoPunks',
    'Azuki',
    'Doodles',
    'Moonbirds',
    'CloneX',
    'Pudgy Penguins',
    'Cool Cats',
  ];

  return names.map((name, i) => {
    const chain = chains[i % chains.length];
    const nftCount = Math.floor(Math.random() * 5) + 1;
    const nftList: NFTItem[] = Array.from({ length: nftCount }, (_, j) => ({
      id: `nft-${i}-${j}`,
      contract_id: `0x${String(i).padStart(40, '0')}`,
      inner_id: `${j + 1}`,
      chain,
      name: `${name} #${j + 1000}`,
      description: `A unique piece from the ${name} collection.`,
      content_type: 'image/png',
      content: `https://picsum.photos/seed/${i}-${j}/400/400`,
      thumbnail_url: `https://picsum.photos/seed/${i}-${j}/200/200`,
      detail_url: `https://etherscan.io/token/0x${String(i).padStart(40, '0')}`,
      amount: name.includes('Clone') ? Math.floor(Math.random() * 3) + 1 : 1,
    }));

    return {
      id: `collection-${i}`,
      chain,
      name,
      symbol: name.split(' ').map((w) => w[0]).join(''),
      logo_url: `https://picsum.photos/seed/col-${i}/64/64`,
      is_core: i < 3,
      floor_price: Math.random() * 50 + 0.1,
      amount: nftCount,
      nft_list: nftList,
    };
  });
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export interface UseNFTListReturn {
  collections: NFTCollection[];
  filteredCollections: NFTCollection[];
  loading: boolean;
  searchKeyword: string;
  setSearchKeyword: (kw: string) => void;
  chainFilter: string;
  setChainFilter: (chain: string) => void;
  starredIds: string[];
  toggleStar: (id: string) => void;
  isStar: (id: string) => boolean;
  viewMode: 'collection' | 'grid';
  setViewMode: (mode: 'collection' | 'grid') => void;
}

export function useNFTList(): UseNFTListReturn {
  const { address } = useCurrentAccount();
  const chainList = useChainStore((s) => s.chainList);

  const [collections, setCollections] = useState<NFTCollection[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchKeyword, setSearchKeyword] = useState('');
  const [chainFilter, setChainFilter] = useState('all');
  const [starredIds, setStarredIds] = useState<string[]>(loadStarred);
  const [viewMode, setViewMode] = useState<'collection' | 'grid'>('collection');

  // Fetch NFTs
  useEffect(() => {
    setLoading(true);
    // Simulate API call
    const timer = setTimeout(() => {
      setCollections(buildMockCollections());
      setLoading(false);
    }, 600);
    return () => clearTimeout(timer);
  }, [address]);

  // Filter
  const filteredCollections = useMemo(() => {
    let result = collections;

    if (chainFilter && chainFilter !== 'all') {
      result = result.filter((c) => c.chain === chainFilter);
    }

    if (searchKeyword.trim()) {
      const q = searchKeyword.toLowerCase();
      result = result.filter(
        (c) =>
          c.name.toLowerCase().includes(q) ||
          c.nft_list.some((n) => n.name.toLowerCase().includes(q))
      );
    }

    // Starred first
    result = [
      ...result.filter((c) => starredIds.includes(c.id)),
      ...result.filter((c) => !starredIds.includes(c.id)),
    ];

    return result;
  }, [collections, chainFilter, searchKeyword, starredIds]);

  const toggleStar = useCallback(
    (id: string) => {
      setStarredIds((prev) => {
        const next = prev.includes(id)
          ? prev.filter((x) => x !== id)
          : [...prev, id];
        saveStarred(next);
        return next;
      });
    },
    []
  );

  const isStar = useCallback(
    (id: string) => starredIds.includes(id),
    [starredIds]
  );

  return {
    collections,
    filteredCollections,
    loading,
    searchKeyword,
    setSearchKeyword,
    chainFilter,
    setChainFilter,
    starredIds,
    toggleStar,
    isStar,
    viewMode,
    setViewMode,
  };
}
