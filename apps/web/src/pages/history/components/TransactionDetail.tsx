import React, { useMemo, useCallback } from 'react';
import type { TxHistoryItem } from '../../../services/api/history';
import type { TokenItem } from '../../../services/api/balance';
import { Popup } from '../../../components/ui';
import { AddressViewer } from '../../../components/address';
import {
  formatTokenAmount,
  formatUsdValue,
  formatTime,
} from '../../../utils';
import { useChain } from '../../../hooks';

// ── Status helpers ──────────────────────────────────────────────────────────

function statusLabel(status: number | undefined): string {
  if (status === undefined || status === null) return 'Unknown';
  return status === 1 ? 'Success' : 'Failed';
}

function statusColor(status: number | undefined): string {
  if (status === 1)
    return 'text-[var(--r-green-default)] bg-[var(--r-green-default)]/10';
  if (status === 0)
    return 'text-[var(--r-red-default)] bg-[var(--r-red-default)]/10';
  return 'text-[var(--r-neutral-foot)] bg-[var(--r-neutral-bg-2)]';
}

// ── Copy helper ─────────────────────────────────────────────────────────────

async function copyToClipboard(text: string) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const el = document.createElement('textarea');
    el.value = text;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
  }
}

// ── Props ────────────────────────────────────────────────────────────────────

interface TransactionDetailProps {
  visible: boolean;
  onClose: () => void;
  item: TxHistoryItem | null;
  tokenDict: Record<string, TokenItem>;
}

/**
 * Popup showing full details for a single transaction.
 */
export const TransactionDetail: React.FC<TransactionDetailProps> = ({
  visible,
  onClose,
  item,
  tokenDict,
}) => {
  const { findChainByServerId } = useChain();

  const chainInfo = useMemo(
    () => (item ? findChainByServerId(item.chain) : undefined),
    [item, findChainByServerId],
  );

  const explorerUrl = useMemo(() => {
    if (!chainInfo?.scanLink || !item) return null;
    return `${chainInfo.scanLink}/tx/${item.id}`;
  }, [chainInfo, item]);

  const handleCopyHash = useCallback(() => {
    if (item) copyToClipboard(item.id);
  }, [item]);

  if (!item) return null;

  return (
    <Popup visible={visible} onClose={onClose} title="Transaction Details">
      <div className="flex flex-col gap-4">
        {/* Tx Hash */}
        <Row label="Tx Hash">
          <div className="flex items-center gap-2">
            <AddressViewer
              address={item.id}
              ellipsis
              longEllipsis
              showCopy={false}
            />
            <button
              className="text-xs text-[var(--rabby-brand)] min-w-[44px] min-h-[44px] flex items-center justify-center -m-3"
              onClick={handleCopyHash}
            >
              Copy
            </button>
            {explorerUrl && (
              <a
                href={explorerUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-[var(--rabby-brand)] underline min-w-[44px] min-h-[44px] flex items-center justify-center -m-3"
              >
                Explorer
              </a>
            )}
          </div>
        </Row>

        {/* Status */}
        <Row label="Status">
          <span
            className={`text-xs px-2 py-0.5 rounded-md font-medium ${statusColor(item.tx?.status)}`}
          >
            {statusLabel(item.tx?.status)}
          </span>
        </Row>

        {/* Chain */}
        <Row label="Chain">
          <span className="text-sm text-[var(--r-neutral-title-1)]">
            {chainInfo?.name || item.chain}
          </span>
        </Row>

        {/* Time */}
        <Row label="Time">
          <span className="text-sm text-[var(--r-neutral-title-1)]">
            {formatTime(item.time_at, 'YYYY-MM-DD HH:mm:ss')}
          </span>
        </Row>

        {/* From */}
        {item.tx?.from_addr && (
          <Row label="From">
            <AddressViewer address={item.tx.from_addr} longEllipsis />
          </Row>
        )}

        {/* To */}
        {item.tx?.to_addr && (
          <Row label="To">
            <AddressViewer address={item.tx.to_addr} longEllipsis />
          </Row>
        )}

        {/* Token Transfers */}
        {(item.sends.length > 0 || item.receives.length > 0) && (
          <div>
            <p className="text-xs font-medium text-[var(--r-neutral-foot)] mb-2">
              Token Transfers
            </p>
            <div className="flex flex-col gap-1.5">
              {item.sends.map((s, i) => {
                const tok = tokenDict[s.token_id];
                return (
                  <div
                    key={`s-${i}`}
                    className="flex items-center justify-between text-sm"
                  >
                    <span className="text-[var(--r-red-default)]">
                      - {formatTokenAmount(s.amount)} {tok?.symbol || '?'}
                    </span>
                    {tok?.price ? (
                      <span className="text-xs text-[var(--r-neutral-foot)]">
                        {formatUsdValue(s.amount * tok.price)}
                      </span>
                    ) : null}
                  </div>
                );
              })}
              {item.receives.map((r, i) => {
                const tok = tokenDict[r.token_id];
                return (
                  <div
                    key={`r-${i}`}
                    className="flex items-center justify-between text-sm"
                  >
                    <span className="text-[var(--r-green-default)]">
                      + {formatTokenAmount(r.amount)} {tok?.symbol || '?'}
                    </span>
                    {tok?.price ? (
                      <span className="text-xs text-[var(--r-neutral-foot)]">
                        {formatUsdValue(r.amount * tok.price)}
                      </span>
                    ) : null}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Gas */}
        {item.tx?.eth_gas_fee != null && (
          <Row label="Gas Fee">
            <span className="text-sm text-[var(--r-neutral-title-1)]">
              {formatTokenAmount(item.tx.eth_gas_fee)}{' '}
              {chainInfo?.nativeTokenSymbol || 'ETH'}{' '}
              <span className="text-xs text-[var(--r-neutral-foot)]">
                ({formatUsdValue(item.tx.usd_gas_fee)})
              </span>
            </span>
          </Row>
        )}
      </div>
    </Popup>
  );
};

// ── Row helper ──────────────────────────────────────────────────────────────

const Row: React.FC<{ label: string; children: React.ReactNode }> = ({
  label,
  children,
}) => (
  <div className="flex items-start justify-between gap-3">
    <span className="text-xs text-[var(--r-neutral-foot)] flex-shrink-0 pt-0.5 min-w-[72px]">
      {label}
    </span>
    <div className="flex-1 text-right">{children}</div>
  </div>
);
