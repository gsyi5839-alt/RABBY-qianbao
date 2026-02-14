import { useState, useCallback, useRef, useEffect, useMemo } from 'react';
import type { TokenItem, Chain } from '@rabby/shared';
import type { BridgeQuoteWithoutTx, BridgeAggregator } from '../../../services/api';
import { bridgeApi } from '../../../services/api';
import { useCurrentAccount } from '../../../hooks';
import { useChainStore } from '../../../store';

export interface BridgeQuoteItem extends BridgeQuoteWithoutTx {
  loading?: boolean;
}

const DEFAULT_SLIPPAGE = 1.0;
const DEBOUNCE_MS = 600;

export function useBridgeState() {
  const { currentAccount } = useCurrentAccount();
  const chainList = useChainStore((s) => s.chainList);
  const mainnetList = useMemo(
    () => chainList.filter((c) => !c.isTestnet),
    [chainList]
  );

  // Chains
  const [fromChain, setFromChain] = useState<Chain | null>(
    mainnetList.find((c) => c.enum === 'ETH') || mainnetList[0] || null
  );
  const [toChain, setToChain] = useState<Chain | null>(null);

  // Tokens
  const [fromToken, setFromToken] = useState<TokenItem | null>(null);
  const [toToken, setToToken] = useState<TokenItem | null>(null);
  const [amount, setAmount] = useState('');

  // Quotes
  const [aggregators, setAggregators] = useState<BridgeAggregator[]>([]);
  const [quotes, setQuotes] = useState<BridgeQuoteItem[]>([]);
  const [quotesLoading, setQuotesLoading] = useState(false);
  const [selectedQuote, setSelectedQuote] = useState<BridgeQuoteItem | null>(
    null
  );

  // Slippage
  const [slippage, setSlippage] = useState(DEFAULT_SLIPPAGE);

  // UI
  const [confirmVisible, setConfirmVisible] = useState(false);
  const [bridgeLoading, setBridgeLoading] = useState(false);

  const debounceRef = useRef<ReturnType<typeof setTimeout>>();
  const abortRef = useRef<AbortController>();

  // Best quote
  const bestQuote = useMemo(() => {
    if (!quotes.length) return null;
    const valid = quotes.filter(
      (q) => q.to_token_amount > 0 && !q.loading
    );
    if (!valid.length) return null;
    return valid.reduce((best, curr) =>
      curr.to_token_amount > best.to_token_amount ? curr : best
    );
  }, [quotes]);

  // Active quote (selected or best)
  const activeQuote = useMemo(() => {
    return selectedQuote || bestQuote;
  }, [selectedQuote, bestQuote]);

  // Insufficient balance
  const insufficient = useMemo(() => {
    if (!fromToken || !amount) return false;
    return parseFloat(amount) > (fromToken.amount || 0);
  }, [fromToken, amount]);

  // Fetch aggregators on mount
  useEffect(() => {
    bridgeApi
      .getBridgeAggregatorList()
      .then(setAggregators)
      .catch(() => setAggregators([]));
  }, []);

  // Fetch quotes with debounce
  const fetchQuotes = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (abortRef.current) abortRef.current.abort();

    if (
      !fromToken ||
      !toToken ||
      !amount ||
      parseFloat(amount) <= 0 ||
      !fromChain ||
      !toChain ||
      !currentAccount ||
      !aggregators.length
    ) {
      setQuotes([]);
      setQuotesLoading(false);
      return;
    }

    setQuotesLoading(true);

    debounceRef.current = setTimeout(async () => {
      const controller = new AbortController();
      abortRef.current = controller;

      const rawAmount = (
        parseFloat(amount) * Math.pow(10, fromToken.decimals)
      ).toFixed(0);

      const aggIds = aggregators.map((a) => a.id).join(',');

      try {
        const results = await bridgeApi.getBridgeQuotes({
          aggregator_ids: aggIds,
          user_addr: currentAccount.address,
          from_chain_id: fromToken.chain,
          from_token_id: fromToken.id,
          from_token_raw_amount: rawAmount,
          to_chain_id: toToken.chain,
          to_token_id: toToken.id,
        });

        if (!controller.signal.aborted) {
          setQuotes(results);
          setSelectedQuote(null);
        }
      } catch {
        if (!controller.signal.aborted) {
          setQuotes([]);
        }
      } finally {
        if (!controller.signal.aborted) {
          setQuotesLoading(false);
        }
      }
    }, DEBOUNCE_MS);
  }, [
    fromToken,
    toToken,
    amount,
    fromChain,
    toChain,
    currentAccount,
    aggregators,
  ]);

  // Trigger fetch on relevant changes
  useEffect(() => {
    fetchQuotes();
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [fetchQuotes]);

  // Switch chains + tokens
  const switchChains = useCallback(() => {
    const tmpChain = fromChain;
    const tmpToken = fromToken;
    setFromChain(toChain);
    setToChain(tmpChain);
    setFromToken(toToken);
    setToToken(tmpToken);
    setAmount('');
    setQuotes([]);
    setSelectedQuote(null);
  }, [fromChain, toChain, fromToken, toToken]);

  // Handle from chain change
  const handleFromChainChange = useCallback(
    (chain: Chain) => {
      setFromChain(chain);
      setFromToken(null);
      setAmount('');
      setQuotes([]);
      setSelectedQuote(null);
    },
    []
  );

  // Handle to chain change
  const handleToChainChange = useCallback(
    (chain: Chain) => {
      setToChain(chain);
      setToToken(null);
      setQuotes([]);
      setSelectedQuote(null);
    },
    []
  );

  // Handle max amount
  const handleMax = useCallback(() => {
    if (fromToken) {
      setAmount(String(fromToken.amount || 0));
    }
  }, [fromToken]);

  return {
    // Chains
    fromChain,
    toChain,
    chainList: mainnetList,
    handleFromChainChange,
    handleToChainChange,
    switchChains,

    // Tokens
    fromToken,
    setFromToken,
    toToken,
    setToToken,
    amount,
    setAmount,

    // Quotes
    quotes,
    quotesLoading,
    bestQuote,
    activeQuote,
    selectedQuote,
    setSelectedQuote,

    // Slippage
    slippage,
    setSlippage,

    // Computed
    insufficient,

    // Actions
    handleMax,
    fetchQuotes,

    // UI
    confirmVisible,
    setConfirmVisible,
    bridgeLoading,
    setBridgeLoading,
  };
}
