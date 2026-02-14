import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useBalanceStore } from '../store/balance';
import { useAccountStore } from '../store/account';
import type { TokenItem } from '@rabby/shared';

/**
 * Token list hook with search, filter, and sort capabilities.
 *
 * Returns the current account's token list with search filtering,
 * chain filtering, and sort options. Handles custom/blocked token
 * categorization.
 *
 * Modeled after the extension's useSearchToken / useIsTokenAddedLocally hooks.
 */

export type TokenSortField = 'value' | 'amount' | 'name' | 'price';
export type TokenSortOrder = 'asc' | 'desc';

interface UseTokenListOptions {
  /** Filter by chain server ID */
  chainServerId?: string;
  /** Only show tokens with balance > 0 */
  withBalance?: boolean;
  /** Initial search keyword */
  keyword?: string;
  /** Sort field */
  sortBy?: TokenSortField;
  /** Sort order */
  sortOrder?: TokenSortOrder;
}

function isWeb3Address(q: string): boolean {
  return q.length === 42 && q.toLowerCase().startsWith('0x');
}

function sortTokens(
  tokens: TokenItem[],
  sortBy: TokenSortField,
  sortOrder: TokenSortOrder
): TokenItem[] {
  const sorted = [...tokens];
  sorted.sort((a, b) => {
    let diff = 0;
    switch (sortBy) {
      case 'value':
        diff = a.price * a.amount - b.price * b.amount;
        break;
      case 'amount':
        diff = a.amount - b.amount;
        break;
      case 'name':
        diff = (a.symbol || '').localeCompare(b.symbol || '');
        break;
      case 'price':
        diff = a.price - b.price;
        break;
    }
    return sortOrder === 'desc' ? -diff : diff;
  });
  return sorted;
}

export function useTokenList(options: UseTokenListOptions = {}) {
  const {
    chainServerId,
    withBalance = false,
    keyword: initialKeyword = '',
    sortBy = 'value',
    sortOrder = 'desc',
  } = options;

  const tokenList = useBalanceStore((s) => s.tokenList);
  const customizeTokenList = useBalanceStore((s) => s.customizeTokenList);
  const blockedTokenList = useBalanceStore((s) => s.blockedTokenList);
  const isLoading = useBalanceStore((s) => s.isLoading);
  const fetchTokenList = useBalanceStore((s) => s.fetchTokenList);
  const currentAddress = useAccountStore((s) => s.currentAccount?.address);

  const [searchKeyword, setSearchKeyword] = useState(initialKeyword);
  const [searchResults, setSearchResults] = useState<TokenItem[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const searchRef = useRef(searchKeyword);

  // Update search ref on keyword change
  useEffect(() => {
    searchRef.current = searchKeyword;
  }, [searchKeyword]);

  /**
   * Filter + sort the token list from store (no API call, local filtering)
   */
  const filteredTokenList = useMemo(() => {
    let result = [...tokenList];

    // Filter by chain
    if (chainServerId) {
      result = result.filter((t) => t.chain === chainServerId);
    }

    // Filter by balance
    if (withBalance) {
      result = result.filter((t) => t.amount > 0);
    }

    // Filter out blocked tokens
    const blockedIds = new Set(blockedTokenList.map((t) => t.id));
    result = result.filter((t) => !blockedIds.has(t.id));

    // Sort
    result = sortTokens(result, sortBy, sortOrder);

    return result;
  }, [tokenList, chainServerId, withBalance, blockedTokenList, sortBy, sortOrder]);

  /**
   * Locally searched tokens (keyword matching against symbol, name, address)
   */
  const localSearchResults = useMemo(() => {
    if (!searchKeyword) return filteredTokenList;

    const kw = searchKeyword.toLowerCase();

    // If it looks like an address, match by id
    if (isWeb3Address(searchKeyword)) {
      return filteredTokenList.filter(
        (t) => t.id.toLowerCase() === kw
      );
    }

    // Otherwise fuzzy match on name/symbol
    return filteredTokenList.filter(
      (t) =>
        t.symbol.toLowerCase().includes(kw) ||
        t.name.toLowerCase().includes(kw) ||
        (t.display_symbol || '').toLowerCase().includes(kw)
    );
  }, [filteredTokenList, searchKeyword]);

  /**
   * Remote search (calls API). Used for finding tokens not in the local list.
   */
  const searchToken = useCallback(
    async (q: string) => {
      if (!currentAddress || !q) {
        setSearchResults([]);
        setIsSearching(false);
        return;
      }

      setIsSearching(true);
      try {
        // TODO: Call token search API when available
        // const results = await tokenApi.searchToken(currentAddress, q, chainServerId);
        // if (searchRef.current === q) {
        //   setSearchResults(results);
        // }
        setSearchResults([]);
      } catch (error) {
        console.error('[useTokenList] searchToken error:', error);
      } finally {
        setIsSearching(false);
      }
    },
    [currentAddress, chainServerId]
  );

  /**
   * Check whether a token is on the customize or blocked list
   */
  const isTokenAddedLocally = useCallback(
    (token: TokenItem): { onCustomize: boolean; onBlocked: boolean; isLocal: boolean } => {
      const onCustomize = customizeTokenList.some((t) => t.id === token.id);
      const onBlocked =
        !onCustomize &&
        blockedTokenList.some(
          (t) => t.chain === token.chain && t.id.toLowerCase() === token.id.toLowerCase()
        );

      return {
        onCustomize,
        onBlocked,
        isLocal: onCustomize || onBlocked,
      };
    },
    [customizeTokenList, blockedTokenList]
  );

  /**
   * Refresh token list from API
   */
  const refresh = useCallback(async () => {
    if (currentAddress) {
      await fetchTokenList(currentAddress);
    }
  }, [currentAddress, fetchTokenList]);

  return {
    // Data
    tokenList: filteredTokenList,
    searchResults: searchKeyword ? localSearchResults : filteredTokenList,
    remoteSearchResults: searchResults,
    customizeTokenList,
    blockedTokenList,

    // Search
    searchKeyword,
    setSearchKeyword,
    searchToken,
    isSearching,

    // Utils
    isTokenAddedLocally,
    isLoading,
    refresh,
  };
}
