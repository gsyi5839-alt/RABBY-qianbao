import React, { useState, useCallback, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import type { NFTItem } from '@rabby/shared';
import { useCurrentAccount, useChain } from '../../hooks';
import { useTransactionStore } from '../../store/transaction';
import { PageHeader } from '../../components/layout';
import { Button, toast } from '../../components/ui';
import { isValidAddress } from '../../utils';
import { AddressInput } from '../send/components/AddressInput';
import { GasFeeBar } from '../send/components/GasFeeBar';
import { NFTPreviewCard } from './NFTPreviewCard';

export const SendNFTPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { address: currentAddress } = useCurrentAccount();
  const { findChainByServerId } = useChain();
  const addPendingTx = useTransactionStore((s) => s.addPendingTx);

  const nftItem = useMemo<NFTItem | null>(() => {
    const param = searchParams.get('nftItem');
    if (!param) return null;
    try {
      return JSON.parse(decodeURIComponent(param));
    } catch {
      return null;
    }
  }, [searchParams]);

  const chainInfo = useMemo(() => {
    return nftItem ? findChainByServerId(nftItem.chain) || null : null;
  }, [nftItem, findChainByServerId]);

  const [toAddress, setToAddress] = useState(searchParams.get('to') || '');
  const [amount, setAmount] = useState(1);
  const [isSending, setIsSending] = useState(false);

  const isERC1155 = nftItem ? nftItem.amount > 1 : false;

  const canSubmit = useMemo(() => {
    if (!toAddress || !isValidAddress(toAddress)) return false;
    if (!nftItem) return false;
    if (amount <= 0) return false;
    if (isERC1155 && amount > nftItem.amount) return false;
    return !isSending;
  }, [toAddress, nftItem, amount, isERC1155, isSending]);

  const gasLevels = useMemo(
    () => [
      { level: 'slow' as const, price: 20e9 },
      { level: 'normal' as const, price: 35e9 },
      { level: 'fast' as const, price: 50e9 },
    ],
    []
  );

  const handleBack = useCallback(() => navigate(-1), [navigate]);

  const handleSelectAddress = useCallback(() => {
    const params = new URLSearchParams();
    params.set('type', 'send-nft');
    if (nftItem) {
      params.set('nftItem', encodeURIComponent(JSON.stringify(nftItem)));
    }
    navigate(`/select-to-address?${params.toString()}`);
  }, [navigate, nftItem]);

  const handleSend = useCallback(async () => {
    if (!canSubmit || !nftItem || !currentAddress) return;
    setIsSending(true);
    try {
      const txId = `nft-tx-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      addPendingTx({
        id: txId,
        from: currentAddress,
        to: toAddress,
        chainId: chainInfo?.id,
        status: 'pending',
        createdAt: Date.now(),
      });
      toast('NFT transfer submitted');
      navigate('/dashboard');
    } catch (e: any) {
      toast(e?.message || 'Transaction failed');
    } finally {
      setIsSending(false);
    }
  }, [canSubmit, nftItem, currentAddress, toAddress, chainInfo, addPendingTx, navigate]);

  if (!nftItem) {
    return (
      <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
        <PageHeader title="Send NFT" onBack={handleBack} />
        <div className="flex-1 flex items-center justify-center">
          <p className="text-[var(--r-neutral-foot)] text-sm">No NFT selected</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Send NFT" onBack={handleBack} />

      <div className="flex-1 overflow-y-auto px-4 pb-4">
        <NFTPreviewCard
          nftItem={nftItem}
          chainInfo={chainInfo}
          amount={amount}
          isERC1155={isERC1155}
          onAmountChange={setAmount}
        />

        <div className="mb-4">
          <AddressInput
            value={toAddress}
            onChange={setToAddress}
            onSelectClick={handleSelectAddress}
          />
        </div>

        <div className="bg-[var(--r-neutral-card-1)] rounded-xl">
          <GasFeeBar
            gasLevels={gasLevels}
            selectedLevel="normal"
            gasLimit={65000}
            nativeTokenSymbol={chainInfo?.nativeTokenSymbol || 'ETH'}
          />
        </div>
      </div>

      <div className="px-4 pb-6 pt-2 border-t border-[var(--r-neutral-line)]">
        <Button className="w-full" disabled={!canSubmit} onClick={handleSend}>
          {isSending ? 'Sending...' : 'Send NFT'}
        </Button>
      </div>
    </div>
  );
};
