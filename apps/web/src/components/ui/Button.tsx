import React from 'react';
import clsx from 'clsx';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  fullWidth?: boolean;
  icon?: React.ReactNode;
}

const variantStyles: Record<string, string> = {
  primary:
    'bg-[var(--rabby-brand)] text-white hover:bg-[var(--rabby-brand-hover)] active:bg-[var(--rabby-brand-hover)] disabled:opacity-50',
  secondary:
    'bg-[var(--r-blue-light-1)] text-[var(--rabby-brand)] hover:bg-[var(--r-blue-light-2)] active:bg-[var(--r-blue-light-2)] disabled:opacity-50',
  danger:
    'bg-[var(--r-red-default)] text-white hover:opacity-90 active:opacity-85 disabled:opacity-50',
  ghost:
    'bg-transparent text-[var(--r-neutral-body)] hover:bg-[var(--r-neutral-bg-2)] active:bg-[var(--r-neutral-line)] disabled:opacity-50',
};

const sizeStyles: Record<string, string> = {
  sm: 'h-8 px-3 text-xs rounded-md min-w-[44px]',
  md: 'h-10 px-4 text-sm rounded-lg min-w-[44px]',
  lg: 'h-12 px-6 text-base rounded-xl min-w-[44px]',
};

const Spinner: React.FC<{ className?: string }> = ({ className }) => (
  <svg
    className={clsx('animate-spin', className)}
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
  >
    <circle
      cx="8"
      cy="8"
      r="6"
      stroke="currentColor"
      strokeOpacity="0.25"
      strokeWidth="2"
    />
    <path
      d="M14 8a6 6 0 00-6-6"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
    />
  </svg>
);

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  loading = false,
  fullWidth = false,
  disabled,
  icon,
  children,
  className,
  ...rest
}) => {
  return (
    <button
      className={clsx(
        'inline-flex items-center justify-center font-medium transition-colors',
        'focus-visible:ring-2 focus-visible:ring-[var(--rabby-brand)] focus-visible:ring-offset-2',
        variantStyles[variant],
        sizeStyles[size],
        fullWidth && 'w-full',
        (disabled || loading) && 'pointer-events-none',
        className
      )}
      disabled={disabled || loading}
      {...rest}
    >
      {loading && <Spinner className="mr-2" />}
      {!loading && icon && <span className="mr-2 flex-shrink-0">{icon}</span>}
      {children}
    </button>
  );
};
