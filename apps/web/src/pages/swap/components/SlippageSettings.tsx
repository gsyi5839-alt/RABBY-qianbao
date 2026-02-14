import React, { useCallback, useState } from 'react';
import clsx from 'clsx';

interface SlippageSettingsProps {
  slippage: number;
  onSlippageChange: (value: number) => void;
  presets: number[];
  autoSlippage: boolean;
  onAutoSlippageChange: (auto: boolean) => void;
  isCustom: boolean;
  onCustomChange: (custom: boolean) => void;
  className?: string;
}

export const SlippageSettings: React.FC<SlippageSettingsProps> = ({
  slippage,
  onSlippageChange,
  presets,
  autoSlippage,
  onAutoSlippageChange,
  isCustom,
  onCustomChange,
  className,
}) => {
  const [customValue, setCustomValue] = useState(
    isCustom ? String(slippage) : ''
  );

  const handlePresetClick = useCallback(
    (value: number) => {
      onSlippageChange(value);
      onCustomChange(false);
      onAutoSlippageChange(false);
    },
    [onSlippageChange, onCustomChange, onAutoSlippageChange]
  );

  const handleCustomChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const val = e.target.value;
      if (val === '' || /^\d*\.?\d*$/.test(val)) {
        setCustomValue(val);
        const num = parseFloat(val);
        if (!isNaN(num) && num > 0 && num <= 50) {
          onSlippageChange(num);
          onCustomChange(true);
          onAutoSlippageChange(false);
        }
      }
    },
    [onSlippageChange, onCustomChange, onAutoSlippageChange]
  );

  const handleAutoToggle = useCallback(() => {
    onAutoSlippageChange(!autoSlippage);
    if (!autoSlippage) {
      onCustomChange(false);
    }
  }, [autoSlippage, onAutoSlippageChange, onCustomChange]);

  const isHighSlippage = slippage > 5;
  const isLowSlippage = slippage < 0.05;

  return (
    <div className={clsx('flex flex-col gap-3', className)}>
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
          Slippage Tolerance
        </span>
        <button
          onClick={handleAutoToggle}
          className={clsx(
            'flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium',
            'transition-colors min-h-[28px]',
            autoSlippage
              ? 'bg-[var(--r-blue-light-1)] text-[var(--rabby-brand)]'
              : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-foot)]'
          )}
        >
          Auto
        </button>
      </div>

      {!autoSlippage && (
        <div className="flex items-center gap-2">
          {presets.map((value) => (
            <button
              key={value}
              onClick={() => handlePresetClick(value)}
              className={clsx(
                'flex-1 h-9 rounded-lg text-sm font-medium transition-colors',
                'min-h-[36px]',
                !isCustom && slippage === value
                  ? 'bg-[var(--rabby-brand)] text-white'
                  : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-body)] hover:bg-[var(--r-neutral-line)]'
              )}
            >
              {value}%
            </button>
          ))}

          <div
            className={clsx(
              'flex items-center flex-1 h-9 rounded-lg px-2',
              'border transition-colors',
              isCustom
                ? 'border-[var(--rabby-brand)] bg-[var(--r-blue-light-1)]'
                : 'border-[var(--r-neutral-line)] bg-[var(--r-neutral-bg-2)]'
            )}
          >
            <input
              type="text"
              inputMode="decimal"
              value={customValue}
              onChange={handleCustomChange}
              placeholder="Custom"
              className={clsx(
                'w-full text-sm font-medium bg-transparent outline-none text-center',
                'text-[var(--r-neutral-title-1)] placeholder:text-[var(--r-neutral-foot)]'
              )}
              onFocus={() => {
                if (!isCustom) {
                  setCustomValue('');
                }
              }}
            />
            <span className="text-sm text-[var(--r-neutral-foot)] ml-0.5">
              %
            </span>
          </div>
        </div>
      )}

      {/* Warnings */}
      {isHighSlippage && !autoSlippage && (
        <p className="text-xs text-[var(--r-orange-default)]">
          High slippage may result in an unfavorable trade
        </p>
      )}
      {isLowSlippage && !autoSlippage && (
        <p className="text-xs text-[var(--r-orange-default)]">
          Slippage is too low, your transaction may fail
        </p>
      )}
    </div>
  );
};
