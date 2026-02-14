import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { TokenItem, Chain } from '@rabby/shared';

interface TokenWithChainProps {
  token: TokenItem;
  chains?: Chain[];
  width?: string;
  height?: string;
  chainSize?: number;
  hideChainIcon?: boolean;
  noRound?: boolean;
  className?: string;
  chainClassName?: string;
}

const FALLBACK_ICON = 'data:image/svg+xml,' + encodeURIComponent(
  '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
  '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/>' +
  '<text x="16" y="21" text-anchor="middle" font-size="14" fill="%236A7587">?</text></svg>'
);

export const TokenWithChain: React.FC<TokenWithChainProps> = ({
  token,
  chains,
  width = '28px',
  height = '28px',
  chainSize = 14,
  hideChainIcon = false,
  noRound = false,
  className,
  chainClassName,
}) => {
  const chain = useMemo(
    () => chains?.find((c) => c.serverId === token.chain),
    [chains, token.chain]
  );

  const chainStyle = useMemo(
    () => ({ width: chainSize, height: chainSize }),
    [chainSize]
  );

  return (
    <div
      className={clsx('relative inline-flex flex-shrink-0', className)}
      style={{ width, height }}
    >
      {/* Token icon */}
      <img
        className={clsx(
          'w-full h-full object-cover',
          !noRound && 'rounded-full'
        )}
        src={token.logo_url || FALLBACK_ICON}
        alt={token.display_symbol || token.symbol}
        style={{ width, height, minWidth: width }}
        onError={(e) => {
          (e.target as HTMLImageElement).src = FALLBACK_ICON;
        }}
      />
      {/* Chain badge */}
      {!hideChainIcon && chain && (
        <img
          className={clsx(
            'absolute right-0 bottom-0 rounded-full border border-white',
            chainClassName
          )}
          src={chain.logo || FALLBACK_ICON}
          alt={chain.name}
          style={chainStyle}
          onError={(e) => {
            (e.target as HTMLImageElement).src = FALLBACK_ICON;
          }}
        />
      )}
    </div>
  );
};

interface IconWithChainProps {
  iconUrl?: string;
  chainLogo?: string;
  chainName?: string;
  width?: string;
  height?: string;
  chainSize?: number;
  hideChainIcon?: boolean;
  noRound?: boolean;
  className?: string;
  chainClassName?: string;
}

export const IconWithChain: React.FC<IconWithChainProps> = ({
  iconUrl,
  chainLogo,
  chainName,
  width = '28px',
  height = '28px',
  chainSize = 14,
  hideChainIcon = false,
  noRound = false,
  className,
  chainClassName,
}) => {
  const chainStyle = useMemo(
    () => ({ width: chainSize, height: chainSize }),
    [chainSize]
  );

  return (
    <div
      className={clsx('relative inline-flex flex-shrink-0', className)}
      style={{ width, height }}
    >
      <img
        className={clsx(
          'w-full h-full object-cover',
          !noRound && 'rounded-full'
        )}
        src={iconUrl || FALLBACK_ICON}
        alt=""
        style={{ width, height, minWidth: width }}
        onError={(e) => {
          (e.target as HTMLImageElement).src = FALLBACK_ICON;
        }}
      />
      {!hideChainIcon && chainLogo && (
        <img
          className={clsx(
            'absolute right-0 bottom-0 rounded-full border border-white',
            chainClassName
          )}
          src={chainLogo}
          alt={chainName}
          style={chainStyle}
          onError={(e) => {
            (e.target as HTMLImageElement).src = FALLBACK_ICON;
          }}
        />
      )}
    </div>
  );
};
