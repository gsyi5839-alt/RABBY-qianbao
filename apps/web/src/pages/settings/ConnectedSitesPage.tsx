import React, { useState, useMemo, useCallback } from 'react';
import { PageHeader } from '../../components/layout';
import { Empty, Button, Modal, toast } from '../../components/ui';
import { ChainIcon } from '../../components/chain';
import { useChain } from '../../hooks';

// ---------------------------------------------------------------------------
// Mock connected sites data
// ---------------------------------------------------------------------------
interface ConnectedSite {
  origin: string;
  name: string;
  icon: string;
  chainEnum: string;
  connectedAt: number;
}

function loadMockSites(): ConnectedSite[] {
  return [
    {
      origin: 'https://app.uniswap.org',
      name: 'Uniswap',
      icon: 'https://app.uniswap.org/favicon.ico',
      chainEnum: 'ETH',
      connectedAt: Date.now() - 86400000,
    },
    {
      origin: 'https://app.aave.com',
      name: 'Aave',
      icon: 'https://app.aave.com/favicon.ico',
      chainEnum: 'ETH',
      connectedAt: Date.now() - 172800000,
    },
    {
      origin: 'https://pancakeswap.finance',
      name: 'PancakeSwap',
      icon: 'https://pancakeswap.finance/favicon.ico',
      chainEnum: 'BSC',
      connectedAt: Date.now() - 259200000,
    },
    {
      origin: 'https://opensea.io',
      name: 'OpenSea',
      icon: 'https://opensea.io/favicon.ico',
      chainEnum: 'ETH',
      connectedAt: Date.now() - 345600000,
    },
  ];
}

// ---------------------------------------------------------------------------
// Connected Sites Page
// ---------------------------------------------------------------------------
const ConnectedSitesPage: React.FC = () => {
  const [sites, setSites] = useState<ConnectedSite[]>(loadMockSites);
  const { findChainByEnum } = useChain();
  const [disconnectTarget, setDisconnectTarget] = useState<ConnectedSite | null>(null);

  const handleDisconnect = useCallback(() => {
    if (!disconnectTarget) return;
    setSites((prev) =>
      prev.filter((s) => s.origin !== disconnectTarget.origin)
    );
    setDisconnectTarget(null);
    toast.success('Site disconnected');
  }, [disconnectTarget]);

  const handleDisconnectAll = useCallback(() => {
    setSites([]);
    toast.success('All sites disconnected');
  }, []);

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader
        title="Connected Sites"
        rightSlot={
          sites.length > 0 ? (
            <button
              className="text-xs text-[var(--r-red-default)] font-medium min-w-[44px] min-h-[44px] flex items-center justify-center"
              onClick={handleDisconnectAll}
            >
              Disconnect All
            </button>
          ) : undefined
        }
      />

      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {sites.length === 0 ? (
          <Empty description="No connected sites" />
        ) : (
          <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden divide-y divide-[var(--r-neutral-line)]">
            {sites.map((site) => {
              const chain = findChainByEnum(site.chainEnum);

              return (
                <div
                  key={site.origin}
                  className="flex items-center gap-3 px-4 py-3 min-h-[56px]"
                >
                  {/* Favicon */}
                  <div className="w-10 h-10 rounded-lg overflow-hidden bg-[var(--r-neutral-bg-2)] flex items-center justify-center flex-shrink-0">
                    <img
                      src={site.icon}
                      alt={site.name}
                      className="w-6 h-6 object-contain"
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = 'none';
                      }}
                    />
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
                      {site.name}
                    </div>
                    <div className="text-xs text-[var(--r-neutral-foot)] truncate">
                      {site.origin}
                    </div>
                  </div>

                  {/* Chain indicator */}
                  {chain && (
                    <ChainIcon chain={chain} size="sm" className="flex-shrink-0" />
                  )}

                  {/* Disconnect */}
                  <button
                    className="flex-shrink-0 p-2 min-w-[44px] min-h-[44px] flex items-center justify-center text-[var(--r-red-default)]"
                    onClick={() => setDisconnectTarget(site)}
                  >
                    <DisconnectIcon />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Disconnect confirmation */}
      <Modal
        visible={!!disconnectTarget}
        onClose={() => setDisconnectTarget(null)}
        title="Disconnect Site"
        footer={
          <div className="flex gap-3">
            <Button variant="ghost" fullWidth onClick={() => setDisconnectTarget(null)}>
              Cancel
            </Button>
            <Button variant="danger" fullWidth onClick={handleDisconnect}>
              Disconnect
            </Button>
          </div>
        }
      >
        <p className="text-sm text-[var(--r-neutral-body)]">
          Are you sure you want to disconnect{' '}
          <strong>{disconnectTarget?.name}</strong>?
        </p>
      </Modal>
    </div>
  );
};

export default ConnectedSitesPage;

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------
const DisconnectIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path d="M4 4l8 8M4 12l8-8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);
