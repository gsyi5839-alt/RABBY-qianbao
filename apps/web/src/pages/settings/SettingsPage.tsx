import React from 'react';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/layout';
import { usePreference } from '../../hooks';
import { useAccountStore } from '../../store';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface SettingItem {
  label: string;
  description?: string;
  icon: React.ReactNode;
  rightSlot?: React.ReactNode;
  onClick?: () => void;
}

interface SettingSection {
  title: string;
  items: SettingItem[];
}

// ---------------------------------------------------------------------------
// Main Settings Page
// ---------------------------------------------------------------------------
const SettingsPage: React.FC = () => {
  const navigate = useNavigate();
  const { theme, language, autoLockTime } = usePreference();
  const accounts = useAccountStore((s) => s.accounts);

  const autoLockLabel =
    autoLockTime === 0 ? 'Never' : `${autoLockTime} min`;

  const themeLabel =
    theme === 'light' ? 'Light' : theme === 'dark' ? 'Dark' : 'System';

  const langLabel = language === 'zh' ? 'Chinese' : 'English';

  const sections: SettingSection[] = [
    {
      title: 'Account',
      items: [
        {
          label: 'Address Management',
          description: `${accounts.length} addresses`,
          icon: <AddressIcon />,
          onClick: () => navigate('/settings/address'),
        },
        {
          label: 'Switch Address',
          icon: <SwitchIcon />,
          onClick: () => navigate('/switch-address'),
        },
      ],
    },
    {
      title: 'Security',
      items: [
        {
          label: 'Lock Wallet',
          icon: <LockIcon />,
          onClick: () => {
            useAccountStore.getState().lock();
            navigate('/unlock');
          },
        },
        {
          label: 'Auto-lock Timer',
          description: autoLockLabel,
          icon: <TimerIcon />,
          rightSlot: <ValueChip>{autoLockLabel}</ValueChip>,
          onClick: () => navigate('/settings/advanced'),
        },
      ],
    },
    {
      title: 'Network',
      items: [
        {
          label: 'Chain List',
          description: 'Manage supported chains',
          icon: <ChainListIcon />,
          onClick: () => navigate('/settings/chain-list'),
        },
        {
          label: 'Custom RPC',
          icon: <RPCIcon />,
          onClick: () => navigate('/custom-rpc'),
        },
      ],
    },
    {
      title: 'General',
      items: [
        {
          label: 'Language',
          icon: <LangIcon />,
          rightSlot: <ValueChip>{langLabel}</ValueChip>,
          onClick: () => navigate('/settings/switch-lang'),
        },
        {
          label: 'Theme',
          icon: <ThemeIcon />,
          rightSlot: <ValueChip>{themeLabel}</ValueChip>,
          onClick: () => navigate('/settings/advanced'),
        },
      ],
    },
    {
      title: 'About',
      items: [
        {
          label: 'Version',
          icon: <VersionIcon />,
          rightSlot: (
            <span className="text-sm text-[var(--r-neutral-foot)]">
              0.93.77
            </span>
          ),
        },
        {
          label: 'Connected Sites',
          icon: <SitesIcon />,
          onClick: () => navigate('/settings/sites'),
        },
        {
          label: 'Advanced',
          icon: <AdvancedIcon />,
          onClick: () => navigate('/settings/advanced'),
        },
      ],
    },
  ];

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Settings" />

      <div className="flex-1 overflow-y-auto px-4 pb-6">
        {sections.map((section) => (
          <div key={section.title} className="mb-5">
            <h3 className="text-xs font-semibold text-[var(--r-neutral-foot)] uppercase tracking-wide mb-2 px-1">
              {section.title}
            </h3>
            <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden divide-y divide-[var(--r-neutral-line)]">
              {section.items.map((item) => (
                <SettingRow key={item.label} item={item} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default SettingsPage;

// ---------------------------------------------------------------------------
// Setting Row
// ---------------------------------------------------------------------------
const SettingRow: React.FC<{ item: SettingItem }> = ({ item }) => (
  <button
    className="w-full flex items-center gap-3 px-4 py-3 min-h-[52px] text-left"
    onClick={item.onClick}
    disabled={!item.onClick}
  >
    <div className="w-8 h-8 rounded-lg bg-[var(--r-neutral-bg-2)] flex items-center justify-center flex-shrink-0 text-[var(--r-neutral-body)]">
      {item.icon}
    </div>
    <div className="flex-1 min-w-0">
      <div className="text-sm font-medium text-[var(--r-neutral-title-1)]">
        {item.label}
      </div>
      {item.description && (
        <div className="text-xs text-[var(--r-neutral-foot)] mt-0.5">
          {item.description}
        </div>
      )}
    </div>
    {item.rightSlot && <div className="flex-shrink-0">{item.rightSlot}</div>}
    {item.onClick && <ChevronRight />}
  </button>
);

const ValueChip: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <span className="text-sm text-[var(--r-neutral-body)]">{children}</span>
);

// ---------------------------------------------------------------------------
// Icons (inline SVGs, kept minimal)
// ---------------------------------------------------------------------------
const ChevronRight = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="text-[var(--r-neutral-foot)] flex-shrink-0">
    <path d="M6 4l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const AddressIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <rect x="3" y="4" width="12" height="10" rx="2" stroke="currentColor" strokeWidth="1.3" />
    <circle cx="9" cy="8" r="2" stroke="currentColor" strokeWidth="1.3" />
    <path d="M6 12c0-1.1.9-2 3-2s3 .9 3 2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);

const SwitchIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path d="M4 7l3-3 3 3M14 11l-3 3-3-3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M7 4v8M11 14V6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);

const LockIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <rect x="4" y="8" width="10" height="7" rx="2" stroke="currentColor" strokeWidth="1.3" />
    <path d="M6 8V6a3 3 0 016 0v2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    <circle cx="9" cy="12" r="1" fill="currentColor" />
  </svg>
);

const TimerIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="9" cy="10" r="6" stroke="currentColor" strokeWidth="1.3" />
    <path d="M9 7v3l2 1" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M7 2h4" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);

const ChainListIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="6" cy="6" r="3" stroke="currentColor" strokeWidth="1.3" />
    <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.3" />
    <path d="M8.5 8.5l1 1" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);

const RPCIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <rect x="3" y="4" width="12" height="4" rx="1" stroke="currentColor" strokeWidth="1.3" />
    <rect x="3" y="10" width="12" height="4" rx="1" stroke="currentColor" strokeWidth="1.3" />
    <circle cx="6" cy="6" r="0.8" fill="currentColor" />
    <circle cx="6" cy="12" r="0.8" fill="currentColor" />
  </svg>
);

const LangIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="9" cy="9" r="6" stroke="currentColor" strokeWidth="1.3" />
    <path d="M3 9h12M9 3c-2 2-2 4 0 6s2 4 0 6M9 3c2 2 2 4 0 6s-2 4 0 6" stroke="currentColor" strokeWidth="1.3" />
  </svg>
);

const ThemeIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path d="M9 3a6 6 0 100 12 5 5 0 010-12z" stroke="currentColor" strokeWidth="1.3" />
    <path d="M9 3v12" stroke="currentColor" strokeWidth="1.3" />
  </svg>
);

const VersionIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="9" cy="9" r="6" stroke="currentColor" strokeWidth="1.3" />
    <path d="M9 6v4M9 12v.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);

const SitesIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="9" cy="9" r="6" stroke="currentColor" strokeWidth="1.3" />
    <path d="M3 9h12" stroke="currentColor" strokeWidth="1.3" />
    <ellipse cx="9" cy="9" rx="3" ry="6" stroke="currentColor" strokeWidth="1.3" />
  </svg>
);

const AdvancedIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <circle cx="9" cy="9" r="2" stroke="currentColor" strokeWidth="1.3" />
    <path d="M9 3v2M9 13v2M3 9h2M13 9h2M5.1 5.1l1.4 1.4M11.5 11.5l1.4 1.4M5.1 12.9l1.4-1.4M11.5 6.5l1.4-1.4" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);
