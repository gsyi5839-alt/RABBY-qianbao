import React, { useMemo } from 'react';
import clsx from 'clsx';
import { formatUsdValue } from '../../../utils';

type GasSpeed = 'slow' | 'normal' | 'fast';

interface GasLevel {
  level: GasSpeed;
  price: number;
  estimatedSeconds?: number;
}

interface GasFeeBarProps {
  gasLevels?: GasLevel[];
  selectedLevel?: GasSpeed;
  onSelectLevel?: (level: GasSpeed) => void;
  gasLimit?: number;
  nativeTokenPrice?: number;
  nativeTokenSymbol?: string;
  isLoading?: boolean;
  className?: string;
}

const SPEED_LABELS: Record<GasSpeed, string> = {
  slow: 'Slow',
  normal: 'Standard',
  fast: 'Fast',
};

const SPEED_ICONS: Record<GasSpeed, string> = {
  slow: '\u{1F422}',
  normal: '\u{2699}\u{FE0F}',
  fast: '\u{26A1}',
};

export const GasFeeBar: React.FC<GasFeeBarProps> = ({
  gasLevels,
  selectedLevel = 'normal',
  onSelectLevel,
  gasLimit = 21000,
  nativeTokenPrice = 0,
  nativeTokenSymbol = 'ETH',
  isLoading = false,
  className,
}) => {
  const selectedGas = useMemo(() => {
    return gasLevels?.find((g) => g.level === selectedLevel);
  }, [gasLevels, selectedLevel]);

  const gasFeeInToken = useMemo(() => {
    if (!selectedGas) return 0;
    return (selectedGas.price * gasLimit) / 1e18;
  }, [selectedGas, gasLimit]);

  const gasFeeInUsd = useMemo(() => {
    return gasFeeInToken * nativeTokenPrice;
  }, [gasFeeInToken, nativeTokenPrice]);

  if (isLoading) {
    return (
      <div className={clsx('px-4 py-3', className)}>
        <div className="flex items-center justify-between">
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Estimated Gas Fee
          </span>
          <div className="h-4 w-20 bg-[var(--r-neutral-line)] rounded animate-pulse" />
        </div>
      </div>
    );
  }

  if (!gasLevels || gasLevels.length === 0) {
    return (
      <div className={clsx('px-4 py-3', className)}>
        <div className="flex items-center justify-between">
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Estimated Gas Fee
          </span>
          <span className="text-xs text-[var(--r-neutral-foot)]">--</span>
        </div>
      </div>
    );
  }

  return (
    <div className={clsx('px-4 py-3', className)}>
      {/* Gas fee summary */}
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-[var(--r-neutral-foot)]">
          Estimated Gas Fee
        </span>
        <div className="flex items-center gap-1">
          <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
            {gasFeeInToken.toFixed(6)} {nativeTokenSymbol}
          </span>
          <span className="text-xs text-[var(--r-neutral-foot)]">
            ({formatUsdValue(gasFeeInUsd)})
          </span>
        </div>
      </div>

      {/* Speed selector */}
      {onSelectLevel && (
        <div className="flex gap-2">
          {gasLevels.map((gas) => (
            <button
              key={gas.level}
              className={clsx(
                'flex-1 flex flex-col items-center py-2 rounded-lg',
                'border transition-colors min-h-[44px]',
                gas.level === selectedLevel
                  ? 'border-[var(--rabby-brand)] bg-[var(--r-blue-light-1)]'
                  : 'border-[var(--r-neutral-line)] hover:border-[var(--r-neutral-foot)]'
              )}
              onClick={() => onSelectLevel(gas.level)}
            >
              <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
                {SPEED_LABELS[gas.level]}
              </span>
              <span className="text-[10px] text-[var(--r-neutral-foot)]">
                {((gas.price * gasLimit) / 1e18).toFixed(5)} {nativeTokenSymbol}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
};
