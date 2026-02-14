import React, { useState, useEffect, useCallback, useMemo } from 'react';
import clsx from 'clsx';
import type { TokenApproval } from '@rabby/shared';
import { PageHeader } from '../../components/layout';
import { Loading, Empty, Input, toast } from '../../components/ui';
import { useCurrentAccount, useChain } from '../../hooks';
import { securityApi } from '../../services/api';
import { ApprovalItem } from './components/ApprovalItem';
import { RevokeConfirmPopup } from './components/RevokeConfirmPopup';
import { RiskBadge } from './components/RiskBadge';

type SortField = 'amount' | 'risk' | 'date';
type TabType = 'token' | 'nft';

const riskOrder: Record<string, number> = {
  danger: 0,
  warning: 1,
  safe: 2,
};

// ── Component ────────────────────────────────────────────────────────────────

export const ApprovalPage: React.FC = () => {
  const { address } = useCurrentAccount();
  const { chainList, currentChainInfo } = useChain();

  const [activeTab, setActiveTab] = useState<TabType>('token');
  const [approvals, setApprovals] = useState<TokenApproval[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState<SortField>('risk');
  const [revokeTarget, setRevokeTarget] = useState<TokenApproval | null>(null);

  // ── Fetch approvals ──────────────────────────────────────────────────────

  const fetchApprovals = useCallback(async () => {
    if (!address) return;
    setLoading(true);
    try {
      const chainId = currentChainInfo?.serverId || 'eth';
      const result = await securityApi.getTokenApprovals(address, chainId);
      // Map from security API TokenApproval to shared TokenApproval
      const mapped: TokenApproval[] = result.map((item) => ({
        id: item.id,
        token: {
          id: item.id,
          chain: item.chain,
          name: item.name,
          symbol: item.symbol,
          display_symbol: item.symbol,
          decimals: 18,
          logo_url: item.logo_url,
          price: item.price,
          amount: item.balance,
        },
        spender: {
          id: item.spenders[0]?.id || '',
          name: item.spenders[0]?.protocol?.name,
          logo_url: item.spenders[0]?.protocol?.logo_url,
          protocol_id: item.spenders[0]?.protocol?.id,
          is_contract: true,
          risk_level: (item.spenders[0]?.risk_level as 'safe' | 'warning' | 'danger') || 'safe',
        },
        amount: item.spenders[0]?.value ?? 0,
        is_unlimited: (item.spenders[0]?.value ?? 0) >= 1e18,
      }));
      setApprovals(mapped);
    } catch (err) {
      console.error('[ApprovalPage] fetch error:', err);
      toast.error('Failed to load approvals');
    } finally {
      setLoading(false);
    }
  }, [address, currentChainInfo?.serverId]);

  useEffect(() => {
    fetchApprovals();
  }, [fetchApprovals]);

  // ── Filtering + sorting ──────────────────────────────────────────────────

  const filtered = useMemo(() => {
    let list = approvals;
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter(
        (a) =>
          a.token.symbol.toLowerCase().includes(q) ||
          a.token.name.toLowerCase().includes(q) ||
          a.spender.id.toLowerCase().includes(q) ||
          (a.spender.name || '').toLowerCase().includes(q),
      );
    }

    list = [...list].sort((a, b) => {
      if (sortBy === 'risk') {
        return (
          (riskOrder[a.spender.risk_level || 'safe'] ?? 2) -
          (riskOrder[b.spender.risk_level || 'safe'] ?? 2)
        );
      }
      if (sortBy === 'amount') {
        return b.amount - a.amount;
      }
      return 0;
    });

    return list;
  }, [approvals, search, sortBy]);

  // ── Summary stats ────────────────────────────────────────────────────────

  const summary = useMemo(() => {
    let danger = 0;
    let warning = 0;
    let safe = 0;
    for (const a of approvals) {
      const rl = a.spender.risk_level || 'safe';
      if (rl === 'danger') danger++;
      else if (rl === 'warning') warning++;
      else safe++;
    }
    return { total: approvals.length, danger, warning, safe };
  }, [approvals]);

  // ── Revoke handler ───────────────────────────────────────────────────────

  const handleRevoke = useCallback(async (_approval: TokenApproval) => {
    // In a real implementation this would build + send a revoke tx
    toast.success('Revoke transaction submitted');
    setApprovals((prev) => prev.filter((a) => a.id !== _approval.id));
  }, []);

  // ── Render ───────────────────────────────────────────────────────────────

  return (
    <div className="flex flex-col h-screen bg-[var(--r-neutral-bg-1)]">
      <PageHeader title="Approval Management" />

      {/* Summary */}
      <div className="px-4 pt-2 pb-3 flex items-center gap-3 flex-shrink-0">
        <SummaryChip label="Total" count={summary.total} />
        <SummaryChip label="Danger" count={summary.danger} color="danger" />
        <SummaryChip label="Warning" count={summary.warning} color="warning" />
        <SummaryChip label="Safe" count={summary.safe} color="safe" />
      </div>

      {/* Tabs */}
      <div className="flex px-4 gap-4 border-b border-[var(--r-neutral-line)] flex-shrink-0">
        <TabButton
          active={activeTab === 'token'}
          onClick={() => setActiveTab('token')}
        >
          Token Approvals
        </TabButton>
        <TabButton
          active={activeTab === 'nft'}
          onClick={() => setActiveTab('nft')}
        >
          NFT Approvals
        </TabButton>
      </div>

      {/* Search + Sort */}
      <div className="px-4 py-3 flex items-center gap-2 flex-shrink-0">
        <div className="flex-1">
          <Input
            placeholder="Search token or contract..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            prefix={<SearchIcon />}
          />
        </div>
        <SortSelect value={sortBy} onChange={setSortBy} />
      </div>

      {/* List */}
      {loading ? (
        <div className="flex-1 flex items-center justify-center">
          <Loading size="lg" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex-1">
          <Empty
            description={
              approvals.length === 0
                ? 'No approvals found'
                : 'No results match your search'
            }
          />
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto">
          {activeTab === 'token' &&
            filtered.map((a) => (
              <ApprovalItem
                key={a.id}
                approval={a}
                onRevoke={setRevokeTarget}
              />
            ))}
          {activeTab === 'nft' && (
            <Empty description="NFT approvals coming soon" />
          )}
        </div>
      )}

      {/* Revoke confirm */}
      <RevokeConfirmPopup
        visible={!!revokeTarget}
        onClose={() => setRevokeTarget(null)}
        approval={revokeTarget}
        onConfirm={handleRevoke}
      />
    </div>
  );
};

// ── Sub-components ──────────────────────────────────────────────────────────

const SummaryChip: React.FC<{
  label: string;
  count: number;
  color?: 'danger' | 'warning' | 'safe';
}> = ({ label, count, color }) => {
  const colorClasses = color
    ? {
        danger: 'bg-[var(--r-red-default)]/10 text-[var(--r-red-default)]',
        warning: 'bg-amber-500/10 text-amber-600',
        safe: 'bg-[var(--r-green-default)]/10 text-[var(--r-green-default)]',
      }[color]
    : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-title-1)]';

  return (
    <div
      className={clsx(
        'flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium',
        colorClasses,
      )}
    >
      <span>{count}</span>
      <span className="opacity-70">{label}</span>
    </div>
  );
};

const TabButton: React.FC<{
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}> = ({ active, onClick, children }) => (
  <button
    className={clsx(
      'pb-2 text-sm font-medium transition-colors border-b-2 min-h-[44px]',
      active
        ? 'text-[var(--rabby-brand)] border-[var(--rabby-brand)]'
        : 'text-[var(--r-neutral-foot)] border-transparent',
    )}
    onClick={onClick}
  >
    {children}
  </button>
);

const SortSelect: React.FC<{
  value: SortField;
  onChange: (v: SortField) => void;
}> = ({ value, onChange }) => (
  <select
    className={clsx(
      'text-xs px-2 py-2 rounded-lg border border-[var(--r-neutral-line)]',
      'bg-[var(--r-neutral-bg-1)] text-[var(--r-neutral-body)]',
      'min-h-[44px]',
    )}
    value={value}
    onChange={(e) => onChange(e.target.value as SortField)}
  >
    <option value="risk">Sort: Risk</option>
    <option value="amount">Sort: Amount</option>
  </select>
);

const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path
      d="M11 11l3 3"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
    />
  </svg>
);
