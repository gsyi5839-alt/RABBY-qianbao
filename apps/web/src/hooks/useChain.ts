import { useCallback, useMemo } from 'react';
import { useChainStore } from '../store/chain';
import type { Chain } from '@rabby/shared';

/**
 * Chain management hook.
 *
 * Provides access to the current chain, chain list,
 * pinned chains, and chain switching functionality.
 *
 * Modeled after the extension's useChain / useAsyncInitializeChainList hooks.
 */
export function useChain() {
  const currentChain = useChainStore((s) => s.currentChain);
  const chainList = useChainStore((s) => s.chainList);
  const pinnedChains = useChainStore((s) => s.pinnedChains);
  const customRPCs = useChainStore((s) => s.customRPCs);
  const setCurrentChain = useChainStore((s) => s.setCurrentChain);
  const addPinnedChain = useChainStore((s) => s.addPinnedChain);
  const removePinnedChain = useChainStore((s) => s.removePinnedChain);
  const addCustomRPC = useChainStore((s) => s.addCustomRPC);
  const removeCustomRPC = useChainStore((s) => s.removeCustomRPC);

  const currentChainInfo = useMemo(() => {
    return chainList.find(
      (chain) => chain.enum === currentChain || chain.serverId === currentChain
    );
  }, [chainList, currentChain]);

  const switchChain = useCallback(
    (chainEnum: string) => {
      setCurrentChain(chainEnum);
    },
    [setCurrentChain]
  );

  const findChainByEnum = useCallback(
    (chainEnum: string): Chain | undefined => {
      return chainList.find((chain) => chain.enum === chainEnum);
    },
    [chainList]
  );

  const findChainByServerId = useCallback(
    (serverId: string): Chain | undefined => {
      return chainList.find((chain) => chain.serverId === serverId);
    },
    [chainList]
  );

  const findChainById = useCallback(
    (id: number): Chain | undefined => {
      return chainList.find((chain) => chain.id === id);
    },
    [chainList]
  );

  /**
   * Returns chains sorted by: pinned first, then by balance, then alphabetical.
   * Modeled after the extension's varyAndSortChainItems.
   */
  const sortedChainList = useMemo(() => {
    const pinned: Chain[] = [];
    const unpinned: Chain[] = [];

    for (const chain of chainList) {
      if (pinnedChains.includes(chain.enum)) {
        pinned.push(chain);
      } else {
        unpinned.push(chain);
      }
    }

    return [...pinned, ...unpinned];
  }, [chainList, pinnedChains]);

  const mainnetList = useMemo(() => {
    return chainList.filter((chain) => !chain.isTestnet);
  }, [chainList]);

  const testnetList = useMemo(() => {
    return chainList.filter((chain) => chain.isTestnet);
  }, [chainList]);

  return {
    // State
    currentChain,
    currentChainInfo,
    chainList,
    sortedChainList,
    mainnetList,
    testnetList,
    pinnedChains,
    customRPCs,

    // Actions
    switchChain,
    findChainByEnum,
    findChainByServerId,
    findChainById,
    addPinnedChain,
    removePinnedChain,
    addCustomRPC,
    removeCustomRPC,
  };
}
