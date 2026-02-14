import React from 'react';
import clsx from 'clsx';

interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'prefix'> {
  prefix?: React.ReactNode;
  suffix?: React.ReactNode;
  error?: string;
  label?: string;
  wrapperClassName?: string;
}

export const Input: React.FC<InputProps> = ({
  prefix,
  suffix,
  error,
  label,
  disabled,
  className,
  wrapperClassName,
  ...rest
}) => {
  return (
    <div className={clsx('flex flex-col gap-1', wrapperClassName)}>
      {label && (
        <label className="text-sm font-medium text-[var(--r-neutral-body)]">
          {label}
        </label>
      )}
      <div
        className={clsx(
          'flex items-center gap-2 px-3 h-12 rounded-xl border transition-colors',
          'bg-[var(--r-neutral-bg-1)]',
          error
            ? 'border-[var(--r-red-default)]'
            : 'border-[var(--r-neutral-line)] focus-within:border-[var(--rabby-brand)]',
          disabled && 'opacity-50 cursor-not-allowed bg-[var(--r-neutral-bg-2)]'
        )}
      >
        {prefix && (
          <span className="flex-shrink-0 text-[var(--r-neutral-foot)]">
            {prefix}
          </span>
        )}
        <input
          className={clsx(
            'flex-1 h-full bg-transparent text-sm text-[var(--r-neutral-title-1)]',
            'placeholder:text-[var(--r-neutral-foot)]',
            'outline-none min-w-0',
            disabled && 'cursor-not-allowed',
            className
          )}
          disabled={disabled}
          {...rest}
        />
        {suffix && (
          <span className="flex-shrink-0 text-[var(--r-neutral-foot)]">
            {suffix}
          </span>
        )}
      </div>
      {error && (
        <p className="text-xs text-[var(--r-red-default)] mt-0.5">{error}</p>
      )}
    </div>
  );
};
