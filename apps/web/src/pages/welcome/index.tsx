import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWallet } from '../../contexts/WalletContext';

const STEPS = ['Welcome', 'Connect', 'Complete'] as const;

/* ---------- inline-style helpers ---------- */

const fullScreen: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'center',
  alignItems: 'center',
  minHeight: '100vh',
  background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff) 0%, #7084ff 50%, #a0b0ff 100%)',
  padding: 24,
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const card: React.CSSProperties = {
  width: 520,
  maxWidth: '100%',
  background: 'var(--r-neutral-card-1, #fff)',
  borderRadius: 16,
  padding: '48px 40px',
  boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
};

const stepIndicatorRow: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  marginBottom: 40,
  gap: 0,
};

const stepCircle = (active: boolean, done: boolean): React.CSSProperties => ({
  width: 32,
  height: 32,
  borderRadius: '50%',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  fontSize: 14,
  fontWeight: 600,
  flexShrink: 0,
  background: done
    ? 'var(--r-blue-default, #4c65ff)'
    : active
      ? 'var(--r-blue-default, #4c65ff)'
      : 'var(--r-neutral-bg-2, #f2f4f7)',
  color: done || active ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
  transition: 'background 0.25s, color 0.25s',
});

const stepLine = (done: boolean): React.CSSProperties => ({
  width: 64,
  height: 2,
  background: done ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-bg-2, #f2f4f7)',
  transition: 'background 0.25s',
});

const stepLabel: React.CSSProperties = {
  fontSize: 11,
  color: 'var(--r-neutral-foot, #6a7587)',
  textAlign: 'center' as const,
  marginTop: 6,
};

const primaryBtn: React.CSSProperties = {
  width: '100%',
  padding: '14px 0',
  borderRadius: 8,
  border: 'none',
  background: 'var(--r-blue-default, #4c65ff)',
  color: '#fff',
  fontSize: 16,
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'opacity 0.2s',
};

const secondaryBtn: React.CSSProperties = {
  width: '100%',
  padding: '14px 0',
  borderRadius: 8,
  border: '1.5px solid var(--r-blue-default, #4c65ff)',
  background: 'transparent',
  color: 'var(--r-blue-default, #4c65ff)',
  fontSize: 16,
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'opacity 0.2s',
};

const heading: React.CSSProperties = {
  fontSize: 28,
  fontWeight: 700,
  color: 'var(--r-neutral-title-1, #192945)',
  margin: 0,
  textAlign: 'center' as const,
};

const subText: React.CSSProperties = {
  fontSize: 15,
  color: 'var(--r-neutral-foot, #6a7587)',
  textAlign: 'center' as const,
  lineHeight: 1.6,
  margin: '12px 0 0',
};

/* ---------- SVG icons ---------- */

function RabbyLogo() {
  return (
    <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'linear-gradient(135deg, #7084ff 0%, var(--r-blue-default, #4c65ff) 100%)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px' }}>
      <svg width="44" height="44" viewBox="0 0 44 44" fill="none">
        <path d="M22 4C12.06 4 4 12.06 4 22s8.06 18 18 18 18-8.06 18-18S31.94 4 22 4zm0 30c-1.66 0-3-1.34-3-3h6c0 1.66-1.34 3-3 3zm9-5H13v-2l2-2v-5c0-3.07 1.63-5.64 4.5-6.32V13c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v.68C25.37 14.36 27 16.93 27 20v5l2 2v2z" fill="#fff" />
      </svg>
    </div>
  );
}

function CheckIcon() {
  return (
    <div style={{ width: 80, height: 80, borderRadius: '50%', background: '#22c55e', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px' }}>
      <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
        <path d="M16 28l-6-6 2.12-2.12L16 23.76l11.88-11.88L30 14z" fill="#fff" />
      </svg>
    </div>
  );
}

function WalletConnectIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
      <path d="M6.09 9.27a8.36 8.36 0 0 1 11.82 0l.39.39a.4.4 0 0 1 0 .58l-1.34 1.31a.21.21 0 0 1-.3 0l-.54-.53a5.83 5.83 0 0 0-8.24 0l-.58.57a.21.21 0 0 1-.3 0L5.66 10.3a.4.4 0 0 1 0-.58l.43-.45zm14.6 2.72 1.2 1.17a.4.4 0 0 1 0 .58l-5.38 5.28a.42.42 0 0 1-.59 0l-3.82-3.75a.1.1 0 0 0-.15 0l-3.82 3.75a.42.42 0 0 1-.59 0L2.16 13.74a.4.4 0 0 1 0-.58l1.2-1.17a.42.42 0 0 1 .59 0l3.82 3.75a.1.1 0 0 0 .15 0l3.82-3.75a.42.42 0 0 1 .59 0l3.82 3.75a.1.1 0 0 0 .15 0l3.82-3.75a.42.42 0 0 1 .59 0z" fill="var(--r-blue-default, #4c65ff)" />
    </svg>
  );
}

function DemoIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
      <rect x="3" y="6" width="18" height="13" rx="2" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.8" fill="none" />
      <circle cx="12" cy="12.5" r="2.5" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" fill="none" />
      <path d="M7 6V4.5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2V6" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.5" fill="none" />
    </svg>
  );
}

/* ---------- Step Indicators ---------- */

function StepIndicators({ current }: { current: number }) {
  return (
    <div>
      <div style={stepIndicatorRow}>
        {STEPS.map((label, i) => (
          <div key={label} style={{ display: 'flex', alignItems: 'center' }}>
            {i > 0 && <div style={stepLine(i <= current)} />}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={stepCircle(i === current, i < current)}>
                {i < current ? (
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                    <path d="M6.5 11.5L3 8l1-1 2.5 2.5 5-5 1 1z" fill="#fff" />
                  </svg>
                ) : (
                  i + 1
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0 16px', marginTop: -32, marginBottom: 32 }}>
        {STEPS.map((label) => (
          <span key={label} style={stepLabel}>{label}</span>
        ))}
      </div>
    </div>
  );
}

/* ---------- Step 0: Welcome Hero ---------- */

function WelcomeHero({ onGetStarted }: { onGetStarted: () => void }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <RabbyLogo />
      <h1 style={heading}>Welcome to Rabby</h1>
      <p style={subText}>
        The game-changing wallet for Ethereum and all EVM chains.
        <br />
        Multi-chain support, security engine, and seamless DApp experience.
      </p>
      <div style={{ marginTop: 36 }}>
        <button
          style={primaryBtn}
          onClick={onGetStarted}
          onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
          onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
        >
          Get Started
        </button>
      </div>
    </div>
  );
}

/* ---------- Step 1: Connect Options ---------- */

function ConnectOptions({ onConnected, onBack }: { onConnected: () => void; onBack: () => void }) {
  const { connect } = useWallet();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleConnect = useCallback(
    async (mode: 'demo' | 'walletconnect') => {
      setLoading(mode);
      setError(null);
      try {
        await connect(mode);
        onConnected();
      } catch (err: any) {
        setError(err?.message || 'Connection failed. Please try again.');
      } finally {
        setLoading(null);
      }
    },
    [connect, onConnected],
  );

  const optionCard = (hovered: boolean): React.CSSProperties => ({
    display: 'flex',
    alignItems: 'center',
    gap: 16,
    padding: '18px 20px',
    borderRadius: 12,
    border: '1.5px solid',
    borderColor: hovered ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-bg-2, #f2f4f7)',
    background: hovered ? 'rgba(76,101,255,0.04)' : 'var(--r-neutral-card-1, #fff)',
    cursor: 'pointer',
    transition: 'all 0.2s',
  });

  return (
    <div>
      <h2 style={{ ...heading, fontSize: 22 }}>Connect Your Wallet</h2>
      <p style={{ ...subText, marginBottom: 28 }}>Choose how you'd like to get started</p>

      <ConnectOptionCard
        icon={<DemoIcon />}
        title="Demo Mode"
        description="Explore Rabby with a demo wallet — no setup required"
        loading={loading === 'demo'}
        onClick={() => handleConnect('demo')}
        optionCardStyle={optionCard}
      />

      <div style={{ height: 12 }} />

      <ConnectOptionCard
        icon={<WalletConnectIcon />}
        title="WalletConnect"
        description="Connect MetaMask, Rainbow, or any WalletConnect wallet"
        loading={loading === 'walletconnect'}
        onClick={() => handleConnect('walletconnect')}
        optionCardStyle={optionCard}
      />

      {error && (
        <div
          style={{
            marginTop: 16,
            padding: '12px 16px',
            borderRadius: 8,
            background: '#fef2f2',
            color: '#dc2626',
            fontSize: 13,
          }}
        >
          {error}
        </div>
      )}

      <button
        style={{
          marginTop: 24,
          background: 'none',
          border: 'none',
          color: 'var(--r-neutral-foot, #6a7587)',
          fontSize: 14,
          cursor: 'pointer',
          width: '100%',
          textAlign: 'center' as const,
        }}
        onClick={onBack}
      >
        Back
      </button>
    </div>
  );
}

function ConnectOptionCard({
  icon,
  title,
  description,
  loading,
  onClick,
  optionCardStyle,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  loading: boolean;
  onClick: () => void;
  optionCardStyle: (hovered: boolean) => React.CSSProperties;
}) {
  const [hovered, setHovered] = useState(false);

  return (
    <div
      role="button"
      tabIndex={0}
      style={optionCardStyle(hovered)}
      onClick={loading ? undefined : onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onKeyDown={(e) => e.key === 'Enter' && !loading && onClick()}
    >
      <div
        style={{
          width: 44,
          height: 44,
          borderRadius: 10,
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {icon}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1, #192945)' }}>
          {title}
        </div>
        <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)', marginTop: 2 }}>
          {description}
        </div>
      </div>
      {loading && (
        <div
          style={{
            width: 20,
            height: 20,
            border: '2px solid var(--r-neutral-bg-2, #f2f4f7)',
            borderTop: '2px solid var(--r-blue-default, #4c65ff)',
            borderRadius: '50%',
            animation: 'spin 0.8s linear infinite',
          }}
        />
      )}
    </div>
  );
}

/* ---------- Step 2: Setup Complete ---------- */

function SetupComplete() {
  const navigate = useNavigate();

  return (
    <div style={{ textAlign: 'center' }}>
      <CheckIcon />
      <h2 style={heading}>You're All Set!</h2>
      <p style={subText}>
        Your wallet is connected. Start exploring DApps,
        <br />
        managing assets, and swapping tokens.
      </p>
      <div style={{ marginTop: 36, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <button
          style={primaryBtn}
          onClick={() => navigate('/')}
          onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
          onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
        >
          Go to Dashboard
        </button>
        <button
          style={secondaryBtn}
          onClick={() => navigate('/import')}
          onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
          onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
        >
          Import Another Wallet
        </button>
      </div>
    </div>
  );
}

/* ---------- Main Page ---------- */

export default function WelcomePage() {
  const [step, setStep] = useState(0);

  return (
    <>
      {/* keyframe for spinner */}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>

      <div style={fullScreen}>
        <div style={card}>
          <StepIndicators current={step} />

          {step === 0 && <WelcomeHero onGetStarted={() => setStep(1)} />}
          {step === 1 && (
            <ConnectOptions onConnected={() => setStep(2)} onBack={() => setStep(0)} />
          )}
          {step === 2 && <SetupComplete />}
        </div>
      </div>
    </>
  );
}
