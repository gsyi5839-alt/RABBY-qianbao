import React, { useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCurrentAccount } from '../../../hooks';
import { ellipsisAddress } from '../../../utils';
import { toast } from '../../../components/ui';

interface AccountHeaderProps {
  onSwitchAccount?: () => void;
}

const styles = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '0',
  } as React.CSSProperties,
  left: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    flex: 1,
    minWidth: 0,
  } as React.CSSProperties,
  avatar: {
    width: 40,
    height: 40,
    borderRadius: '50%',
    background: 'rgba(255,255,255,0.2)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  } as React.CSSProperties,
  avatarText: {
    color: '#fff',
    fontWeight: 700,
    fontSize: 16,
  } as React.CSSProperties,
  info: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
    minWidth: 0,
  } as React.CSSProperties,
  name: {
    color: '#fff',
    fontWeight: 600,
    fontSize: 16,
    lineHeight: '20px',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  } as React.CSSProperties,
  addressRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    cursor: 'pointer',
  } as React.CSSProperties,
  address: {
    color: 'rgba(255,255,255,0.6)',
    fontSize: 12,
    fontFamily: 'monospace',
    lineHeight: '16px',
  } as React.CSSProperties,
  copyIcon: {
    width: 14,
    height: 14,
    color: 'rgba(255,255,255,0.5)',
    flexShrink: 0,
  } as React.CSSProperties,
  actions: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    flexShrink: 0,
  } as React.CSSProperties,
  iconBtn: {
    width: 36,
    height: 36,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: '50%',
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    padding: 0,
  } as React.CSSProperties,
};

export const AccountHeader: React.FC<AccountHeaderProps> = ({
  onSwitchAccount,
}) => {
  const navigate = useNavigate();
  const { currentAccount } = useCurrentAccount();

  const displayName = currentAccount?.alianName || 'Account 1';
  const displayAddress = currentAccount?.address
    ? ellipsisAddress(currentAccount.address)
    : '0x0000...0000';
  const avatarLetter = displayName[0]?.toUpperCase() || 'A';

  const handleCopyAddress = useCallback(() => {
    if (!currentAccount?.address) return;
    navigator.clipboard.writeText(currentAccount.address).then(() => {
      toast.success('Address copied');
    }).catch(() => {
      toast.error('Failed to copy');
    });
  }, [currentAccount?.address]);

  const handleSwitchAccount = useCallback(() => {
    if (onSwitchAccount) {
      onSwitchAccount();
    } else {
      navigate('/switch-address');
    }
  }, [onSwitchAccount, navigate]);

  const handleReceive = useCallback(() => {
    navigate('/receive');
  }, [navigate]);

  return (
    <div style={styles.container}>
      <div style={styles.left}>
        <div
          style={styles.avatar}
          onClick={handleSwitchAccount}
          role="button"
          tabIndex={0}
        >
          <span style={styles.avatarText}>{avatarLetter}</span>
        </div>
        <div style={styles.info}>
          <div style={styles.name}>{displayName}</div>
          <div
            style={styles.addressRow}
            onClick={handleCopyAddress}
            role="button"
            tabIndex={0}
          >
            <span style={styles.address}>{displayAddress}</span>
            <svg
              style={styles.copyIcon}
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
              <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
            </svg>
          </div>
        </div>
      </div>

      <div style={styles.actions}>
        <button
          style={styles.iconBtn}
          onClick={handleReceive}
          title="Receive / QR"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="3" width="7" height="7" />
            <rect x="14" y="3" width="7" height="7" />
            <rect x="3" y="14" width="7" height="7" />
            <rect x="14" y="14" width="3" height="3" />
            <line x1="21" y1="14" x2="21" y2="17" />
            <line x1="14" y1="21" x2="17" y2="21" />
          </svg>
        </button>
        <button
          style={styles.iconBtn}
          onClick={() => navigate('/settings')}
          title="Settings"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z" />
          </svg>
        </button>
      </div>
    </div>
  );
};
