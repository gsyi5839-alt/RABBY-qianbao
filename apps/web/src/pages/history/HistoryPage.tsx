import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { useSearchParams } from 'react-router-dom';
import { PageHeader } from '../../components/layout';
import { Loading, Empty } from '../../components/ui';
import { useCurrentAccount, useChain } from '../../hooks';
import { historyApi } from '../../services/api';
import type {
  TxHistoryItem,
  TxHistoryResult,
} from '../../services/api/history';
import type { TokenItem } from '../../services/api/balance';
import { formatTime } from '../../utils';
import { TransactionItem } from './components/TransactionItem';
import { TransactionDetail } from './components/TransactionDetail';
import { DateGroup } from './components/DateGroup';

const PAGE_COUNT = 10;

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Group transactions by date label. */
function groupByDate(
  list: TxHistoryItem[],
): Array<{ label: string; items: TxHistoryItem[] }> {
  const groups: Map<string, TxHistoryItem[]> = new Map();
  const now = new Date();
  const todayKey = dateKey(now);
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayKey = dateKey(yesterday);

  for (const item of list) {
    const d = new Date(item.time_at * 1000);
    const key = dateKey(d);
    let label: string;
    if (key === todayKey) label = 'Today';
    else if (key === yesterdayKey) label = 'Yesterday';
    else label = formatTime(item.time_at, 'YYYY-MM-DD');

    if (!groups.has(label)) groups.set(label, []);
    groups.get(label)!.push(item);
  }
  return Array.from(groups.entries()).map(([label, items]) => ({
    label,
    items,
  }));
}

function dateKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

// ── Component ────────────────────────────────────────────────────────────────

interface HistoryPageProps {
  isFilterScam?: boolean;
}

export const HistoryPage: React.FC<HistoryPageProps> = ({
  isFilterScam = false,
}) => {
  const { address } = useCurrentAccount();
  const { chainList } = useChain();

  const [searchParams] = useSearchParams();
  const chainFilter = searchParams.get('chain') || '';

  const [txList, setTxList] = useState<TxHistoryItem[]>([]);
  const [tokenDict, setTokenDict] = useState<Record<string, TokenItem>>({});
  const [cateDict, setCateDict] =
    useState<Record<string, { id: string; name: string }>>({});
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Detail popup
  const [detailItem, setDetailItem] = useState<TxHistoryItem | null>(null);

  const listRef = useRef<HTMLDivElement>(null);

  // ── Fetch ────────────────────────────────────────────────────────────────

  const fetchHistory = useCallback(
    async (startTime?: number) => {
      if (!address) return null;
      const isInitial = !startTime;
      if (isInitial) setLoading(true);
      else setLoadingMore(true);

      try {
        const res = isFilterScam
          ? await historyApi.getAllTxHistory(address, startTime, PAGE_COUNT)
          : await historyApi.getTxHistory(
              address,
              chainFilter || undefined,
              startTime,
              PAGE_COUNT,
            );

        const dict =
          (res as TxHistoryResult).token_dict ||
          (res as any).token_uuid_dict ||
          {};
        let list = res.history_list || [];

        if (isFilterScam) {
          list = list.filter((item) => !item.is_scam);
        }

        list.sort((a, b) => b.time_at - a.time_at);

        return { list, dict, cateDict: res.cate_dict };
      } catch (err) {
        console.error('[HistoryPage] fetch error:', err);
        return null;
      } finally {
        if (isInitial) setLoading(false);
        else setLoadingMore(false);
      }
    },
    [address, chainFilter, isFilterScam],
  );

  // Initial load
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const res = await fetchHistory();
      if (cancelled || !res) return;
      setTxList(res.list);
      setTokenDict(res.dict);
      if (res.cateDict) setCateDict(res.cateDict);
      setHasMore(
        !isFilterScam && res.list.length >= PAGE_COUNT,
      );
    })();
    return () => {
      cancelled = true;
    };
  }, [fetchHistory, isFilterScam]);

  // ── Load more ────────────────────────────────────────────────────────────

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore || txList.length === 0) return;
    const last = txList[txList.length - 1];
    const res = await fetchHistory(last.time_at);
    if (!res) return;
    setTxList((prev) => [...prev, ...res.list]);
    setTokenDict((prev) => ({ ...prev, ...res.dict }));
    if (res.cateDict) setCateDict((prev) => ({ ...prev, ...res.cateDict }));
    setHasMore(
      !isFilterScam && res.list.length >= PAGE_COUNT,
    );
  }, [loadingMore, hasMore, txList, fetchHistory, isFilterScam]);

  // ── Infinite scroll ──────────────────────────────────────────────────────

  useEffect(() => {
    const el = listRef.current;
    if (!el) return;

    const handleScroll = () => {
      if (el.scrollTop + el.clientHeight >= el.scrollHeight - 100) {
        loadMore();
      }
    };
    el.addEventListener('scroll', handleScroll, { passive: true });
    return () => el.removeEventListener('scroll', handleScroll);
  }, [loadMore]);

  // ── Pull-to-refresh ──────────────────────────────────────────────────────

  const refresh = useCallback(async () => {
    setRefreshing(true);
    const res = await fetchHistory();
    if (res) {
      setTxList(res.list);
      setTokenDict(res.dict);
      if (res.cateDict) setCateDict(res.cateDict);
      setHasMore(!isFilterScam && res.list.length >= PAGE_COUNT);
    }
    setRefreshing(false);
  }, [fetchHistory, isFilterScam]);

  // ── Grouped data ─────────────────────────────────────────────────────────

  const grouped = useMemo(() => groupByDate(txList), [txList]);
  const isEmpty = txList.length === 0 && !loading;

  // ── Chain filter display ─────────────────────────────────────────────────

  const chainName = useMemo(() => {
    if (!chainFilter) return 'All Chains';
    const c = chainList.find(
      (ch) => ch.serverId === chainFilter || ch.enum === chainFilter,
    );
    return c?.name || chainFilter;
  }, [chainFilter, chainList]);

  return (
    <div className="flex flex-col h-screen bg-[var(--r-neutral-bg-1)]">
      <PageHeader
        title={isFilterScam ? 'Filtered Transactions' : 'Transactions'}
        rightSlot={
          !isFilterScam ? (
            <span className="text-xs text-[var(--r-neutral-foot)] pr-1">
              {chainName}
            </span>
          ) : undefined
        }
      />

      {/* Refresh indicator */}
      {refreshing && (
        <div className="flex justify-center py-2">
          <Loading size="sm" />
        </div>
      )}

      {/* Loading skeleton */}
      {loading && (
        <div className="flex-1 flex items-center justify-center">
          <Loading size="lg" />
        </div>
      )}

      {/* Empty state */}
      {isEmpty && (
        <div className="flex-1">
          <Empty
            description="No transactions found"
            action={
              <button
                className="text-sm text-[var(--rabby-brand)] mt-2 min-w-[44px] min-h-[44px]"
                onClick={refresh}
              >
                Refresh
              </button>
            }
          />
        </div>
      )}

      {/* Transaction list */}
      {!loading && !isEmpty && (
        <div ref={listRef} className="flex-1 overflow-y-auto">
          {/* Pull to refresh zone */}
          <button
            className="w-full py-2 text-center text-xs text-[var(--rabby-brand)] min-h-[44px]"
            onClick={refresh}
          >
            Pull to refresh
          </button>

          {grouped.map((group) => (
            <DateGroup key={group.label} label={group.label}>
              {group.items.map((item) => (
                <TransactionItem
                  key={item.id}
                  item={item}
                  tokenDict={tokenDict}
                  cateDict={cateDict}
                  onClick={setDetailItem}
                />
              ))}
            </DateGroup>
          ))}

          {/* Load more indicator */}
          {loadingMore && (
            <div className="flex justify-center py-4">
              <Loading size="sm" />
            </div>
          )}

          {!hasMore && txList.length > 0 && (
            <p className="text-center text-xs text-[var(--r-neutral-foot)] py-4">
              No more transactions
            </p>
          )}
        </div>
      )}

      {/* Transaction Detail popup */}
      <TransactionDetail
        visible={!!detailItem}
        onClose={() => setDetailItem(null)}
        item={detailItem}
        tokenDict={tokenDict}
      />
    </div>
  );
};
