import { useState, useCallback, useRef, useEffect, useMemo } from 'react';
import type { TokenItem, Chain } from '@rabby/shared';
import type { SwapQuoteResult, DexInfo } from '../../../services/api';
import { swapApi } from '../../../services/api';
import { useCurrentAccount } from '../../../hooks';
import { useChainStore } from '../../../store';

export interface DexQuoteItem {
  dex: DexInfo;
  quote: SwapQuoteResult | null;
  loading: boolean;
  error?: string;
}

const SLIPPAGE_PRESETS = [0.1, 0.5, 1.0];
const DEFAULT_SLIPPAGE = 0.5;
const DEBOUNCE_MS = 600;

export function useSwapState() {
  const { currentAccount } = useCurrentAccount();
  const chainList = useChainStore((s) => s.chainList);

  // Chain
  const [chain, setChain] = useState<Chain | null>(
    chainList.find((c) => c.enum === 'ETH') || chainList[0] || null
  );

  // Tokens
  const [fromToken, setFromToken] = useState<TokenItem | null>(null);
  const [toToken, setToToken] = useState<TokenItem | null>(null);
  const [fromAmount, setFromAmount] = useState('');
  const [toAmount, setToAmount] = useState('');

  // Quotes
  const [dexList, setDexList] = useState<DexInfo[]>([]);
  const [quotes, setQuotes] = useState<DexQuoteItem[]>([]);
  const [quotesLoading, setQuotesLoading] = useState(false);
  const [selectedDex, setSelectedDex] = useState<string | null>(null);

  // Slippage
  const [slippage, setSlippage] = useState(DEFAULT_SLIPPAGE);
  const [autoSlippage, setAutoSlippage] = useState(true);
  const [isCustomSlippage, setIsCustomSlippage] = useState(false);

  // UI state
  const [confirmVisible, setConfirmVisible] = useState(false);
  const [swapLoading, setSwapLoading] = useState(false);

  const debounceRef = useRef<ReturnType<typeof setTimeout>>();
  const abortRef = useRef<AbortController>();

  // Best quote
  const bestQuote = useMemo(() => {
    const valid = quotes.filter((q) => q.quote && !q.error);
    if (!valid.length) return null;
    return valid.reduce((best, curr) => {
      const bestAmt = best.quote?.receive_token_raw_amount || 0;
      const currAmt = curr.quote?.receive_token_raw_amount || 0;
      return currAmt > bestAmt ? curr : best;
    });
  }, [quotes]);

  // Selected quote
  const activeQuote = useMemo(() => {
    if (selectedDex) {
      return quotes.find((q) => q.dex.id === selectedDex) || bestQuote;
    }
    return bestQuote;
  }, [quotes, selectedDex, bestQuote]);

  // Price impact
  const priceImpact = useMemo(() => {
    if (!fromToken || !toToken || !activeQuote?.quote) return null;
    const fromUsd = parseFloat(fromAmount || '0') * (fromToken.price || 0);
    const receiveAmt = activeQuote.quote.receive_token_raw_amount /
      Math.pow(10, toToken.decimals);
    const toUsd = receiveAmt * (toToken.price || 0);
    if (fromUsd === 0) return null;
    return ((fromUsd - toUsd) / fromUsd) * 100;
  }, [fromToken, toToken, fromAmount, activeQuote]);

  // Insufficient balance
  const insufficient = useMemo(() => {
    if (!fromToken || !fromAmount) return false;
    return parseFloat(fromAmount) > (fromToken.amount || 0);
  }, [fromToken, fromAmount]);

  // Fetch DEX list when chain changes
  useEffect(() => {
    if (!chain) return;
    swapApi.getSwapSupportedDexes(chain.serverId).then(setDexList).catch(() => {
      setDexList([]);
    });
  }, [chain?.serverId]);

  // Fetch quotes with debounce
  const fetchQuotes = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (abortRef.current) abortRef.current.abort();

    if (!fromToken || !toToken || !fromAmount || parseFloat(fromAmount) <= 0 || !chain || !currentAccount) {
      setQuotes([]);
      setToAmount('');
      setQuotesLoading(false);
      return;
    }

    setQuotesLoading(true);

    debounceRef.current = setTimeout(async () => {
      const controller = new AbortController();
      abortRef.current = controller;

      const rawAmount = (
        parseFloat(fromAmount) * Math.pow(10, fromToken.decimals)
      ).toFixed(0);

      const results: DexQuoteItem[] = dexList.map((dex) => ({
        dex,
        quote: null,
        loading: true,
      }));
      setQuotes([...results]);

      const promises = dexList.map(async (dex, idx) => {
        try {
          const quote = await swapApi.getSwapQuote({
            id: currentAccount.address,
            chain_id: chain.serverId,
            dex_id: dex.id,
            pay_token_id: fromToken.id,
            pay_token_raw_amount: rawAmount,
            receive_token_id: toToken.id,
            slippage: String(slippage / 100),
          });
          results[idx] = { dex, quote, loading: false };
        } catch (err) {
          results[idx] = {
            dex,
            quote: null,
            loading: false,
            error: 'Failed to fetch quote',
          };
        }
        if (!controller.signal.aborted) {
          setQuotes([...results]);
        }
      });

      await Promise.allSettled(promises);

      if (!controller.signal.aborted) {
        setQuotesLoading(false);
        // Set toAmount from best quote
        const valid = results.filter((r) => r.quote && !r.error);
        if (valid.length) {
          const best = valid.reduce((a, b) =>
            (b.quote?.receive_token_raw_amount || 0) >
            (a.quote?.receive_token_raw_amount || 0)
              ? b
              : a
          );
          if (best.quote && toToken) {
            const amount = best.quote.receive_token_raw_amount /
              Math.pow(10, toToken.decimals);
            setToAmount(String(amount));
          }
        }
      }
    }, DEBOUNCE_MS);
  }, [fromToken, toToken, fromAmount, chain, currentAccount, dexList, slippage]);

  // Trigger quote fetch on relevant changes
  useEffect(() => {
    fetchQuotes();
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [fetchQuotes]);

  // Reverse from/to tokens
  const exchangeTokens = useCallback(() => {
    const tmpToken = fromToken;
    const tmpAmount = toAmount;
    setFromToken(toToken);
    setToToken(tmpToken);
    setFromAmount(tmpAmount);
    setToAmount('');
    setSelectedDex(null);
  }, [fromToken, toToken, toAmount]);

  // Switch chain
  const switchChain = useCallback(
    (newChain: Chain) => {
      setChain(newChain);
      setFromToken(null);
      setToToken(null);
      setFromAmount('');
      setToAmount('');
      setQuotes([]);
      setSelectedDex(null);
    },
    []
  );

  // Handle max amount
  const handleMax = useCallback(() => {
    if (fromToken) {
      setFromAmount(String(fromToken.amount || 0));
    }
  }, [fromToken]);

  return {
    // Chain
    chain,
    chainList,
    switchChain,

    // Tokens
    fromToken,
    setFromToken,
    toToken,
    setToToken,
    fromAmount,
    setFromAmount,
    toAmount,

    // Quotes
    dexList,
    quotes,
    quotesLoading,
    bestQuote,
    activeQuote,
    selectedDex,
    setSelectedDex,

    // Slippage
    slippage,
    setSlippage,
    autoSlippage,
    setAutoSlippage,
    isCustomSlippage,
    setIsCustomSlippage,
    SLIPPAGE_PRESETS,

    // Computed
    priceImpact,
    insufficient,

    // Actions
    exchangeTokens,
    handleMax,
    fetchQuotes,

    // UI state
    confirmVisible,
    setConfirmVisible,
    swapLoading,
    setSwapLoading,
  };
}
