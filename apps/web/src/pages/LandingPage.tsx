// @ts-nocheck
import React, { useState, useRef, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { translations } from '../i18n/translations';
import { LanguageSwitcher } from '../components/LanguageSwitcher';

/* ── Landing assets ── */
import LogoLarge from '../assets/landing/logo-rabby-large.svg';
import LogoWhite from '../assets/landing/rabby-white-large.svg';
import HeroPreview from '../assets/landing/home-preview.png';
import WelcomeImg from '../assets/landing/welcome.png';
import AppStoreSvg from '../assets/landing/app-store.svg';
import DiscordSvg from '../assets/landing/discord.svg';
import TwitterSvg from '../assets/landing/twitter.svg';
import TelegramSvg from '../assets/landing/telegram.svg';
import DebankSvg from '../assets/landing/debank.svg';

/* ── Feature icons ── */
import IconSwap from '../assets/dashboard/panel/swap-cc.svg';
import IconSend from '../assets/dashboard/panel/send-cc.svg';
import IconBridge from '../assets/dashboard/panel/bridge-cc.svg';
import IconReceive from '../assets/dashboard/panel/receive-cc.svg';
import IconNFT from '../assets/dashboard/panel/nft-cc.svg';
import IconSecurity from '../assets/dashboard/panel/approvals-cc.svg';
import IconDApps from '../assets/dashboard/panel/dapps-cc.svg';
import IconHistory from '../assets/dashboard/panel/transactions-cc.svg';

/* ── Wallet logos ── */
import WalletLedger from '../assets/walletlogo/ledger.svg';
import WalletTrezor from '../assets/walletlogo/trezor.svg';
import WalletMetamask from '../assets/walletlogo/metamask.svg';
import WalletWC from '../assets/walletlogo/walletconnect.svg';
import WalletSafe from '../assets/walletlogo/safe.svg';
import WalletCoinbase from '../assets/walletlogo/coinbase.svg';
import WalletTrust from '../assets/walletlogo/trust.svg';
import WalletOneKey from '../assets/walletlogo/onekey.svg';
import WalletKeystone from '../assets/walletlogo/keystone.svg';

/* ── Chain icons (local) ── */
import ChainEth from '../assets/chains/eth.png';
import ChainBtc from '../assets/chains/btc.png';
import ChainDoge from '../assets/chains/doge.png';
import ChainTrx from '../assets/chains/trx.png';
import ChainTon from '../assets/chains/ton.png';
import ChainOp from '../assets/chains/op.png';
import ChainArb from '../assets/chains/arb.png';
import ChainZks from '../assets/chains/zks.png';
import ChainBase from '../assets/chains/base.png';
import ChainBnb from '../assets/chains/bnb.png';
import ChainPol from '../assets/chains/pol.png';
import ChainAvax from '../assets/chains/avax.png';
import ChainOkt from '../assets/chains/okt.svg';

/* ── Dropdown Menu Component ── */
interface NavDropdownProps {
  label: string;
  itemsKey: 'product' | 'resources';
  translations: typeof translations.en;
  className?: string;
}

function NavDropdown({ label, itemsKey, translations: t, className }: NavDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const items = itemsKey === 'product'
    ? [
        { label: t.dropdown.product.iosApp, href: '#download', description: t.dropdown.product.iosAppDesc },
        { label: t.dropdown.product.chromeExtension, href: '#download', description: t.dropdown.product.chromeExtensionDesc },
        { label: t.dropdown.product.features, href: '#features' },
        { label: t.dropdown.product.security, href: '#security' },
      ]
    : [
        { label: t.dropdown.resources.documentation, href: '#', description: t.dropdown.resources.documentationDesc },
        { label: t.dropdown.resources.blog, href: '#' },
        { label: t.dropdown.resources.support, href: '#' },
        { label: t.dropdown.resources.faq, href: '#' },
      ];

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div
      className={className}
      ref={dropdownRef}
      style={{ position: 'relative' }}
      onMouseEnter={() => setIsOpen(true)}
      onMouseLeave={() => setIsOpen(false)}
    >
      <button
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          fontSize: 15,
          fontWeight: 500,
          color: '#3e495e',
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '8px 0',
          transition: 'color 0.2s',
        }}
      >
        {label}
        <svg
          width={12}
          height={12}
          viewBox="0 0 24 24"
          fill="none"
          style={{
            transition: 'transform 0.2s',
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
          }}
        >
          <path
            d="M6 9l6 6 6-6"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            left: -16,
            minWidth: 200,
            padding: '8px 0',
            background: '#fff',
            borderRadius: 12,
            boxShadow: '0 8px 24px rgba(0, 0, 0, 0.12)',
            border: '1px solid #e0e5ec',
            zIndex: 1000,
          }}
        >
          {items.map((item, idx) => (
            <a
              key={idx}
              href={item.href}
              style={{
                display: 'block',
                padding: item.description ? '10px 20px' : '12px 20px',
                color: '#3e495e',
                fontSize: 14,
                textDecoration: 'none',
                transition: 'background 0.15s, color 0.15s',
              }}
              onMouseEnter={(e) => {
                (e.currentTarget as HTMLAnchorElement).style.background = '#f7f8fc';
                (e.currentTarget as HTMLAnchorElement).style.color = '#4c65ff';
              }}
              onMouseLeave={(e) => {
                (e.currentTarget as HTMLAnchorElement).style.background = 'transparent';
                (e.currentTarget as HTMLAnchorElement).style.color = '#3e495e';
              }}
            >
              {item.description ? (
                <div>
                  <div style={{ fontWeight: 500, marginBottom: 2 }}>{item.label}</div>
                  <div style={{ fontSize: 12, color: '#6a7587' }}>{item.description}</div>
                </div>
              ) : (
                item.label
              )}
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

/* ── Feature Dropdown (nav) ── */
interface FeatureDropdownProps {
  label: string;
  translations: typeof translations.en;
  className?: string;
}

function FeatureDropdown({ label, translations: t, className }: FeatureDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const items = [
    {
      key: 'multiChainWallet',
      title: t.featuresMenu.multiChainWallet.title,
      desc: t.featuresMenu.multiChainWallet.desc,
      href: '#chains',
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <rect x="3" y="7" width="18" height="12" rx="3" stroke="#4c65ff" strokeWidth="1.6" />
          <path d="M16 13.5a1.5 1.5 0 1 0 0-3" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      ),
    },
    {
      key: 'hardwareWallet',
      title: t.featuresMenu.hardwareWallet.title,
      desc: t.featuresMenu.hardwareWallet.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <rect x="7" y="3" width="10" height="18" rx="2" stroke="#4c65ff" strokeWidth="1.6" />
          <circle cx="12" cy="16" r="1.6" fill="#4c65ff" />
        </svg>
      ),
    },
    {
      key: 'dappBrowser',
      title: t.featuresMenu.dappBrowser.title,
      desc: t.featuresMenu.dappBrowser.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="8" stroke="#4c65ff" strokeWidth="1.6" />
          <path d="M4 12h16M12 4c2.5 3.2 2.5 12.8 0 16M8 6.5c1.4 1.4 1.4 9.6 0 11" stroke="#4c65ff" strokeWidth="1.4" strokeLinecap="round" />
        </svg>
      ),
    },
    {
      key: 'card',
      title: t.featuresMenu.card.title,
      desc: t.featuresMenu.card.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <rect x="3" y="6" width="18" height="12" rx="2" stroke="#4c65ff" strokeWidth="1.6" />
          <path d="M5 10h14M8 14h4" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      ),
    },
  ];

  return (
    <div
      className={className}
      ref={dropdownRef}
      style={{ position: 'relative' }}
      onMouseEnter={() => setIsOpen(true)}
      onMouseLeave={() => setIsOpen(false)}
    >
      <button
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          fontSize: 15,
          fontWeight: 500,
          color: '#3e495e',
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '8px 0',
          transition: 'color 0.2s',
        }}
      >
        {label}
        <svg
          width={12}
          height={12}
          viewBox="0 0 24 24"
          fill="none"
          style={{
            transition: 'transform 0.2s',
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
          }}
        >
          <path
            d="M6 9l6 6 6-6"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            left: -24,
            minWidth: 260,
            padding: '12px 0',
            background: '#fff',
            borderRadius: 14,
            boxShadow: '0 12px 28px rgba(0, 0, 0, 0.12)',
            border: '1px solid #e5e8ef',
            zIndex: 1200,
          }}
        >
          {items.map((item, idx) => {
            const isExternal = item.href?.startsWith('http');
            return (
              <a
                key={item.key}
                href={item.href}
                target={isExternal ? '_blank' : undefined}
                rel={isExternal ? 'noreferrer' : undefined}
                onClick={() => setIsOpen(false)}
                style={{
                  display: 'flex',
                  gap: 12,
                  padding: '12px 18px',
                  alignItems: 'flex-start',
                  borderBottom: idx !== items.length - 1 ? '1px solid #f0f2f7' : 'none',
                  transition: 'background 0.15s, color 0.15s',
                  textDecoration: 'none',
                  color: '#1f2a44',
                }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLAnchorElement).style.background = '#f7f8fc';
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLAnchorElement).style.background = 'transparent';
                }}
              >
                <div style={{ width: 26, height: 26, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {item.icon}
                </div>
                <div>
                  <div style={{ fontSize: 15, fontWeight: 600, color: '#1f2a44', marginBottom: 4 }}>{item.title}</div>
                  <div style={{ fontSize: 13, color: '#6a7587', lineHeight: 1.5 }}>{item.desc}</div>
                </div>
              </a>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ── Multi-chain Dropdown (nav) ── */
interface MultiChainDropdownProps {
  label: string;
  translations: typeof translations.en;
  className?: string;
  linkTo?: string;
}

function MultiChainDropdown({ label, translations: t, className, linkTo }: MultiChainDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const items = [
    {
      key: 'public',
      title: t.multiChainMenu.public.title,
      desc: t.multiChainMenu.public.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <path d="M12 3l7 4v7l-7 4-7-4V7l7-4z" stroke="#4c65ff" strokeWidth="1.6" strokeLinejoin="round" />
          <path d="M12 3v7l7 4" stroke="#4c65ff" strokeWidth="1.6" strokeLinejoin="round" />
        </svg>
      ),
    },
    {
      key: 'layer2',
      title: t.multiChainMenu.layer2.title,
      desc: t.multiChainMenu.layer2.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <rect x="4" y="6" width="16" height="12" rx="2" stroke="#4c65ff" strokeWidth="1.6" />
          <path d="M8 10h8M8 14h5" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      ),
    },
    {
      key: 'evm',
      title: t.multiChainMenu.evm.title,
      desc: t.multiChainMenu.evm.desc,
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <rect x="5" y="5" width="6" height="6" rx="1.2" stroke="#4c65ff" strokeWidth="1.6" />
          <rect x="13" y="5" width="6" height="6" rx="1.2" stroke="#4c65ff" strokeWidth="1.6" />
          <rect x="5" y="13" width="6" height="6" rx="1.2" stroke="#4c65ff" strokeWidth="1.6" />
          <rect x="13" y="13" width="6" height="6" rx="1.2" stroke="#4c65ff" strokeWidth="1.6" />
        </svg>
      ),
    },
    {
      key: 'promo',
      title: t.multiChainMenu.promo.title,
      desc: t.multiChainMenu.promo.desc,
      href: linkTo || '/multi-chain',
      icon: (
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
          <path d="M5 5h14v14H5z" stroke="#4c65ff" strokeWidth="1.6" />
          <path d="M9 9h6v6H9z" fill="#4c65ff" stroke="#4c65ff" strokeWidth="1.2" />
        </svg>
      ),
    },
  ];

  return (
    <div
      className={className}
      ref={dropdownRef}
      style={{ position: 'relative' }}
      onMouseEnter={() => setIsOpen(true)}
      onMouseLeave={() => setIsOpen(false)}
    >
      <button
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          fontSize: 15,
          fontWeight: 500,
          color: '#3e495e',
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '8px 0',
          transition: 'color 0.2s',
        }}
      >
        {label}
        <svg
          width={12}
          height={12}
          viewBox="0 0 24 24"
          fill="none"
          style={{
            transition: 'transform 0.2s',
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
          }}
        >
          <path
            d="M6 9l6 6 6-6"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            left: -24,
            minWidth: 260,
            padding: '12px 0',
            background: '#fff',
            borderRadius: 14,
            boxShadow: '0 12px 28px rgba(0, 0, 0, 0.12)',
            border: '1px solid #e5e8ef',
            zIndex: 1200,
          }}
        >
          {items.map((item, idx) => {
            const isExternal = item.href?.startsWith('http');
            return (
              <a
                key={item.key}
                href={item.href || '#'}
                target={isExternal ? '_blank' : undefined}
                rel={isExternal ? 'noreferrer' : undefined}
                onClick={() => setIsOpen(false)}
                style={{
                  display: 'flex',
                  gap: 12,
                  padding: '12px 18px',
                  alignItems: 'flex-start',
                  borderBottom: idx !== items.length - 1 ? '1px solid #f0f2f7' : 'none',
                  transition: 'background 0.15s, color 0.15s',
                  textDecoration: 'none',
                  color: '#1f2a44',
                }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLAnchorElement).style.background = '#f7f8fc';
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLAnchorElement).style.background = 'transparent';
                }}
              >
                <div style={{ width: 26, height: 26, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {item.icon}
                </div>
                <div>
                  <div style={{ fontSize: 15, fontWeight: 600, color: '#1f2a44', marginBottom: 4 }}>{item.title}</div>
                  <div style={{ fontSize: 13, color: '#6a7587', lineHeight: 1.5 }}>{item.desc}</div>
                </div>
              </a>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ── Data ── */
const FEATURE_ICONS = [
  IconSwap, IconSend, IconBridge, IconReceive,
  IconNFT, IconSecurity, IconDApps, IconHistory,
];

const SECURITY_CARD_ICONS = [
  {
    key: 'riskScanning' as const,
    icon: (
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#4c65ff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      </svg>
    ),
  },
  {
    key: 'approvalManagement' as const,
    icon: <img src={IconSecurity} alt="" width={28} height={28} />,
  },
  {
    key: 'dappDetection' as const,
    icon: <img src={IconDApps} alt="" width={28} height={28} />,
  },
];

const CHAIN_COLORS: Record<string, string> = {
  ethereum: '#627eea',
  arbitrum: '#28a0f0',
  optimism: '#ff0420',
  polygon: '#8247e5',
  bsc: '#f0b90b',
  avalanche: '#e84142',
  base: '#0052ff',
  zksync: '#4e529a',
  fantom: '#1969ff',
  gnosis: '#04795b',
  linea: '#121212',
  more: '#6a7587',
  btc: '#f7931a',
  doge: '#c2a633',
  trx: '#c63131',
  ton: '#0098ea',
  op: '#ff0420',
  arb: '#28a0f0',
  zks: '#4e529a',
  okb: '#1f5af6',
};

const CHAIN_LOGOS: Record<string, string> = {
  ethereum: ChainEth,
  btc: ChainBtc,
  doge: ChainDoge,
  trx: ChainTrx,
  ton: ChainTon,
  op: ChainOp,
  arb: ChainArb,
  zks: ChainZks,
  base: ChainBase,
  bsc: ChainBnb,
  polygon: ChainPol,
  avalanche: ChainAvax,
  okb: ChainOkt,
};

const WALLET_LOGOS = [
  { src: WalletLedger, key: 'ledger' as const },
  { src: WalletTrezor, key: 'trezor' as const },
  { src: WalletMetamask, key: 'metamask' as const },
  { src: WalletWC, key: 'walletconnect' as const },
  { src: WalletSafe, key: 'safe' as const },
  { src: WalletCoinbase, key: 'coinbase' as const },
  { src: WalletTrust, key: 'trust' as const },
  { src: WalletOneKey, key: 'onekey' as const },
  { src: WalletKeystone, key: 'keystone' as const },
];

const FOOTER_SOCIALS = [
  { src: TwitterSvg, alt: 'Twitter', key: 'twitter' as const },
  { src: DiscordSvg, alt: 'Discord', key: 'discord' as const },
  { src: TelegramSvg, alt: 'Telegram', key: 'telegram' as const },
  { src: DebankSvg, alt: 'DeBank', key: 'debank' as const },
];

/* ── Styles ── */
const wrap = (maxWidth = 1200): React.CSSProperties => ({
  maxWidth,
  margin: '0 auto',
  padding: '0 40px',
});

const sectionTitle: React.CSSProperties = {
  fontSize: 36,
  fontWeight: 700,
  textAlign: 'center' as const,
  marginBottom: 12,
};

const sectionSub: React.CSSProperties = {
  fontSize: 16,
  color: '#6a7587',
  textAlign: 'center' as const,
  marginBottom: 56,
  lineHeight: 1.6,
};

/* ── Component ── */
export default function LandingPage() {
  const { language } = useLanguage();
  // @ts-ignore - type definition mismatch
  const t = translations[language];

  return (
    <div>
      {/* Responsive styles */}
      <style>{`
        @media (max-width: 1023px) {
          .hero-grid { grid-template-columns: 1fr !important; text-align: center; }
          .hero-text { align-items: center !important; }
          .hero-img { order: -1; }
          .feature-grid { grid-template-columns: repeat(2, 1fr) !important; }
          .footer-grid { grid-template-columns: repeat(2, 1fr) !important; }
        }
        @media (max-width: 767px) {
          .feature-grid { grid-template-columns: 1fr !important; }
          .security-grid { grid-template-columns: 1fr !important; }
          .nav-links { display: none !important; }
          .nav-right-link { display: none !important; }
          .footer-grid { grid-template-columns: 1fr !important; }
          .hero-h1 { font-size: 32px !important; }
          .section-title { font-size: 28px !important; }
          .section-wrap { padding: 0 20px !important; }
          .nav-dropdown { display: none !important; }
        }
        .nav-link:hover { color: #4c65ff !important; }
        .cta-btn:hover { background: #3a52e0 !important; }
        .dl-btn:hover { border-color: #4c65ff !important; box-shadow: 0 4px 12px rgba(0,0,0,0.08) !important; }
        .feature-card:hover { transform: translateY(-4px); background: rgba(255,255,255,0.18) !important; }
        .wallet-logo:hover { opacity: 1 !important; }
        .nav-dropdown-item:hover { background: #f7f8fc !important; color: #4c65ff !important; }
      `}</style>

      {/* ─── Section 1: Nav Bar ─── */}
      <nav style={{
        position: 'sticky',
        top: 0,
        zIndex: 100,
        height: 72,
        background: 'rgba(255,255,255,0.97)',
        backdropFilter: 'blur(12px)',
        borderBottom: '1px solid var(--r-neutral-line)',
        display: 'flex',
        alignItems: 'center',
      }}>
        <div style={{ ...wrap(1280), width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* Left: Logo + Nav links (grouped like token.im) */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 48 }}>
            <a href="#" style={{ display: 'flex', alignItems: 'center' }}>
              <img src={LogoLarge} alt="Rabby" style={{ height: 28 }} />
            </a>
            <div className="nav-links" style={{ display: 'flex', alignItems: 'center', gap: 36 }}>
              <FeatureDropdown
                className="nav-dropdown"
                // @ts-ignore
                label={t.nav.features}
                // @ts-ignore
                translations={t}
              />
              <MultiChainDropdown
                className="nav-dropdown"
                // @ts-ignore
                label={t.nav.multiChain}
                // @ts-ignore
                translations={t}
                linkTo="/multi-chain"
              />
              <a href="#security" className="nav-link" style={{ fontSize: 15, fontWeight: 500, color: '#3e495e', transition: 'color 0.2s' }}>
                {/* @ts-ignore */}
                {t.nav.security}
              </a>
              <a href="#gold-token" className="nav-link" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, fontWeight: 500, color: '#3e495e', transition: 'color 0.2s' }}>
                {/* @ts-ignore */}
                {t.nav.goldToken}
                <span style={{ background: '#d55b52', color: '#fff', borderRadius: 999, padding: '2px 8px', fontSize: 11, fontWeight: 700, letterSpacing: 0.3 }}>
                  {/* @ts-ignore */}
                  {t.nav.newTag}
                </span>
              </a>
            </div>
          </div>

          {/* Right: Secondary links + Language + CTA */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
            <LanguageSwitcher />
            <NavDropdown className="nav-dropdown" /* @ts-ignore */ label={t.nav.blog} itemsKey="resources" /* @ts-ignore */ translations={t} />
            <a href="#" className="nav-link nav-right-link" style={{ fontSize: 15, fontWeight: 500, color: '#3e495e', transition: 'color 0.2s' }}>
              {/* @ts-ignore */}
              {t.nav.support}
            </a>
            <a
              href="#download"
              className="cta-btn"
              style={{
                background: '#4c65ff',
                color: '#fff',
                borderRadius: 20,
                padding: '10px 28px',
                fontSize: 14,
                fontWeight: 600,
                transition: 'background 0.2s',
                whiteSpace: 'nowrap',
              }}
            >
              {t.nav.downloadNow}
            </a>
          </div>
        </div>
      </nav>

      {/* ─── Section 2: Hero ─── */}
      <section style={{ background: 'var(--section-light-gray)', padding: '100px 0 80px' }}>
        <div className="section-wrap hero-grid" style={{
          ...wrap(),
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 60,
          alignItems: 'center',
        }}>
          <div className="hero-text" style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
            <h1 className="hero-h1" style={{ fontSize: 48, fontWeight: 800, lineHeight: 1.15, margin: '0 0 20px', color: '#192945' }}>
              {t.hero.title}
            </h1>
            <p style={{ fontSize: 18, lineHeight: 1.6, color: '#6a7587', margin: '0 0 36px' }}>
              {t.hero.description}
            </p>
            <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              <a href="https://apps.apple.com" target="_blank" rel="noopener noreferrer" className="dl-btn" style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '12px 24px', borderRadius: 12,
                border: '1.5px solid var(--r-neutral-line)', background: '#fff',
                fontSize: 15, fontWeight: 600, color: '#192945',
                transition: 'all 0.2s', cursor: 'pointer',
              }}>
                <img src={AppStoreSvg} alt="" style={{ width: 20, height: 20 }} />
                {t.hero.appStore}
              </a>
              <a href="https://chrome.google.com/webstore" target="_blank" rel="noopener noreferrer" className="dl-btn" style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '12px 24px', borderRadius: 12,
                border: '1.5px solid var(--r-neutral-line)', background: '#fff',
                fontSize: 15, fontWeight: 600, color: '#192945',
                transition: 'all 0.2s', cursor: 'pointer',
              }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="10" stroke="#4c65ff" strokeWidth="2" />
                  <circle cx="12" cy="12" r="4" fill="#4c65ff" />
                </svg>
                {t.hero.chromeExtension}
              </a>
            </div>
          </div>
          <div className="hero-img" style={{ position: 'relative', display: 'flex', justifyContent: 'center' }}>
            <div style={{
              position: 'absolute', width: 400, height: 400,
              background: 'radial-gradient(circle, rgba(76,101,255,0.15), transparent 70%)',
              borderRadius: '50%', filter: 'blur(60px)', top: '50%', left: '50%',
              transform: 'translate(-50%, -50%)', zIndex: 0,
            }} />
            <img
              src={HeroPreview}
              alt="Rabby Wallet Preview"
              style={{
                maxWidth: 380, width: '100%',
                borderRadius: 20, boxShadow: 'var(--rabby-shadow-lg)',
                position: 'relative', zIndex: 1,
              }}
            />
          </div>
        </div>
      </section>

      {/* ─── Section 3: Features ─── */}
      <section id="features" style={{
        background: 'linear-gradient(135deg, #4c65ff 0%, #7084ff 50%, #a0b0ff 100%)',
        padding: '80px 0',
      }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={{ ...sectionTitle, color: '#fff' }}>{t.features.title}</h2>
          <p style={{ ...sectionSub, color: 'rgba(255,255,255,0.75)' }}>{t.features.subtitle}</p>
          <div className="feature-grid" style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gap: 24,
          }}>
            {FEATURE_ICONS.map((icon, idx) => {
              const itemKey = Object.keys(t.features.items)[idx] as keyof typeof t.features.items;
              const item = t.features.items[itemKey];
              return (
                <div key={itemKey} className="feature-card" style={{
                  background: 'rgba(255,255,255,0.12)',
                  backdropFilter: 'blur(8px)',
                  borderRadius: 16,
                  padding: '28px 24px',
                  textAlign: 'center',
                  transition: 'transform 0.2s, background 0.2s',
                }}>
                  <div style={{
                    width: 56, height: 56, borderRadius: 14,
                    background: 'rgba(255,255,255,0.15)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    margin: '0 auto 16px',
                  }}>
                    <img src={icon} alt={item.name} width={28} height={28} style={{ filter: 'brightness(0) invert(1)' }} />
                  </div>
                  <div style={{ fontSize: 16, fontWeight: 600, color: '#fff', marginBottom: 6 }}>{item.name}</div>
                  <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.7)', lineHeight: 1.5 }}>{item.desc}</div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ─── Section 4: Security ─── */}
      <section id="security" style={{ background: '#fff', padding: '80px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.security.title}</h2>
          <p style={sectionSub}>{t.security.subtitle}</p>
          <div className="security-grid" style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 32,
          }}>
            {SECURITY_CARD_ICONS.map((card) => {
              const cardData = t.security.cards[card.key];
              return (
                <div key={card.key} style={{
                  padding: 32, borderRadius: 16,
                  background: 'var(--section-light-gray)',
                  textAlign: 'center',
                }}>
                  <div style={{
                    width: 64, height: 64, borderRadius: '50%',
                    background: 'var(--r-blue-light-1)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    margin: '0 auto 20px',
                  }}>
                    {card.icon}
                  </div>
                  <div style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{cardData.title}</div>
                  <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>{cardData.desc}</div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ─── Section 5: Chains ─── */}
      <section id="chains" style={{ background: 'var(--section-light-gray)', padding: '80px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.chains.title}</h2>
          <p style={sectionSub}>{t.chains.subtitle}</p>

          {/* Chains grid */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
            gap: 12,
            marginBottom: 20,
          }}>
            {[
              'btc', 'ethereum', 'doge', 'trx', 'ton',
              'op', 'arb', 'zks', 'base', 'bsc',
              'polygon', 'avalanche', 'okb',
            ].map((chainKey) => (
              <div key={chainKey} style={{
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                padding: '12px 14px',
                borderRadius: 14,
                background: '#fff',
                boxShadow: 'var(--rabby-shadow-sm)',
                border: '1px solid #eef1f5',
              }}>
                {CHAIN_LOGOS[chainKey] ? (
                  <img
                    src={CHAIN_LOGOS[chainKey]}
                    alt={chainKey}
                    style={{ width: 24, height: 24, borderRadius: 8, flexShrink: 0, background: '#f5f6fb' }}
                  />
                ) : (
                  <span style={{
                    width: 12, height: 12, borderRadius: '50%',
                    background: CHAIN_COLORS[chainKey] || '#6a7587', flexShrink: 0,
                  }} />
                )}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{/* @ts-ignore */t.chains.chainNames[chainKey] ?? chainKey}</span>
                  <span style={{ fontSize: 12, color: '#6a7587' }}>{/* @ts-ignore */t.chains.supportText}</span>
                </div>
              </div>
            ))}
          </div>
          <p style={{ fontSize: 12, color: '#6a7587', textAlign: 'center', marginBottom: 32 }}>
            {t.chains.note}
          </p>

          {/* Stablecoins row */}
          <div style={{
            background: '#fff',
            borderRadius: 16,
            padding: '16px 20px',
            boxShadow: 'var(--rabby-shadow-sm)',
            border: '1px solid #eef1f5',
            marginBottom: 28,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M12 3l9 5v8l-9 5-9-5V8l9-5z" stroke="#4c65ff" strokeWidth="1.6" />
                <circle cx="12" cy="12" r="3" fill="#4c65ff" />
              </svg>
              <strong style={{ fontSize: 14 }}>{t.chains.stablecoinsTitle}</strong>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {['USDT', 'USDC', 'DAI', 'FDUSD', 'TUSD', 'USDe', 'GHO', 'crvUSD'].map((s) => (
                <span key={s} style={{
                  padding: '6px 12px',
                  borderRadius: 12,
                  background: '#f7f8fc',
                  fontSize: 13,
                  color: '#3e495e',
                  border: '1px solid #eef1f5',
                }}>
                  {s}
                </span>
              ))}
            </div>
            <p style={{ fontSize: 12, color: '#6a7587', marginTop: 10 }}>{t.chains.stablecoinsNote}</p>
          </div>

          {/* Security highlights */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: 16,
          }}>
            {[
              { key: 'risk', icon: 'shield' },
              { key: 'offline', icon: 'lock' },
              { key: 'audit', icon: 'check' },
            ].map((item) => (
              <div key={item.key} style={{
                background: '#fff',
                borderRadius: 14,
                padding: '16px 18px',
                boxShadow: 'var(--rabby-shadow-sm)',
                border: '1px solid #eef1f5',
                display: 'flex',
                gap: 12,
                alignItems: 'flex-start',
              }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: 'rgba(76,101,255,0.1)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: '#4c65ff',
                }}>
                  {item.icon === 'shield' && <ShieldIcon />}
                  {item.icon === 'lock' && <LockIcon />}
                  {item.icon === 'check' && <CheckIcon />}
                </div>
                <div>
                  <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 6 }}>{/* @ts-ignore */t.chains.securityItems[item.key]}</div>
                  <div style={{ fontSize: 13, color: '#6a7587', lineHeight: 1.5 }}>
                    {t.chains.securityTitle}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Section 6: Compatible Wallets ─── */}
      <section style={{ background: '#fff', padding: '80px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.wallets.title}</h2>
          <p style={sectionSub}>{t.wallets.subtitle}</p>
          <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 40, alignItems: 'center' }}>
            {WALLET_LOGOS.map((w) => (
              <div key={w.key} className="wallet-logo" style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                opacity: 0.55, transition: 'opacity 0.2s', cursor: 'default',
              }}>
                <img src={w.src} alt={w.key} style={{ width: 48, height: 48 }} />
                <span style={{ fontSize: 12, color: '#6a7587' }}>{t.wallets.walletNames[w.key]}</span>
              </div>
            ))}
          </div>
          <p style={{ fontSize: 13, color: '#6a7587', textAlign: 'center', marginTop: 32 }}>
            {t.wallets.more}
          </p>
        </div>
      </section>

      {/* ─── Section 7: Download CTA ─── */}
      <section id="download" style={{
        background: 'linear-gradient(135deg, #4c65ff 0%, #7084ff 50%, #a0b0ff 100%)',
        padding: '80px 0',
      }}>
        <div className="section-wrap" style={{ ...wrap(800), textAlign: 'center' }}>
          <h2 className="section-title" style={{ fontSize: 40, fontWeight: 700, color: '#fff', marginBottom: 16 }}>
            {t.download.title}
          </h2>
          <p style={{ fontSize: 17, color: 'rgba(255,255,255,0.8)', marginBottom: 40 }}>
            {t.download.subtitle}
          </p>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 20, flexWrap: 'wrap' }}>
            <a href="https://apps.apple.com" target="_blank" rel="noopener noreferrer" style={{
              background: '#fff', color: '#192945', border: 'none', borderRadius: 12,
              padding: '16px 32px', fontSize: 16, fontWeight: 600,
              display: 'inline-flex', alignItems: 'center', gap: 12,
              boxShadow: 'var(--rabby-shadow-md)', transition: 'transform 0.2s, box-shadow 0.2s',
              cursor: 'pointer',
            }}>
              <img src={AppStoreSvg} alt="" style={{ width: 22, height: 22 }} />
              {t.download.appStore}
            </a>
            <a href="https://chrome.google.com/webstore" target="_blank" rel="noopener noreferrer" style={{
              background: '#fff', color: '#192945', border: 'none', borderRadius: 12,
              padding: '16px 32px', fontSize: 16, fontWeight: 600,
              display: 'inline-flex', alignItems: 'center', gap: 12,
              boxShadow: 'var(--rabby-shadow-md)', transition: 'transform 0.2s, box-shadow 0.2s',
              cursor: 'pointer',
            }}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="#4c65ff" strokeWidth="2" />
                <circle cx="12" cy="12" r="4" fill="#4c65ff" />
              </svg>
              {t.download.chromeExtension}
            </a>
          </div>
        </div>
      </section>

      {/* ─── Section 8: Footer ─── */}
      <footer style={{ background: '#1a1f36', padding: '60px 0 40px', color: '#fff' }}>
        <div className="section-wrap footer-grid" style={{
          ...wrap(),
          display: 'grid',
          gridTemplateColumns: '2fr 1fr 1fr 1fr',
          gap: 40,
        }}>
          {/* Brand column */}
          <div>
            <img src={LogoWhite} alt="Rabby" style={{ height: 24, filter: 'brightness(0) invert(1)' }} />
            <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.6)', lineHeight: 1.6, marginTop: 16, maxWidth: 280 }}>
              {t.footer.brand.description}
            </p>
            <div style={{ display: 'flex', gap: 16, marginTop: 24 }}>
              {FOOTER_SOCIALS.map((s) => (
                <a key={s.alt} href="#" style={{ opacity: 0.5, transition: 'opacity 0.2s' }}
                  onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.opacity = '1'; }}
                  onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.opacity = '0.5'; }}
                >
                  <img src={s.src} alt={s.alt} style={{ width: 20, height: 20, filter: 'brightness(0) invert(1)' }} />
                </a>
              ))}
            </div>
          </div>

          {/* Link columns */}
          {(['product', 'resources', 'community'] as const).map((sectionKey) => (
            <div key={sectionKey}>
              <div style={{
                fontSize: 14, fontWeight: 600, color: 'rgba(255,255,255,0.9)',
                marginBottom: 16, textTransform: 'uppercase', letterSpacing: '0.05em',
              }}>
                {t.footer.links[sectionKey]}
              </div>
              {(Object.keys(t.footer.links.items) as Array<keyof typeof t.footer.links.items>)
                .filter(key => {
                  if (sectionKey === 'product') return ['iosApp', 'chromeExtension', 'features', 'security'].includes(key);
                  if (sectionKey === 'resources') return ['documentation', 'blog', 'support', 'faq'].includes(key);
                  return ['twitter', 'discord', 'telegram', 'debank'].includes(key);
                })
                .map((key) => (
                  <a key={key} href="#" style={{
                    display: 'block', fontSize: 14, color: 'rgba(255,255,255,0.5)',
                    marginBottom: 10, transition: 'color 0.2s',
                  }}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = 'rgba(255,255,255,0.9)'; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = 'rgba(255,255,255,0.5)'; }}
                  >
                    {t.footer.links.items[key]}
                  </a>
                ))}
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="section-wrap" style={{
          ...wrap(),
          borderTop: '1px solid rgba(255,255,255,0.08)',
          paddingTop: 24,
          marginTop: 40,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 16,
        }}>
          <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>
            {t.footer.bottom.copyright}
          </span>
          <div style={{ display: 'flex', gap: 24 }}>
            <a href="#" style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)', transition: 'color 0.2s' }}>{t.footer.bottom.terms}</a>
            <a href="#" style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)', transition: 'color 0.2s' }}>{t.footer.bottom.privacy}</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
const ShieldIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <path d="M12 3l7 3v6.5c0 3.5-2.5 6.7-7 8.5-4.5-1.8-7-5-7-8.5V6l7-3z" stroke="#4c65ff" strokeWidth="1.6" strokeLinejoin="round" />
    <path d="M9 12l2 2 4-4" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const LockIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <rect x="5" y="10" width="14" height="10" rx="2" stroke="#4c65ff" strokeWidth="1.6" />
    <path d="M9 10V7a3 3 0 016 0v3" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
    <circle cx="12" cy="15" r="1.5" fill="#4c65ff" />
  </svg>
);

const CheckIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <rect x="4" y="4" width="16" height="16" rx="4" stroke="#4c65ff" strokeWidth="1.6" />
    <path d="M8 12l3 3 5-6" stroke="#4c65ff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
