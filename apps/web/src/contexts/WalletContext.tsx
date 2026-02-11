import React, { createContext, useContext, useState, useCallback } from 'react';
import type { Account, TransactionRequest } from '@rabby/shared';

export type { Account };

export interface WCSessionPeer {
  name: string;
  url: string;
  icon?: string;
}

interface WalletContextValue {
  connected: boolean;
  accounts: Account[];
  currentAccount: Account | null;
  connect: (mode?: 'demo' | 'walletconnect') => Promise<void>;
  disconnect: () => void;
  setCurrentAccount: (account: Account | null) => void;
  wcProvider: any;
  wcSessionPeer: WCSessionPeer | null;
  chainId: number;
  setChainId: (chainId: number) => void;
  signTransaction: (tx: TransactionRequest) => Promise<string>;
  signMessage: (msg: string) => Promise<string>;
  sendTransaction: (tx: TransactionRequest) => Promise<string>;
}

const WalletContext = createContext<WalletContextValue | null>(null);

export function WalletProvider({ children }: { children: React.ReactNode }) {
  const [connected, setConnected] = useState(false);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [currentAccount, setCurrentAccount] = useState<Account | null>(null);
  const [wcProvider, setWcProvider] = useState<any>(null);
  const [wcSessionPeer, setWcSessionPeer] = useState<WCSessionPeer | null>(null);
  const [chainId, setChainId] = useState(1);

  const connect = useCallback(async (mode: 'demo' | 'walletconnect' = 'demo') => {
    if (mode === 'demo') {
      setAccounts([
        { address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', brandName: 'Rabby', type: 'HD Key Tree' },
      ]);
      setCurrentAccount({ address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', brandName: 'Rabby', type: 'HD Key Tree' });
      setConnected(true);
      return;
    }
    try {
      const { default: EthereumProvider } = await import('@walletconnect/ethereum-provider');
      const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;
      if (!projectId) throw new Error('请配置 VITE_WALLETCONNECT_PROJECT_ID，从 https://cloud.walletconnect.com 获取');
      const provider = await EthereumProvider.init({
        projectId,
        chains: [1],
        showQrModal: true,
      });
      await provider.connect();
      const addrs = await provider.request({ method: 'eth_requestAccounts' }) as string[];
      const accs = addrs.map((a) => ({ address: a, brandName: 'WalletConnect', type: 'WalletConnect' }));
      setAccounts(accs);
      setCurrentAccount(accs[0] || null);
      setWcProvider(provider);

      // Extract WC session peer metadata
      const session = (provider as any).session;
      if (session?.peer?.metadata) {
        const meta = session.peer.metadata;
        setWcSessionPeer({
          name: meta.name || 'Unknown DApp',
          url: meta.url || '',
          icon: meta.icons?.[0],
        });
      }

      setConnected(true);
    } catch (err) {
      console.error('WalletConnect:', err);
      throw err;
    }
  }, []);

  const disconnect = useCallback(async () => {
    if (wcProvider) {
      try { await wcProvider.disconnect(); } catch {}
      setWcProvider(null);
    }
    setWcSessionPeer(null);
    setAccounts([]);
    setCurrentAccount(null);
    setConnected(false);
  }, [wcProvider]);

  const signTransaction = useCallback(async (tx: TransactionRequest): Promise<string> => {
    if (!wcProvider) throw new Error('WalletConnect provider not available');
    const hash = await wcProvider.request({
      method: 'eth_sendTransaction',
      params: [tx],
    });
    return hash as string;
  }, [wcProvider]);

  const signMessage = useCallback(async (msg: string): Promise<string> => {
    if (!wcProvider) throw new Error('WalletConnect provider not available');
    if (!currentAccount) throw new Error('No account connected');
    const sig = await wcProvider.request({
      method: 'personal_sign',
      params: [msg, currentAccount.address],
    });
    return sig as string;
  }, [wcProvider, currentAccount]);

  const sendTransaction = useCallback(async (tx: TransactionRequest): Promise<string> => {
    return signTransaction(tx);
  }, [signTransaction]);

  return (
    <WalletContext.Provider
      value={{
        connected,
        accounts,
        currentAccount,
        connect,
        disconnect,
        setCurrentAccount,
        wcProvider,
        wcSessionPeer,
        chainId,
        setChainId,
        signTransaction,
        signMessage,
        sendTransaction,
      }}
    >
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet() {
  const ctx = useContext(WalletContext);
  if (!ctx) throw new Error('useWallet must be used within WalletProvider');
  return ctx;
}
