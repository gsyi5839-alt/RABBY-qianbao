import { useState, useCallback } from 'react';
import { useSettings } from '../../contexts/SettingsContext';

interface ToggleState {
  hideSmallBalances: boolean;
  customGasPrice: boolean;
  enableTestnet: boolean;
}

const AUTO_LOCK_OPTIONS = [
  { value: 1, label: '1 minute' },
  { value: 5, label: '5 minutes' },
  { value: 15, label: '15 minutes' },
  { value: 30, label: '30 minutes' },
  { value: 60, label: '1 hour' },
];

function ToggleSwitch({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: (val: boolean) => void;
}) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      style={{
        width: 44,
        height: 24,
        borderRadius: 12,
        border: 'none',
        background: checked
          ? 'var(--r-blue-default, #4c65ff)'
          : 'var(--r-neutral-line, #d3d8e0)',
        cursor: 'pointer',
        position: 'relative',
        transition: 'background 0.2s',
        flexShrink: 0,
        padding: 0,
      }}
    >
      <div
        style={{
          width: 20,
          height: 20,
          borderRadius: '50%',
          background: '#fff',
          position: 'absolute',
          top: 2,
          left: checked ? 22 : 2,
          transition: 'left 0.2s',
          boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
        }}
      />
    </button>
  );
}

function SettingsRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '14px 0',
      }}
    >
      <div style={{ flex: 1, minWidth: 0, marginRight: 16 }}>
        <div
          style={{
            fontSize: 14,
            fontWeight: 500,
            color: 'var(--r-neutral-title-1, #192945)',
          }}
        >
          {label}
        </div>
        {description && (
          <div
            style={{
              fontSize: 12,
              color: 'var(--r-neutral-foot, #6a7587)',
              marginTop: 2,
              lineHeight: 1.4,
            }}
          >
            {description}
          </div>
        )}
      </div>
      {children}
    </div>
  );
}

function SectionCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div
      style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: '4px 20px',
        marginBottom: 16,
      }}
    >
      <div
        style={{
          fontSize: 13,
          fontWeight: 600,
          color: 'var(--r-neutral-foot, #6a7587)',
          textTransform: 'uppercase',
          letterSpacing: '0.04em',
          padding: '16px 0 4px',
        }}
      >
        {title}
      </div>
      {children}
    </div>
  );
}

export default function AdvancedSettings() {
  const { autoLockMinutes, setAutoLockMinutes } = useSettings();

  const [toggles, setToggles] = useState<ToggleState>({
    hideSmallBalances: true,
    customGasPrice: false,
    enableTestnet: false,
  });

  const [showLockDropdown, setShowLockDropdown] = useState(false);

  const handleToggle = useCallback((key: keyof ToggleState) => {
    setToggles((prev) => ({ ...prev, [key]: !prev[key] }));
  }, []);

  const handleClearCache = useCallback(() => {
    if (window.confirm('Are you sure you want to clear the cache? This will not affect your accounts or keys.')) {
      try {
        const keysToKeep = ['rabby_web_settings', 'rabby_current_chain'];
        const saved: Record<string, string | null> = {};
        keysToKeep.forEach((k) => {
          saved[k] = localStorage.getItem(k);
        });
        localStorage.clear();
        keysToKeep.forEach((k) => {
          if (saved[k] !== null) {
            localStorage.setItem(k, saved[k]!);
          }
        });
        alert('Cache cleared successfully.');
      } catch {
        alert('Failed to clear cache.');
      }
    }
  }, []);

  const handleExportData = useCallback(() => {
    try {
      const data: Record<string, string | null> = {};
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key) data[key] = localStorage.getItem(key);
      }
      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: 'application/json',
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `rabby-data-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      alert('Failed to export data.');
    }
  }, []);

  return (
    <div style={{ maxWidth: 780, margin: '0 auto', padding: '0 20px' }}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <h2
          style={{
            margin: 0,
            fontSize: 24,
            fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
          }}
        >
          Advanced Settings
        </h2>
        <p
          style={{
            margin: '6px 0 0',
            fontSize: 14,
            color: 'var(--r-neutral-foot, #6a7587)',
          }}
        >
          Fine-tune your wallet experience
        </p>
      </div>

      {/* Privacy Section */}
      <SectionCard title="Privacy">
        <SettingsRow
          label="Hide small balances"
          description="Hide tokens with a value less than $1"
        >
          <ToggleSwitch
            checked={toggles.hideSmallBalances}
            onChange={() => handleToggle('hideSmallBalances')}
          />
        </SettingsRow>

        <div
          style={{
            borderTop: '1px solid var(--r-neutral-line, #e5e9ef)',
          }}
        />

        <SettingsRow
          label="Auto-lock timeout"
          description="Automatically lock the wallet after inactivity"
        >
          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setShowLockDropdown((v) => !v)}
              style={{
                padding: '6px 12px',
                background: 'var(--r-neutral-card-2, #f2f4f7)',
                border: '1px solid var(--r-neutral-line, #e5e9ef)',
                borderRadius: 8,
                fontSize: 13,
                color: 'var(--r-neutral-title-1, #192945)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                minWidth: 120,
                justifyContent: 'space-between',
              }}
            >
              <span>
                {AUTO_LOCK_OPTIONS.find((o) => o.value === autoLockMinutes)?.label ||
                  `${autoLockMinutes} min`}
              </span>
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path
                  d="M3 4.5l3 3 3-3"
                  stroke="currentColor"
                  strokeWidth="1.2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
            {showLockDropdown && (
              <>
                {/* Invisible overlay to close dropdown */}
                <div
                  style={{
                    position: 'fixed',
                    inset: 0,
                    zIndex: 999,
                  }}
                  onClick={() => setShowLockDropdown(false)}
                />
                <div
                  style={{
                    position: 'absolute',
                    top: '100%',
                    right: 0,
                    marginTop: 4,
                    background: 'var(--r-neutral-card-1, #fff)',
                    borderRadius: 8,
                    boxShadow: '0 4px 16px rgba(0,0,0,0.12)',
                    border: '1px solid var(--r-neutral-line, #e5e9ef)',
                    overflow: 'hidden',
                    zIndex: 1000,
                    minWidth: 140,
                  }}
                >
                  {AUTO_LOCK_OPTIONS.map((option) => (
                    <button
                      key={option.value}
                      onClick={() => {
                        setAutoLockMinutes(option.value);
                        setShowLockDropdown(false);
                      }}
                      style={{
                        display: 'block',
                        width: '100%',
                        padding: '10px 14px',
                        background:
                          autoLockMinutes === option.value
                            ? 'var(--r-blue-light-1, rgba(76,101,255,0.06))'
                            : 'transparent',
                        border: 'none',
                        cursor: 'pointer',
                        fontSize: 13,
                        color:
                          autoLockMinutes === option.value
                            ? 'var(--r-blue-default, #4c65ff)'
                            : 'var(--r-neutral-title-1, #192945)',
                        fontWeight: autoLockMinutes === option.value ? 500 : 400,
                        textAlign: 'left',
                        transition: 'background 0.15s',
                      }}
                      onMouseEnter={(e) => {
                        if (autoLockMinutes !== option.value) {
                          (e.currentTarget as HTMLElement).style.background =
                            'var(--r-neutral-card-2, #f7f8fa)';
                        }
                      }}
                      onMouseLeave={(e) => {
                        (e.currentTarget as HTMLElement).style.background =
                          autoLockMinutes === option.value
                            ? 'var(--r-blue-light-1, rgba(76,101,255,0.06))'
                            : 'transparent';
                      }}
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
        </SettingsRow>
      </SectionCard>

      {/* Developer Section */}
      <SectionCard title="Developer">
        <SettingsRow
          label="Custom gas price"
          description="Manually set gas price for transactions"
        >
          <ToggleSwitch
            checked={toggles.customGasPrice}
            onChange={() => handleToggle('customGasPrice')}
          />
        </SettingsRow>

        <div
          style={{
            borderTop: '1px solid var(--r-neutral-line, #e5e9ef)',
          }}
        />

        <SettingsRow
          label="Enable testnet"
          description="Show testnet chains in the chain selector"
        >
          <ToggleSwitch
            checked={toggles.enableTestnet}
            onChange={() => handleToggle('enableTestnet')}
          />
        </SettingsRow>
      </SectionCard>

      {/* Data Section */}
      <SectionCard title="Data">
        <SettingsRow
          label="Clear cache"
          description="Remove cached data without affecting your accounts"
        >
          <button
            onClick={handleClearCache}
            style={{
              padding: '8px 16px',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              border: 'none',
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
              cursor: 'pointer',
              transition: 'background 0.15s',
              flexShrink: 0,
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-line, #e5e9ef)';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-card-2, #f2f4f7)';
            }}
          >
            Clear Cache
          </button>
        </SettingsRow>

        <div
          style={{
            borderTop: '1px solid var(--r-neutral-line, #e5e9ef)',
          }}
        />

        <SettingsRow
          label="Export data"
          description="Download your settings and preferences as a JSON file"
        >
          <button
            onClick={handleExportData}
            style={{
              padding: '8px 16px',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              border: 'none',
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
              cursor: 'pointer',
              transition: 'background 0.15s',
              flexShrink: 0,
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-line, #e5e9ef)';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-card-2, #f2f4f7)';
            }}
          >
            Export Data
          </button>
        </SettingsRow>
      </SectionCard>

      {/* About Section */}
      <SectionCard title="About">
        <SettingsRow label="Version">
          <span
            style={{
              fontSize: 13,
              color: 'var(--r-neutral-foot, #6a7587)',
              fontFamily: "'SF Mono', 'Roboto Mono', monospace",
            }}
          >
            v0.93.77
          </span>
        </SettingsRow>

        <div
          style={{
            borderTop: '1px solid var(--r-neutral-line, #e5e9ef)',
          }}
        />

        <div
          style={{
            display: 'flex',
            gap: 10,
            padding: '14px 0 16px',
          }}
        >
          <a
            href="https://github.com/RabbyHub/Rabby"
            target="_blank"
            rel="noopener noreferrer"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              padding: '8px 16px',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
              textDecoration: 'none',
              transition: 'background 0.15s',
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-line, #e5e9ef)';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-card-2, #f2f4f7)';
            }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
              <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
            </svg>
            GitHub
          </a>
          <a
            href="https://discord.gg/rabby"
            target="_blank"
            rel="noopener noreferrer"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              padding: '8px 16px',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
              textDecoration: 'none',
              transition: 'background 0.15s',
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-line, #e5e9ef)';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.background =
                'var(--r-neutral-card-2, #f2f4f7)';
            }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
              <path d="M13.545 2.907a13.227 13.227 0 0 0-3.257-1.011.05.05 0 0 0-.052.025c-.141.25-.297.577-.406.833a12.19 12.19 0 0 0-3.658 0 8.258 8.258 0 0 0-.412-.833.051.051 0 0 0-.052-.025c-1.125.194-2.22.534-3.257 1.011a.046.046 0 0 0-.021.018C.356 6.024-.213 9.047.066 12.032c.001.014.01.028.021.037a13.276 13.276 0 0 0 3.995 2.02.05.05 0 0 0 .056-.019c.308-.42.582-.863.818-1.329a.05.05 0 0 0-.028-.07 8.748 8.748 0 0 1-1.248-.595.05.05 0 0 1-.005-.084c.084-.063.168-.129.248-.195a.049.049 0 0 1 .051-.007c2.619 1.196 5.454 1.196 8.041 0a.049.049 0 0 1 .053.007c.08.066.164.132.248.195a.05.05 0 0 1-.004.085c-.399.233-.813.44-1.249.594a.05.05 0 0 0-.03.07c.24.466.515.909.817 1.329a.05.05 0 0 0 .056.019 13.235 13.235 0 0 0 4.001-2.02.049.049 0 0 0 .021-.037c.334-3.451-.559-6.449-2.366-9.106a.034.034 0 0 0-.02-.019ZM5.347 10.12c-.79 0-1.44-.726-1.44-1.618 0-.892.637-1.618 1.44-1.618.807 0 1.451.733 1.44 1.618 0 .892-.637 1.618-1.44 1.618Zm5.316 0c-.79 0-1.44-.726-1.44-1.618 0-.892.637-1.618 1.44-1.618.807 0 1.451.733 1.44 1.618 0 .892-.633 1.618-1.44 1.618Z" />
            </svg>
            Discord
          </a>
        </div>
      </SectionCard>
    </div>
  );
}
