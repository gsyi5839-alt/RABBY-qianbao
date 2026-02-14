import React, { useState } from 'react';
import type { TokenApproval } from '@rabby/shared';
import { Popup, Button } from '../../../components/ui';
import { formatTokenAmount, ellipsisAddress } from '../../../utils';
import { RiskBadge } from './RiskBadge';

interface RevokeConfirmPopupProps {
  visible: boolean;
  onClose: () => void;
  approval: TokenApproval | null;
  onConfirm: (approval: TokenApproval) => Promise<void>;
}

/**
 * Confirmation popup shown before revoking a token approval.
 * Displays token + spender info, current approval amount, and a confirm button.
 */
export const RevokeConfirmPopup: React.FC<RevokeConfirmPopupProps> = ({
  visible,
  onClose,
  approval,
  onConfirm,
}) => {
  const [loading, setLoading] = useState(false);

  if (!approval) return null;

  const tokenSymbol =
    approval.token.display_symbol || approval.token.symbol;
  const spenderName =
    approval.spender.name || ellipsisAddress(approval.spender.id);

  const handleConfirm = async () => {
    setLoading(true);
    try {
      await onConfirm(approval);
      onClose();
    } catch {
      // error handled upstream
    } finally {
      setLoading(false);
    }
  };

  return (
    <Popup visible={visible} onClose={onClose} title="Revoke Approval" height="auto">
      <div className="flex flex-col gap-5 pb-2">
        {/* Token info */}
        <div className="flex items-center gap-3">
          <img
            src={approval.token.logo_url}
            alt={tokenSymbol}
            className="w-10 h-10 rounded-full flex-shrink-0"
          />
          <div>
            <p className="text-base font-medium text-[var(--r-neutral-title-1)]">
              {tokenSymbol}
            </p>
            <p className="text-xs text-[var(--r-neutral-foot)]">
              Balance: {formatTokenAmount(approval.token.amount)}
            </p>
          </div>
        </div>

        {/* Spender info */}
        <div className="flex flex-col gap-1.5 bg-[var(--r-neutral-bg-2)] rounded-xl p-3">
          <Row label="Spender">
            <div className="flex items-center gap-1.5">
              {approval.spender.logo_url && (
                <img
                  src={approval.spender.logo_url}
                  alt=""
                  className="w-4 h-4 rounded-full"
                />
              )}
              <span className="text-sm text-[var(--r-neutral-title-1)]">
                {spenderName}
              </span>
            </div>
          </Row>
          <Row label="Address">
            <span className="text-xs font-mono text-[var(--r-neutral-foot)]">
              {ellipsisAddress(approval.spender.id, 8, 6)}
            </span>
          </Row>
          <Row label="Risk Level">
            <RiskBadge level={approval.spender.risk_level || 'safe'} />
          </Row>
        </div>

        {/* Current approval amount */}
        <div className="flex items-center justify-between px-1">
          <span className="text-sm text-[var(--r-neutral-body)]">
            Current Approval
          </span>
          <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
            {approval.is_unlimited
              ? 'Unlimited'
              : formatTokenAmount(approval.amount)}{' '}
            {tokenSymbol}
          </span>
        </div>

        {/* Warning */}
        <div className="text-xs text-[var(--r-neutral-foot)] bg-amber-50 rounded-lg px-3 py-2">
          Revoking this approval will require a transaction on-chain. A gas fee
          will be charged.
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <Button variant="ghost" fullWidth onClick={onClose} disabled={loading}>
            Cancel
          </Button>
          <Button
            variant="danger"
            fullWidth
            loading={loading}
            onClick={handleConfirm}
          >
            Confirm Revoke
          </Button>
        </div>
      </div>
    </Popup>
  );
};

// ── Row helper ──────────────────────────────────────────────────────────────

const Row: React.FC<{ label: string; children: React.ReactNode }> = ({
  label,
  children,
}) => (
  <div className="flex items-center justify-between">
    <span className="text-xs text-[var(--r-neutral-foot)]">{label}</span>
    <div>{children}</div>
  </div>
);
