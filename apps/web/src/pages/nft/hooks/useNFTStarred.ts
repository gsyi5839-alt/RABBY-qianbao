import { useLocalStorage } from '../../../hooks/useLocalStorage';
import { useCallback } from 'react';

const STARRED_KEY = 'rabby_nft_starred';

export function useNFTStarred() {
  const [starred, setStarred] = useLocalStorage<string[]>(STARRED_KEY, []);

  const toggleStar = useCallback(
    (nftId: string) => {
      setStarred((prev) =>
        prev.includes(nftId)
          ? prev.filter((id) => id !== nftId)
          : [...prev, nftId],
      );
    },
    [setStarred],
  );

  const isStarred = useCallback(
    (nftId: string) => starred.includes(nftId),
    [starred],
  );

  return { starred, toggleStar, isStarred };
}
