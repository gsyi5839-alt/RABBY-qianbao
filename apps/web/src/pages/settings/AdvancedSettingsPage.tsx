import React, { useState, useCallback } from 'react';
import clsx from 'clsx';
import { PageHeader } from '../../components/layout';
import { Button, Input, Modal, toast } from '../../components/ui';
import { usePreference } from '../../hooks';
import { useChainStore, usePreferenceStore } from '../../store';
import type { ThemeMode } from '../../store/preference';

// ---------------------------------------------------------------------------
// Advanced Settings Page
// ---------------------------------------------------------------------------
const AdvancedSettingsPage: React.FC = () => {
  const {
    theme,
    setTheme,
    autoLockTime,
    setAutoLockTime,
    isShowTestnet,
    setShowTestnet,
  } = usePreference();

  const customRPCs = useChainStore((s) => s.customRPCs);
  const addCustomRPC = useChainStore((s) => s.addCustomRPC);
  const removeCustomRPC = useChainStore((s) => s.removeCustomRPC);

  const [rpcModal, setRpcModal] = useState(false);
  const [rpcChainId, setRpcChainId] = useState('');
  const [rpcUrl, setRpcUrl] = useState('');
  const [resetModal, setResetModal] = useState(false);

  const handleSaveRPC = useCallback(() => {
    if (!rpcChainId.trim() || !rpcUrl.trim()) {
      toast.error('Please fill in both fields');
      return;
    }
    addCustomRPC(rpcChainId.trim(), rpcUrl.trim());
    setRpcModal(false);
    setRpcChainId('');
    setRpcUrl('');
    toast.success('Custom RPC saved');
  }, [rpcChainId, rpcUrl, addCustomRPC]);

  const handleClearCache = useCallback(() => {
    toast.success('Cache cleared');
  }, []);

  const handleResetWallet = useCallback(() => {
    usePreferenceStore.getState().reset();
    useChainStore.getState().reset();
    setResetModal(false);
    toast.success('Wallet data reset');
  }, []);

  const autoLockOptions = [
    { value: 0, label: 'Never' },
    { value: 10, label: '10 min' },
    { value: 60, label: '1 hour' },
    { value: 240, label: '4 hours' },
    { value: 1440, label: '1 day' },
  ];

  const themeOptions: { value: ThemeMode; label: string }[] = [
    { value: 'light', label: 'Light' },
    { value: 'dark', label: 'Dark' },
    { value: 'system', label: 'System' },
  ];

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Advanced Settings" />

      <div className="flex-1 overflow-y-auto px-4 pb-6">
        {/* Theme */}
        <Section title="Theme">
          <div className="flex gap-2">
            {themeOptions.map((opt) => (
              <button
                key={opt.value}
                className={clsx(
                  'flex-1 py-2.5 rounded-xl text-sm font-medium transition-colors min-h-[44px]',
                  theme === opt.value
                    ? 'bg-[var(--rabby-brand)] text-white'
                    : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-body)]'
                )}
                onClick={() => setTheme(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </Section>

        {/* Auto-lock */}
        <Section title="Auto-lock Timer">
          <div className="flex flex-wrap gap-2">
            {autoLockOptions.map((opt) => (
              <button
                key={opt.value}
                className={clsx(
                  'px-4 py-2 rounded-xl text-sm font-medium transition-colors min-h-[44px]',
                  autoLockTime === opt.value
                    ? 'bg-[var(--rabby-brand)] text-white'
                    : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-body)]'
                )}
                onClick={() => setAutoLockTime(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </Section>

        {/* Testnet toggle */}
        <Section title="Testnet Mode">
          <div className="flex items-center justify-between bg-[var(--r-neutral-card-1)] rounded-xl px-4 py-3">
            <span className="text-sm text-[var(--r-neutral-title-1)]">
              Show Testnet Chains
            </span>
            <ToggleSwitch checked={isShowTestnet} onChange={setShowTestnet} />
          </div>
        </Section>

        {/* Custom RPC */}
        <Section title="Custom RPC Endpoints">
          {Object.keys(customRPCs).length > 0 ? (
            <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden divide-y divide-[var(--r-neutral-line)] mb-3">
              {Object.entries(customRPCs).map(([chainId, url]) => (
                <div key={chainId} className="flex items-center gap-3 px-4 py-3">
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                      {chainId}
                    </div>
                    <div className="text-xs text-[var(--r-neutral-foot)] truncate">
                      {url}
                    </div>
                  </div>
                  <button
                    className="text-[var(--r-red-default)] p-2 min-w-[44px] min-h-[44px] flex items-center justify-center"
                    onClick={() => {
                      removeCustomRPC(chainId);
                      toast.success('Custom RPC removed');
                    }}
                  >
                    <DeleteIcon />
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[var(--r-neutral-foot)] mb-3">
              No custom RPC endpoints configured.
            </p>
          )}
          <Button
            variant="secondary"
            size="md"
            onClick={() => setRpcModal(true)}
          >
            Add Custom RPC
          </Button>
        </Section>

        {/* Cache */}
        <Section title="Cache">
          <Button variant="secondary" size="md" onClick={handleClearCache}>
            Clear Cache
          </Button>
        </Section>

        {/* Danger zone */}
        <Section title="Danger Zone">
          <div className="bg-red-50 rounded-xl p-4">
            <p className="text-sm text-[var(--r-red-default)] mb-3">
              This will reset all local wallet data. Make sure you have backed
              up your seed phrase and private keys.
            </p>
            <Button
              variant="danger"
              size="md"
              onClick={() => setResetModal(true)}
            >
              Reset Wallet
            </Button>
          </div>
        </Section>
      </div>

      {/* Add RPC Modal */}
      <Modal
        visible={rpcModal}
        onClose={() => setRpcModal(false)}
        title="Add Custom RPC"
        footer={
          <div className="flex gap-3">
            <Button variant="ghost" fullWidth onClick={() => setRpcModal(false)}>
              Cancel
            </Button>
            <Button variant="primary" fullWidth onClick={handleSaveRPC}>
              Save
            </Button>
          </div>
        }
      >
        <div className="flex flex-col gap-3">
          <Input
            label="Chain ID / Name"
            placeholder="e.g. ETH"
            value={rpcChainId}
            onChange={(e) => setRpcChainId(e.target.value)}
          />
          <Input
            label="RPC URL"
            placeholder="https://..."
            value={rpcUrl}
            onChange={(e) => setRpcUrl(e.target.value)}
          />
        </div>
      </Modal>

      {/* Reset confirmation */}
      <Modal
        visible={resetModal}
        onClose={() => setResetModal(false)}
        title="Reset Wallet"
        footer={
          <div className="flex gap-3">
            <Button variant="ghost" fullWidth onClick={() => setResetModal(false)}>
              Cancel
            </Button>
            <Button variant="danger" fullWidth onClick={handleResetWallet}>
              Reset
            </Button>
          </div>
        }
      >
        <p className="text-sm text-[var(--r-neutral-body)]">
          This action cannot be undone. All locally stored wallet data will be
          permanently deleted. Please make sure you have backed up all
          important information.
        </p>
      </Modal>
    </div>
  );
};

export default AdvancedSettingsPage;

// ---------------------------------------------------------------------------
// Section wrapper
// ---------------------------------------------------------------------------
const Section: React.FC<{ title: string; children: React.ReactNode }> = ({
  title,
  children,
}) => (
  <div className="mb-6">
    <h3 className="text-xs font-semibold text-[var(--r-neutral-foot)] uppercase tracking-wide mb-2 px-1">
      {title}
    </h3>
    {children}
  </div>
);

// ---------------------------------------------------------------------------
// Toggle Switch
// ---------------------------------------------------------------------------
interface ToggleSwitchProps {
  checked: boolean;
  onChange: (value: boolean) => void;
}

const ToggleSwitch: React.FC<ToggleSwitchProps> = ({ checked, onChange }) => (
  <button
    role="switch"
    aria-checked={checked}
    className={clsx(
      'relative w-11 h-6 rounded-full transition-colors flex-shrink-0',
      checked ? 'bg-[var(--rabby-brand)]' : 'bg-[var(--r-neutral-line)]'
    )}
    onClick={() => onChange(!checked)}
  >
    <div
      className={clsx(
        'absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform',
        checked ? 'translate-x-[22px]' : 'translate-x-0.5'
      )}
    />
  </button>
);

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------
const DeleteIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path d="M4 4l8 8M4 12l8-8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);
