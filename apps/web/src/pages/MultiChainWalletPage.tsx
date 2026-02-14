import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { translations } from '../i18n/translations';
import { LanguageSwitcher } from '../components/LanguageSwitcher';

/* ── Assets ── */
import LogoLarge from '../assets/landing/logo-rabby-large.svg';
import LogoWhite from '../assets/landing/rabby-white-large.svg';
import AppStoreSvg from '../assets/landing/app-store.svg';
import DiscordSvg from '../assets/landing/discord.svg';
import TwitterSvg from '../assets/landing/twitter.svg';
import TelegramSvg from '../assets/landing/telegram.svg';
import DebankSvg from '../assets/landing/debank.svg';

import WalletLedger from '../assets/walletlogo/ledger.svg';
import WalletTrezor from '../assets/walletlogo/trezor.svg';
import WalletOneKey from '../assets/walletlogo/onekey.svg';
import WalletKeystone from '../assets/walletlogo/keystone.svg';

// Chain icons - Real PNG logos
import IconEth from '../assets/chains/eth.png';
import IconBtc from '../assets/chains/btc.png';
import IconDoge from '../assets/chains/doge.png';
import IconApt from '../assets/chains/apt.png';
import IconTrx from '../assets/chains/trx.png';
import IconTon from '../assets/chains/ton.png';
import IconOp from '../assets/chains/op.png';
import IconArb from '../assets/chains/arb.png';
import IconZks from '../assets/chains/zks.png';
import IconBase from '../assets/chains/base.png';
import IconPol from '../assets/chains/pol.png';
import IconBnb from '../assets/chains/bnb.png';
import IconOkt from '../assets/chains/okt.svg';
import IconAvax from '../assets/chains/avax.png';

/* ── Icons ── */
const ShieldIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <path d="M12 3l7 3v6.5c0 3.5-2.5 6.7-7 8.5-4.5-1.8-7-5-7-8.5V6l7-3z" stroke="#4c65ff" strokeWidth="1.6" strokeLinejoin="round" />
    <path d="M9 12l2 2 4-4" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const LockIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <rect x="5" y="10" width="14" height="10" rx="2" stroke="#4c65ff" strokeWidth="1.6" />
    <path d="M9 10V7a3 3 0 016 0v3" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
    <circle cx="12" cy="15" r="1.5" fill="#4c65ff" />
  </svg>
);

const ScanIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="8" stroke="#4c65ff" strokeWidth="1.6" />
    <path d="M12 8v4l3 3" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
  </svg>
);

const BiometricIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <path d="M8 12c0-2.2 1.8-4 4-4s4 1.8 4 4-1.8 4-4 4-4-1.8-4-4zm4 6c-3.3 0-6-2.7-6-6s2.7-6 6-6 6 2.7 6 6-2.7 6-6 6z" stroke="#4c65ff" strokeWidth="1.6" />
    <circle cx="12" cy="12" r="2" fill="#4c65ff" />
  </svg>
);

const GasIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <path d="M12 3l3 7h-6l3-7zm0 18l-3-7h6l-3 7z" stroke="#4c65ff" strokeWidth="1.6" strokeLinejoin="round" />
    <path d="M12 8v8" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
  </svg>
);

const DomainIcon = () => (
  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
    <circle cx="9" cy="12" r="6" stroke="#4c65ff" strokeWidth="1.6" />
    <circle cx="15" cy="12" r="6" stroke="#4c65ff" strokeWidth="1.6" />
    <path d="M15 6V8" stroke="#4c65ff" strokeWidth="1.6" strokeLinecap="round" />
    <path d="M9 16v-4h6v4" stroke="#4c65ff" strokeWidth="1.6" />
  </svg>
);

const EthereumIcon = () => (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="none">
    <path d="M12 3l7 9-7 3-7-3 7-9z" fill="#627eea" opacity="0.8"/>
    <path d="M12 22l-7-10 7 3 7-3-7 10z" fill="#627eea" opacity="0.6"/>
  </svg>
);

const BitcoinIcon = () => (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="10" fill="#f7931a" opacity="0.2"/>
    <path d="M14 7h-2v2h-2v2h2v6h-2v2h2v2h2v-2h2v-2h-2v-6h2v-2h-2V9h2V7z" fill="#f7931a"/>
  </svg>
);

const CheckCircleIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="9" stroke="#16c784" strokeWidth="1.6" />
    <path d="M8 12l2.5 2.5L15 9" stroke="#16c784" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

/* ── Components ── */
const wrap = (maxWidth = 1200): React.CSSProperties => ({
  maxWidth,
  margin: '0 auto',
  padding: '0 40px',
});

const sectionTitle: React.CSSProperties = {
  fontSize: 40,
  fontWeight: 700,
  textAlign: 'center' as const,
  marginBottom: 16,
  color: '#192945',
};

const sectionSub: React.CSSProperties = {
  fontSize: 16,
  color: '#6a7587',
  textAlign: 'center' as const,
  marginBottom: 56,
  lineHeight: 1.6,
  maxWidth: 720,
  marginLeft: 'auto',
  marginRight: 'auto',
};

export default function MultiChainWalletPage() {
  const { language } = useLanguage();
  // @ts-ignore - multiChainPage exists in translations but not in type definition
  const t = (translations[language] as any).multiChainPage;

  return (
    <div>
      {/* Responsive styles */}
      <style>{`
        @media (max-width: 1023px) {
          .hero-grid { grid-template-columns: 1fr !important; text-align: center; }
          .chain-grid { grid-template-columns: repeat(2, 1fr) !important; }
          .hardware-grid { grid-template-columns: repeat(3, 1fr) !important; }
        }
        @media (max-width: 767px) {
          .chain-grid { grid-template-columns: 1fr !important; }
          .hardware-grid { grid-template-columns: repeat(2, 1fr) !important; }
          .hero-title { font-size: 32px !important; }
          .section-title { font-size: 28px !important; }
          .section-wrap { padding: 0 20px !important; }
        }
        .chain-card:hover { transform: translateY(-4px); box-shadow: 0 8px 20px rgba(0,0,0,0.1) !important; }
        .feature-icon-box { background: linear-gradient(135deg, #4c65ff 0%, #7084ff 100%); }
      `}</style>

      {/* ─── Navigation ─── */}
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
          <a href="/" style={{ display: 'flex', alignItems: 'center' }}>
            <img src={LogoLarge} alt="Rabby" style={{ height: 28 }} />
          </a>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
            <LanguageSwitcher />
            <a href="#security" style={{ fontSize: 15, fontWeight: 500, color: '#3e495e' }}>
              安全
            </a>
            <a
              href="#download"
              style={{
                background: '#4c65ff',
                color: '#fff',
                borderRadius: 20,
                padding: '10px 28px',
                fontSize: 14,
                fontWeight: 600,
              }}
            >
              立即下载
            </a>
          </div>
        </div>
      </nav>

      {/* ─── Hero Section ─── */}
      <section style={{
        background: 'linear-gradient(135deg, #f7f8fc 0%, #edf0ff 100%)',
        padding: '120px 0 100px',
        textAlign: 'center',
      }}>
        <div className="section-wrap" style={wrap()}>
          <h1 className="hero-title" style={{
            fontSize: 56,
            fontWeight: 800,
            lineHeight: 1.2,
            margin: '0 0 24px',
            background: 'linear-gradient(135deg, #4c65ff 0%, #7084ff 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
          }}>
            {t.hero.title}
          </h1>
          <p style={{
            fontSize: 18,
            color: '#6a7587',
            maxWidth: 900,
            margin: '0 auto 40px',
            lineHeight: 1.8,
          }}>
            {t.hero.subtitle}
          </p>
          <div style={{ display: 'flex', gap: 16, justifyContent: 'center', flexWrap: 'wrap' }}>
            <a href="#download" style={{
              background: '#4c65ff',
              color: '#fff',
              borderRadius: 12,
              padding: '16px 40px',
              fontSize: 16,
              fontWeight: 600,
              boxShadow: '0 4px 12px rgba(76,101,255,0.3)',
              transition: 'transform 0.2s, box-shadow 0.2s',
            }}>
              {t.hero.cta}
            </a>
          </div>
        </div>
      </section>

      {/* ─── Multi-chain Networks Section ─── */}
      <section style={{ background: '#fff', padding: '100px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.multiChain.title}</h2>
          <p style={sectionSub}>{t.multiChain.subtitle}</p>

          {/* Chain Cards Grid */}
          <div className="chain-grid" style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: 24,
            marginBottom: 40,
          }}>
            {/* ETH */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(98,126,234,0.1) 0%, rgba(98,126,234,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconEth} alt="Ethereum" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.eth.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.eth.desc}
              </div>
            </div>

            {/* BTC */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(247,147,26,0.1) 0%, rgba(247,147,26,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconBtc} alt="Bitcoin" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.btc.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.btc.desc}
              </div>
            </div>

            {/* DOGE */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(194,166,51,0.1) 0%, rgba(194,166,51,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconDoge} alt="Dogecoin" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.doge.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.doge.desc}
              </div>
            </div>

            {/* APT */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(40,54,255,0.1) 0%, rgba(40,54,255,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconApt} alt="Aptos" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.apt.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.apt.desc}
              </div>
            </div>

            {/* TRX */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(198,49,49,0.1) 0%, rgba(198,49,49,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconTrx} alt="TRON" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.trx.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.trx.desc}
              </div>
            </div>

            {/* TON */}
            <div className="chain-card" style={{
              padding: '32px 24px',
              borderRadius: 20,
              background: '#fff',
              border: '1px solid #eef1f5',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              transition: 'all 0.3s ease',
            }}>
              <div style={{
                width: 64,
                height: 64,
                borderRadius: 16,
                background: 'linear-gradient(135deg, rgba(0,152,234,0.1) 0%, rgba(0,152,234,0.05) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
              }}>
                <img src={IconTon} alt="TON" style={{ width: 36, height: 36 }} />
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                {t.chains.ton.name}
              </div>
              <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                {t.chains.ton.desc}
              </div>
            </div>
          </div>

          {/* More chains chips */}
          <div style={{
            display: 'flex',
            flexWrap: 'wrap',
            gap: 12,
            justifyContent: 'center',
            marginBottom: 32,
          }}>
            {[
              { key: 'op', color: '#ff0420', icon: IconOp },
              { key: 'arb', color: '#28a0f0', icon: IconArb },
              { key: 'zks', color: '#4e529a', icon: IconZks },
              { key: 'base', color: '#0052ff', icon: IconBase },
              { key: 'bnb', color: '#f0b90b', icon: IconBnb },
              { key: 'pol', color: '#8247e5', icon: IconPol },
              { key: 'okt', color: '#1f5af6', icon: IconOkt },
              { key: 'avax', color: '#e84142', icon: IconAvax },
            ].map((chain) => (
              <div key={chain.key} style={{
                padding: '10px 20px',
                borderRadius: 20,
                background: '#f7f8fc',
                fontSize: 14,
                fontWeight: 600,
                color: '#3e495e',
                border: '1px solid #eef1f5',
                display: 'flex',
                alignItems: 'center',
                gap: 8,
              }}>
                <img src={chain.icon} alt={chain.key} style={{ width: 20, height: 20 }} />
                {t.chains[chain.key as keyof typeof t.chains]?.name || chain.key.toUpperCase()}
              </div>
            ))}
          </div>

          <p style={{ fontSize: 13, color: '#6a7587', textAlign: 'center', marginTop: 24 }}>
            {t.chains.note}
          </p>
        </div>
      </section>

      {/* ─── Stablecoins Section ─── */}
      <section style={{ background: '#f7f8fc', padding: '80px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <div style={{
            background: '#fff',
            borderRadius: 24,
            padding: '40px',
            boxShadow: '0 4px 12px rgba(0,0,0,0.04)',
          }}>
            <h3 style={{
              fontSize: 24,
              fontWeight: 700,
              marginBottom: 12,
              color: '#192945',
            }}>
              {t.stablecoins.title}
            </h3>
            <p style={{ fontSize: 14, color: '#6a7587', marginBottom: 24 }}>
              {t.stablecoins.subtitle}
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
              {t.stablecoins.coins.map((coin: string) => (
                <span key={coin} style={{
                  padding: '8px 16px',
                  borderRadius: 12,
                  background: 'rgba(76,101,255,0.08)',
                  fontSize: 14,
                  fontWeight: 600,
                  color: '#4c65ff',
                  border: '1px solid rgba(76,101,255,0.2)',
                }}>
                  {coin}
                </span>
              ))}
            </div>
            <p style={{ fontSize: 13, color: '#6a7587', marginTop: 20 }}>
              {t.stablecoins.note}
            </p>
          </div>
        </div>
      </section>

      {/* ─── Security Section ─── */}
      <section id="security" style={{ background: '#fff', padding: '100px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.security.title}</h2>
          <p style={sectionSub}>{t.security.subtitle}</p>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: 32,
          }}>
            {t.security.features.map((feature: any, idx: number) => (
              <div key={idx} style={{
                padding: '32px',
                borderRadius: 20,
                background: '#f7f8fc',
                border: '1px solid #eef1f5',
              }}>
                <div style={{
                  width: 56,
                  height: 56,
                  borderRadius: 14,
                  background: 'linear-gradient(135deg, #4c65ff 0%, #7084ff 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: 20,
                }}>
                  {feature.icon === 'offline' && <LockIcon />}
                  {feature.icon === 'audit' && <CheckCircleIcon />}
                  {feature.icon === 'scan' && <ScanIcon />}
                </div>
                <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: '#192945' }}>
                  {feature.title}
                </div>
                <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.7 }}>
                  {feature.desc}
                </div>
              </div>
            ))}
          </div>

          {/* Audit Partners */}
          <div style={{ marginTop: 60, textAlign: 'center' }}>
            <p style={{ fontSize: 14, color: '#6a7587', marginBottom: 24 }}>
              {t.security.auditPartners}
            </p>
            <div style={{
              display: 'flex',
              gap: 32,
              justifyContent: 'center',
              flexWrap: 'wrap',
              fontSize: 16,
              fontWeight: 600,
              color: '#3e495e',
            }}>
              {t.security.partners.map((partner: string) => (
                <span key={partner} style={{
                  padding: '12px 24px',
                  borderRadius: 12,
                  background: '#f7f8fc',
                }}>
                  {partner}
                </span>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ─── Transfer Features Section ─── */}
      <section style={{ background: '#f7f8fc', padding: '100px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.transfer.title}</h2>
          <p style={sectionSub}>{t.transfer.subtitle}</p>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: 24,
          }}>
            {t.transfer.features.map((feature: any, idx: number) => (
              <div key={idx} style={{
                padding: '32px 24px',
                borderRadius: 20,
                background: '#fff',
                border: '1px solid #eef1f5',
                boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              }}>
                <div style={{
                  width: 48,
                  height: 48,
                  borderRadius: 12,
                  background: 'rgba(76,101,255,0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: 16,
                }}>
                  {feature.icon === 'biometric' && <BiometricIcon />}
                  {feature.icon === 'gas' && <GasIcon />}
                  {feature.icon === 'domain' && <DomainIcon />}
                </div>
                <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 8, color: '#192945' }}>
                  {feature.title}
                </div>
                <div style={{ fontSize: 14, color: '#6a7587', lineHeight: 1.6 }}>
                  {feature.desc}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Hardware Wallets Section ─── */}
      <section style={{ background: '#fff', padding: '100px 0' }}>
        <div className="section-wrap" style={wrap()}>
          <h2 className="section-title" style={sectionTitle}>{t.hardware.title}</h2>
          <p style={sectionSub}>{t.hardware.subtitle}</p>

          <div className="hardware-grid" style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 24,
          }}>
            {[
              { key: 'ledger', src: WalletLedger },
              { key: 'trezor', src: WalletTrezor },
              { key: 'onekey', src: WalletOneKey },
              { key: 'keystone', src: WalletKeystone },
            ].map((wallet) => (
              <div key={wallet.key} style={{
                padding: '24px',
                borderRadius: 16,
                background: '#f7f8fc',
                textAlign: 'center',
                border: '1px solid #eef1f5',
                transition: 'all 0.2s ease',
              }}>
                <img
                  src={wallet.src}
                  alt={t.hardware.brands[wallet.key as keyof typeof t.hardware.brands]}
                  style={{ width: 64, height: 64, margin: '0 auto 12' }}
                />
                <div style={{ fontSize: 14, fontWeight: 600, color: '#3e495e' }}>
                  {t.hardware.brands[wallet.key as keyof typeof t.hardware.brands]}
                </div>
              </div>
            ))}
          </div>

          <p style={{ fontSize: 13, color: '#6a7587', textAlign: 'center', marginTop: 32 }}>
            以及 Cobo、imKey、GridPlus、BitBox、CoolWallet、Safe、Ngrave、Fireblocks、AirGap 等
          </p>
        </div>
      </section>

      {/* ─── Download CTA ─── */}
      <section id="download" style={{
        background: 'linear-gradient(135deg, #4c65ff 0%, #7084ff 50%, #a0b0ff 100%)',
        padding: '100px 0',
      }}>
        <div className="section-wrap" style={{ ...wrap(800), textAlign: 'center' }}>
          <h2 style={{
            fontSize: 40,
            fontWeight: 700,
            color: '#fff',
            marginBottom: 16,
          }}>
            立即开始使用 Rabby
          </h2>
          <p style={{
            fontSize: 17,
            color: 'rgba(255,255,255,0.85)',
            marginBottom: 40,
          }}>
            支持 iOS 和 Chrome 浏览器扩展
          </p>
          <div style={{ display: 'flex', gap: 20, justifyContent: 'center', flexWrap: 'wrap' }}>
            <a
              href="https://apps.apple.com"
              target="_blank"
              rel="noopener noreferrer"
              style={{
                background: '#fff',
                color: '#192945',
                borderRadius: 12,
                padding: '16px 32px',
                fontSize: 16,
                fontWeight: 600,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 12,
                boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
              }}
            >
              <img src={AppStoreSvg} alt="" style={{ width: 22, height: 22 }} />
              App Store
            </a>
            <a
              href="https://chrome.google.com/webstore"
              target="_blank"
              rel="noopener noreferrer"
              style={{
                background: 'rgba(255,255,255,0.15)',
                color: '#fff',
                borderRadius: 12,
                padding: '16px 32px',
                fontSize: 16,
                fontWeight: 600,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 12,
                backdropFilter: 'blur(8px)',
                border: '1px solid rgba(255,255,255,0.3)',
              }}
            >
              Chrome Extension
            </a>
          </div>
        </div>
      </section>

      {/* ─── Footer ─── */}
      <footer style={{ background: '#1a1f36', padding: '60px 0 40px', color: '#fff' }}>
        <div style={{ ...wrap(), display: 'grid', gridTemplateColumns: '2fr 1fr 1fr 1fr', gap: 40 }}>
          <div>
            <img src={LogoWhite} alt="Rabby" style={{ height: 24, filter: 'brightness(0) invert(1)' }} />
            <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.6)', lineHeight: 1.6, marginTop: 16, maxWidth: 280 }}>
              以太坊及所有 EVM 链的颠覆性钱包。安全、便捷、开放。
            </p>
            <div style={{ display: 'flex', gap: 16, marginTop: 24 }}>
              <a href="#" style={{ opacity: 0.5, transition: 'opacity 0.2s' }}>
                <img src={TwitterSvg} alt="Twitter" style={{ width: 20, height: 20, filter: 'brightness(0) invert(1)' }} />
              </a>
              <a href="#" style={{ opacity: 0.5, transition: 'opacity 0.2s' }}>
                <img src={DiscordSvg} alt="Discord" style={{ width: 20, height: 20, filter: 'brightness(0) invert(1)' }} />
              </a>
              <a href="#" style={{ opacity: 0.5, transition: 'opacity 0.2s' }}>
                <img src={TelegramSvg} alt="Telegram" style={{ width: 20, height: 20, filter: 'brightness(0) invert(1)' }} />
              </a>
              <a href="#" style={{ opacity: 0.5, transition: 'opacity 0.2s' }}>
                <img src={DebankSvg} alt="DeBank" style={{ width: 20, height: 20, filter: 'brightness(0) invert(1)' }} />
              </a>
            </div>
          </div>

          <div>
            <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 16 }}>产品</div>
            {['iOS应用', 'Chrome扩展', '功能', '安全'].map((item) => (
              <a key={item} href="#" style={{ display: 'block', fontSize: 14, color: 'rgba(255,255,255,0.5)', marginBottom: 10 }}>
                {item}
              </a>
            ))}
          </div>

          <div>
            <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 16 }}>资源</div>
            {['文档', '博客', '支持', 'FAQ'].map((item) => (
              <a key={item} href="#" style={{ display: 'block', fontSize: 14, color: 'rgba(255,255,255,0.5)', marginBottom: 10 }}>
                {item}
              </a>
            ))}
          </div>

          <div>
            <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 16 }}>社区</div>
            {['Twitter', 'Discord', 'Telegram', 'DeBank'].map((item) => (
              <a key={item} href="#" style={{ display: 'block', fontSize: 14, color: 'rgba(255,255,255,0.5)', marginBottom: 10 }}>
                {item}
              </a>
            ))}
          </div>
        </div>

        <div style={{
          ...wrap(),
          borderTop: '1px solid rgba(255,255,255,0.08)',
          paddingTop: 24,
          marginTop: 40,
          display: 'flex',
          justifyContent: 'space-between',
        }}>
          <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>
            © 2024 Rabby Wallet. 保留所有权利。
          </span>
          <div style={{ display: 'flex', gap: 24 }}>
            <a href="#" style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>条款</a>
            <a href="#" style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>隐私</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
