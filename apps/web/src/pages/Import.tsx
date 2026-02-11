import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

/* ---------- Types ---------- */

interface ImportOption {
  id: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  category: 'software' | 'hardware' | 'other';
}

/* ---------- SVG Icons ---------- */

function MnemonicIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <rect x="3" y="5" width="22" height="18" rx="3" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <line x1="7" y1="11" x2="21" y2="11" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="7" y1="15" x2="17" y2="15" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="7" y1="19" x2="13" y2="19" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function PrivateKeyIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <circle cx="11" cy="12" r="5" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <path d="M15 14l8 8M20 19l3 3M19 22l2-2" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function LedgerIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <rect x="8" y="3" width="12" height="22" rx="2" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <rect x="11" y="6" width="6" height="4" rx="1" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" fill="none" />
      <circle cx="14" cy="20" r="1.5" fill="var(--r-blue-default, #4c65ff)" />
    </svg>
  );
}

function TrezorIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <path d="M14 3L6 8v8l8 9 8-9V8z" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <circle cx="14" cy="13" r="3" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" fill="none" />
      <path d="M14 16v3" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function KeystoneIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <rect x="6" y="4" width="16" height="20" rx="3" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <rect x="9" y="7" width="10" height="7" rx="1.5" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" fill="none" />
      <circle cx="14" cy="19" r="1.5" fill="var(--r-blue-default, #4c65ff)" />
    </svg>
  );
}

function GridPlusIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <rect x="4" y="4" width="20" height="20" rx="4" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <line x1="4" y1="12" x2="24" y2="12" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" />
      <line x1="4" y1="18" x2="24" y2="18" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" />
      <line x1="12" y1="4" x2="12" y2="24" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" />
      <line x1="18" y1="4" x2="18" y2="24" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" />
    </svg>
  );
}

function WatchIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <circle cx="14" cy="14" r="9" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <circle cx="14" cy="14" r="3.5" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" fill="none" />
      <path d="M14 10.5V8M14 20v-2.5M17.5 14H20M8 14h2.5" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.2" strokeLinecap="round" />
    </svg>
  );
}

function WalletConnectIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <path d="M8.09 11.27a8.36 8.36 0 0 1 11.82 0l.39.39a.4.4 0 0 1 0 .58l-1.34 1.31a.21.21 0 0 1-.3 0l-.54-.53a5.83 5.83 0 0 0-8.24 0l-.58.57a.21.21 0 0 1-.3 0L7.66 12.3a.4.4 0 0 1 0-.58l.43-.45zm14.6 2.72 1.2 1.17a.4.4 0 0 1 0 .58l-5.38 5.28a.42.42 0 0 1-.59 0l-3.82-3.75a.1.1 0 0 0-.15 0l-3.82 3.75a.42.42 0 0 1-.59 0L4.16 15.74a.4.4 0 0 1 0-.58l1.2-1.17a.42.42 0 0 1 .59 0l3.82 3.75a.1.1 0 0 0 .15 0l3.82-3.75a.42.42 0 0 1 .59 0l3.82 3.75a.1.1 0 0 0 .15 0l3.82-3.75a.42.42 0 0 1 .59 0z" fill="var(--r-blue-default, #4c65ff)" />
    </svg>
  );
}

/* ---------- Import options data ---------- */

const IMPORT_OPTIONS: ImportOption[] = [
  {
    id: 'mnemonic',
    title: 'Mnemonic Phrase',
    description: 'Import using your 12 or 24 word recovery phrase',
    icon: <MnemonicIcon />,
    category: 'software',
  },
  {
    id: 'private-key',
    title: 'Private Key',
    description: 'Import with a private key string',
    icon: <PrivateKeyIcon />,
    category: 'software',
  },
  {
    id: 'ledger',
    title: 'Ledger',
    description: 'Connect your Ledger hardware wallet via USB',
    icon: <LedgerIcon />,
    category: 'hardware',
  },
  {
    id: 'trezor',
    title: 'Trezor',
    description: 'Connect your Trezor hardware wallet',
    icon: <TrezorIcon />,
    category: 'hardware',
  },
  {
    id: 'keystone',
    title: 'Keystone',
    description: 'Pair your Keystone wallet via QR code',
    icon: <KeystoneIcon />,
    category: 'hardware',
  },
  {
    id: 'gridplus',
    title: 'GridPlus',
    description: 'Connect your GridPlus Lattice1 device',
    icon: <GridPlusIcon />,
    category: 'hardware',
  },
  {
    id: 'watch',
    title: 'Watch Address',
    description: 'Monitor any address without signing capabilities',
    icon: <WatchIcon />,
    category: 'other',
  },
  {
    id: 'walletconnect',
    title: 'WalletConnect',
    description: 'Connect a mobile wallet via WalletConnect protocol',
    icon: <WalletConnectIcon />,
    category: 'other',
  },
];

/* ---------- Styles ---------- */

const pageContainer: React.CSSProperties = {
  minHeight: '100vh',
  background: 'var(--r-neutral-bg-2, #f2f4f7)',
  padding: '40px 24px',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const innerContainer: React.CSSProperties = {
  maxWidth: 860,
  margin: '0 auto',
};

const headerStyle: React.CSSProperties = {
  marginBottom: 32,
};

const backBtn: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  background: 'none',
  border: 'none',
  color: 'var(--r-neutral-foot, #6a7587)',
  fontSize: 14,
  cursor: 'pointer',
  padding: 0,
  marginBottom: 16,
};

const titleStyle: React.CSSProperties = {
  fontSize: 28,
  fontWeight: 700,
  color: 'var(--r-neutral-title-1, #192945)',
  margin: 0,
};

const subtitleStyle: React.CSSProperties = {
  fontSize: 15,
  color: 'var(--r-neutral-foot, #6a7587)',
  margin: '8px 0 0',
};

const sectionTitle: React.CSSProperties = {
  fontSize: 13,
  fontWeight: 600,
  color: 'var(--r-neutral-foot, #6a7587)',
  textTransform: 'uppercase' as const,
  letterSpacing: 0.8,
  margin: '0 0 12px',
};

const gridStyle: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
  gap: 16,
  marginBottom: 32,
};

/* ---------- Import Card ---------- */

function ImportCard({ option, onClick }: { option: ImportOption; onClick: () => void }) {
  const [hovered, setHovered] = useState(false);

  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    padding: '24px 20px',
    cursor: 'pointer',
    border: '1.5px solid',
    borderColor: hovered ? 'var(--r-blue-default, #4c65ff)' : 'transparent',
    boxShadow: hovered ? '0 4px 16px rgba(76,101,255,0.1)' : '0 2px 8px rgba(0,0,0,0.04)',
    transition: 'all 0.2s',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: 12,
  };

  return (
    <div
      role="button"
      tabIndex={0}
      style={cardStyle}
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onKeyDown={(e) => e.key === 'Enter' && onClick()}
    >
      <div
        style={{
          width: 48,
          height: 48,
          borderRadius: 12,
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {option.icon}
      </div>
      <div>
        <div
          style={{
            fontSize: 16,
            fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
          }}
        >
          {option.title}
        </div>
        <div
          style={{
            fontSize: 13,
            color: 'var(--r-neutral-foot, #6a7587)',
            marginTop: 4,
            lineHeight: 1.5,
          }}
        >
          {option.description}
        </div>
      </div>
    </div>
  );
}

/* ---------- Main Page ---------- */

export default function Import() {
  const navigate = useNavigate();

  const softwareOptions = IMPORT_OPTIONS.filter((o) => o.category === 'software');
  const hardwareOptions = IMPORT_OPTIONS.filter((o) => o.category === 'hardware');
  const otherOptions = IMPORT_OPTIONS.filter((o) => o.category === 'other');

  const handleOptionClick = (id: string) => {
    // Placeholder: each option would navigate to its own import flow
    console.log(`Import option selected: ${id}`);
  };

  return (
    <div style={pageContainer}>
      <div style={innerContainer}>
        <div style={headerStyle}>
          <button style={backBtn} onClick={() => navigate(-1)}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M10 12L6 8l4-4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Back
          </button>
          <h1 style={titleStyle}>Import Wallet</h1>
          <p style={subtitleStyle}>
            Choose a method to import or connect your existing wallet
          </p>
        </div>

        <div>
          <h3 style={sectionTitle}>Software Wallet</h3>
          <div style={gridStyle}>
            {softwareOptions.map((option) => (
              <ImportCard
                key={option.id}
                option={option}
                onClick={() => handleOptionClick(option.id)}
              />
            ))}
          </div>
        </div>

        <div>
          <h3 style={sectionTitle}>Hardware Wallet</h3>
          <div style={gridStyle}>
            {hardwareOptions.map((option) => (
              <ImportCard
                key={option.id}
                option={option}
                onClick={() => handleOptionClick(option.id)}
              />
            ))}
          </div>
        </div>

        <div>
          <h3 style={sectionTitle}>Other Methods</h3>
          <div style={gridStyle}>
            {otherOptions.map((option) => (
              <ImportCard
                key={option.id}
                option={option}
                onClick={() => handleOptionClick(option.id)}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
