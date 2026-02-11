import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';

/* ---------- Types ---------- */

type DappCategory = 'All' | 'DeFi' | 'NFT' | 'Bridge' | 'Social';

interface DappItem {
  id: string;
  name: string;
  category: Exclude<DappCategory, 'All'>;
  description: string;
  url: string;
  color: string; // icon placeholder bg
  letter: string; // first letter for placeholder
}

/* ---------- Mock data ---------- */

const MOCK_DAPPS: DappItem[] = [
  {
    id: '1',
    name: 'Uniswap',
    category: 'DeFi',
    description: 'The leading decentralized exchange for token swaps on Ethereum and L2s',
    url: 'https://app.uniswap.org',
    color: '#FF007A',
    letter: 'U',
  },
  {
    id: '2',
    name: 'Aave',
    category: 'DeFi',
    description: 'Decentralized lending and borrowing protocol with multi-chain support',
    url: 'https://app.aave.com',
    color: '#B6509E',
    letter: 'A',
  },
  {
    id: '3',
    name: 'OpenSea',
    category: 'NFT',
    description: 'The largest marketplace for NFTs, collectibles, and digital art',
    url: 'https://opensea.io',
    color: '#2081E2',
    letter: 'O',
  },
  {
    id: '4',
    name: 'Lido',
    category: 'DeFi',
    description: 'Liquid staking for Ethereum - stake ETH and receive stETH',
    url: 'https://lido.fi',
    color: '#00A3FF',
    letter: 'L',
  },
  {
    id: '5',
    name: 'Stargate',
    category: 'Bridge',
    description: 'Omnichain bridge powered by LayerZero for native asset transfers',
    url: 'https://stargate.finance',
    color: '#8B5CF6',
    letter: 'S',
  },
  {
    id: '6',
    name: 'Blur',
    category: 'NFT',
    description: 'Pro NFT marketplace with advanced trading tools and analytics',
    url: 'https://blur.io',
    color: '#FF6600',
    letter: 'B',
  },
  {
    id: '7',
    name: 'Across',
    category: 'Bridge',
    description: 'Fast and low-cost bridge for moving assets across EVM chains',
    url: 'https://across.to',
    color: '#6CF9D8',
    letter: 'A',
  },
  {
    id: '8',
    name: 'Lens Protocol',
    category: 'Social',
    description: 'Decentralized social graph for building Web3 social applications',
    url: 'https://lens.xyz',
    color: '#00501E',
    letter: 'L',
  },
  {
    id: '9',
    name: 'Farcaster',
    category: 'Social',
    description: 'Decentralized social network with open composable feeds',
    url: 'https://warpcast.com',
    color: '#8A63D2',
    letter: 'F',
  },
  {
    id: '10',
    name: 'Curve',
    category: 'DeFi',
    description: 'Stablecoin DEX optimized for low-slippage swaps and yield farming',
    url: 'https://curve.fi',
    color: '#FF3D00',
    letter: 'C',
  },
];

const MOCK_RECENT: DappItem[] = [MOCK_DAPPS[0], MOCK_DAPPS[2], MOCK_DAPPS[4]];

const CATEGORIES: DappCategory[] = ['All', 'DeFi', 'NFT', 'Bridge', 'Social'];

/* ---------- Styles ---------- */

const pageContainer: React.CSSProperties = {
  minHeight: '100vh',
  background: 'var(--r-neutral-bg-2, #f2f4f7)',
  padding: '40px 24px',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const innerContainer: React.CSSProperties = {
  maxWidth: 960,
  margin: '0 auto',
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

const searchContainer: React.CSSProperties = {
  position: 'relative' as const,
  marginTop: 24,
  marginBottom: 24,
};

const searchInput: React.CSSProperties = {
  width: '100%',
  padding: '14px 16px 14px 44px',
  borderRadius: 12,
  border: '1.5px solid transparent',
  background: 'var(--r-neutral-card-1, #fff)',
  fontSize: 15,
  color: 'var(--r-neutral-title-1, #192945)',
  outline: 'none',
  boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
  boxSizing: 'border-box' as const,
  transition: 'border-color 0.2s',
};

const searchIconStyle: React.CSSProperties = {
  position: 'absolute' as const,
  left: 14,
  top: '50%',
  transform: 'translateY(-50%)',
  pointerEvents: 'none' as const,
};

const tabRow: React.CSSProperties = {
  display: 'flex',
  gap: 8,
  marginBottom: 24,
  overflowX: 'auto' as const,
};

const dappGrid: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
  gap: 16,
};

const sectionHeading: React.CSSProperties = {
  fontSize: 16,
  fontWeight: 600,
  color: 'var(--r-neutral-title-1, #192945)',
  margin: '0 0 16px',
};

const recentRow: React.CSSProperties = {
  display: 'flex',
  gap: 12,
  overflowX: 'auto' as const,
  paddingBottom: 4,
  marginBottom: 32,
};

/* ---------- Search Icon SVG ---------- */

function SearchIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" style={searchIconStyle}>
      <circle cx="8" cy="8" r="5.5" stroke="var(--r-neutral-foot, #6a7587)" strokeWidth="1.6" />
      <path d="M12.5 12.5L16 16" stroke="var(--r-neutral-foot, #6a7587)" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

/* ---------- Category Tab ---------- */

function CategoryTab({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  const style: React.CSSProperties = {
    padding: '8px 18px',
    borderRadius: 20,
    border: 'none',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
    background: active ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-card-1, #fff)',
    color: active ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
    transition: 'all 0.2s',
    whiteSpace: 'nowrap' as const,
    flexShrink: 0,
  };

  return (
    <button style={style} onClick={onClick}>
      {label}
    </button>
  );
}

/* ---------- DApp Card ---------- */

function DappCard({ dapp }: { dapp: DappItem }) {
  const [hovered, setHovered] = useState(false);

  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    padding: '24px 20px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: 14,
    border: '1.5px solid',
    borderColor: hovered ? 'var(--r-blue-default, #4c65ff)' : 'transparent',
    boxShadow: hovered ? '0 4px 16px rgba(76,101,255,0.1)' : '0 1px 4px rgba(0,0,0,0.04)',
    transition: 'all 0.2s',
    cursor: 'default',
  };

  const iconPlaceholder: React.CSSProperties = {
    width: 48,
    height: 48,
    borderRadius: 12,
    background: dapp.color,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 20,
    fontWeight: 700,
    color: '#fff',
    flexShrink: 0,
  };

  const categoryTag: React.CSSProperties = {
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: 6,
    fontSize: 11,
    fontWeight: 600,
    background: 'var(--r-neutral-bg-2, #f2f4f7)',
    color: 'var(--r-neutral-foot, #6a7587)',
  };

  const openBtn: React.CSSProperties = {
    padding: '8px 0',
    borderRadius: 8,
    border: 'none',
    background: 'var(--r-blue-default, #4c65ff)',
    color: '#fff',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
    width: '100%',
    transition: 'opacity 0.2s',
  };

  return (
    <div
      style={cardStyle}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={iconPlaceholder}>{dapp.letter}</div>
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontSize: 16,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
            }}
          >
            {dapp.name}
          </div>
          <span style={categoryTag}>{dapp.category}</span>
        </div>
      </div>

      <div
        style={{
          fontSize: 13,
          color: 'var(--r-neutral-foot, #6a7587)',
          lineHeight: 1.55,
          flex: 1,
        }}
      >
        {dapp.description}
      </div>

      <button
        style={openBtn}
        onClick={() => window.open(dapp.url, '_blank', 'noopener,noreferrer')}
        onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
        onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
      >
        Open
      </button>
    </div>
  );
}

/* ---------- Recent DApp Chip ---------- */

function RecentChip({ dapp }: { dapp: DappItem }) {
  const [hovered, setHovered] = useState(false);

  const chipStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '10px 16px',
    borderRadius: 12,
    background: 'var(--r-neutral-card-1, #fff)',
    border: '1.5px solid',
    borderColor: hovered ? 'var(--r-blue-default, #4c65ff)' : 'transparent',
    cursor: 'pointer',
    transition: 'all 0.2s',
    flexShrink: 0,
    boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
  };

  const miniIcon: React.CSSProperties = {
    width: 32,
    height: 32,
    borderRadius: 8,
    background: dapp.color,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 14,
    fontWeight: 700,
    color: '#fff',
    flexShrink: 0,
  };

  return (
    <div
      style={chipStyle}
      onClick={() => window.open(dapp.url, '_blank', 'noopener,noreferrer')}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div style={miniIcon}>{dapp.letter}</div>
      <div>
        <div
          style={{
            fontSize: 14,
            fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
            whiteSpace: 'nowrap' as const,
          }}
        >
          {dapp.name}
        </div>
        <div
          style={{
            fontSize: 11,
            color: 'var(--r-neutral-foot, #6a7587)',
            whiteSpace: 'nowrap' as const,
          }}
        >
          {dapp.category}
        </div>
      </div>
    </div>
  );
}

/* ---------- Main Page ---------- */

export default function DappSearch() {
  const location = useLocation();
  const initialQuery = (location.state as { q?: string } | null)?.q || '';
  const [search, setSearch] = useState(initialQuery);
  const [activeCategory, setActiveCategory] = useState<DappCategory>('All');
  const [searchFocused, setSearchFocused] = useState(false);

  useEffect(() => {
    if (initialQuery) setSearch(initialQuery);
  }, [initialQuery]);

  const filtered = useMemo(() => {
    let list = MOCK_DAPPS;

    if (activeCategory !== 'All') {
      list = list.filter((d) => d.category === activeCategory);
    }

    if (search.trim()) {
      const q = search.trim().toLowerCase();
      list = list.filter(
        (d) =>
          d.name.toLowerCase().includes(q) ||
          d.description.toLowerCase().includes(q) ||
          d.category.toLowerCase().includes(q),
      );
    }

    return list;
  }, [search, activeCategory]);

  return (
    <div style={pageContainer}>
      <div style={innerContainer}>
        <h1 style={titleStyle}>DApp Browser</h1>
        <p style={subtitleStyle}>
          Discover and access decentralized applications across the ecosystem
        </p>

        {/* Search bar */}
        <div style={searchContainer}>
          <SearchIcon />
          <input
            type="text"
            placeholder="Search DApps by name, category, or description..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onFocus={() => setSearchFocused(true)}
            onBlur={() => setSearchFocused(false)}
            style={{
              ...searchInput,
              borderColor: searchFocused
                ? 'var(--r-blue-default, #4c65ff)'
                : 'transparent',
            }}
          />
        </div>

        {/* Recently visited */}
        {!search.trim() && (
          <div style={{ marginBottom: 32 }}>
            <h2 style={sectionHeading}>Recently Visited</h2>
            <div style={recentRow}>
              {MOCK_RECENT.map((dapp) => (
                <RecentChip key={dapp.id} dapp={dapp} />
              ))}
            </div>
          </div>
        )}

        {/* Category tabs */}
        <div style={tabRow}>
          {CATEGORIES.map((cat) => (
            <CategoryTab
              key={cat}
              label={cat}
              active={activeCategory === cat}
              onClick={() => setActiveCategory(cat)}
            />
          ))}
        </div>

        {/* DApp grid */}
        {filtered.length > 0 ? (
          <div style={dappGrid}>
            {filtered.map((dapp) => (
              <DappCard key={dapp.id} dapp={dapp} />
            ))}
          </div>
        ) : (
          <div
            style={{
              background: 'var(--r-neutral-card-1, #fff)',
              borderRadius: 16,
              padding: '60px 24px',
              textAlign: 'center' as const,
            }}
          >
            <svg width="48" height="48" viewBox="0 0 48 48" fill="none" style={{ marginBottom: 16 }}>
              <circle cx="24" cy="24" r="20" stroke="var(--r-neutral-bg-2, #f2f4f7)" strokeWidth="3" fill="none" />
              <circle cx="20" cy="20" r="8" stroke="var(--r-neutral-foot, #6a7587)" strokeWidth="2" fill="none" opacity="0.4" />
              <path d="M26 26l8 8" stroke="var(--r-neutral-foot, #6a7587)" strokeWidth="2" strokeLinecap="round" opacity="0.4" />
            </svg>
            <h3
              style={{
                fontSize: 18,
                fontWeight: 600,
                color: 'var(--r-neutral-title-1, #192945)',
                margin: '0 0 6px',
              }}
            >
              No DApps Found
            </h3>
            <p
              style={{
                fontSize: 14,
                color: 'var(--r-neutral-foot, #6a7587)',
                margin: 0,
              }}
            >
              Try adjusting your search or selecting a different category.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
