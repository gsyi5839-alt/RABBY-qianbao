import { useState, useCallback, useMemo, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import type { TokenItem, Chain } from '@rabby/shared';
import { useCurrentAccount, useChain, useTokenList } from '../../../hooks';
import { useTransactionStore } from '../../../store/transaction';
import { isValidAddress } from '../../../utils';
import { toast } from '../../../components/ui';

const DEFAULT_GAS_LIMIT = 21000;

export function useSendToken() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { address: currentAddress } = useCurrentAccount();
  const { chainList, currentChainInfo, switchChain } = useChain();
  const { tokenList, isLoading: tokensLoading } = useTokenList({
    withBalance: true,
    sortBy: 'value',
    sortOrder: 'desc',
  });
  const addPendingTx = useTransactionStore((s) => s.addPendingTx);

  // State
  const [toAddress, setToAddress] = useState(searchParams.get('to') || '');
  const [amount, setAmount] = useState(searchParams.get('amount') || '');
  const [selectedToken, setSelectedToken] = useState<TokenItem | null>(null);
  const [tokenSelectorVisible, setTokenSelectorVisible] = useState(false);
  const [gasSpeed, setGasSpeed] = useState<'slow' | 'normal' | 'fast'>('normal');
  const [isSending, setIsSending] = useState(false);
  const [addressError, setAddressError] = useState('');

  // Initialize token from query params or first in list
  useEffect(() => {
    if (selectedToken) return;
    const tokenParam = searchParams.get('token');
    if (tokenParam && tokenList.length > 0) {
      const [chain, id] = tokenParam.split(':');
      const found = tokenList.find((t) => t.chain === chain && t.id === id);
      if (found) {
        setSelectedToken(found);
        return;
      }
    }
    if (tokenList.length > 0 && !selectedToken) {
      setSelectedToken(tokenList[0]);
    }
  }, [tokenList, searchParams, selectedToken]);

  // Derived
  const tokenBalance = selectedToken?.amount ?? 0;

  const usdValue = useMemo(() => {
    if (!selectedToken || !amount) return '';
    const val = parseFloat(amount) * selectedToken.price;
    return isNaN(val) ? '' : val.toFixed(2);
  }, [selectedToken, amount]);

  const balanceError = useMemo(() => {
    if (!amount || !selectedToken) return '';
    const num = parseFloat(amount);
    if (isNaN(num)) return '';
    return num > tokenBalance ? 'Insufficient balance' : '';
  }, [amount, selectedToken, tokenBalance]);

  const canSubmit = useMemo(() => {
    if (!toAddress || !isValidAddress(toAddress)) return false;
    if (!selectedToken) return false;
    if (!amount || parseFloat(amount) <= 0) return false;
    if (balanceError) return false;
    return !isSending;
  }, [toAddress, selectedToken, amount, balanceError, isSending]);

  const gasLevels = useMemo(
    () => [
      { level: 'slow' as const, price: 20e9, estimatedSeconds: 60 },
      { level: 'normal' as const, price: 35e9, estimatedSeconds: 30 },
      { level: 'fast' as const, price: 50e9, estimatedSeconds: 15 },
    ],
    []
  );

  const nativeTokenPrice = useMemo(() => {
    const native = tokenList.find(
      (t) =>
        t.chain === currentChainInfo?.serverId &&
        t.id === currentChainInfo?.nativeTokenAddress
    );
    return native?.price || 0;
  }, [tokenList, currentChainInfo]);

  // Handlers
  const handleBack = useCallback(() => navigate(-1), [navigate]);

  const handleMaxClick = useCallback(() => {
    if (selectedToken) setAmount(String(tokenBalance));
  }, [selectedToken, tokenBalance]);

  const handleTokenSelect = useCallback((token: TokenItem) => {
    setSelectedToken(token);
    setAmount('');
  }, []);

  const handleChainChange = useCallback(
    (chain: Chain) => {
      switchChain(chain.enum);
      setSelectedToken(null);
      setAmount('');
    },
    [switchChain]
  );

  const handleSelectAddress = useCallback(() => {
    const params = new URLSearchParams();
    params.set('type', 'send-token');
    if (selectedToken) {
      params.set('token', `${selectedToken.chain}:${selectedToken.id}`);
    }
    if (amount) params.set('amount', amount);
    navigate(`/select-to-address?${params.toString()}`);
  }, [navigate, selectedToken, amount]);

  const handleSend = useCallback(async () => {
    if (!canSubmit || !selectedToken || !currentAddress) return;
    setIsSending(true);
    try {
      const txId = `tx-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      addPendingTx({
        id: txId,
        from: currentAddress,
        to: toAddress,
        value: amount,
        chainId: currentChainInfo?.id,
        status: 'pending',
        createdAt: Date.now(),
      });
      toast('Transaction submitted successfully');
      navigate('/dashboard');
    } catch (e: any) {
      toast(e?.message || 'Transaction failed');
    } finally {
      setIsSending(false);
    }
  }, [canSubmit, selectedToken, currentAddress, toAddress, amount, currentChainInfo, addPendingTx, navigate]);

  return {
    // State
    toAddress, setToAddress,
    amount, setAmount,
    selectedToken,
    tokenSelectorVisible, setTokenSelectorVisible,
    gasSpeed, setGasSpeed,
    isSending,
    addressError,
    // Derived
    tokenBalance, usdValue, balanceError, canSubmit,
    gasLevels, nativeTokenPrice,
    // Lists
    chainList, currentChainInfo, tokenList, tokensLoading,
    // Handlers
    handleBack, handleMaxClick, handleTokenSelect,
    handleChainChange, handleSelectAddress, handleSend,
    DEFAULT_GAS_LIMIT,
  };
}
