import React from 'react';
import clsx from 'clsx';

interface LoadingProps {
  size?: 'sm' | 'md' | 'lg';
  className?: string;
  color?: string;
}

interface LoadingOverlayProps {
  visible: boolean;
  children?: React.ReactNode;
  text?: string;
}

const sizes: Record<string, string> = {
  sm: 'w-5 h-5',
  md: 'w-8 h-8',
  lg: 'w-12 h-12',
};

export const Loading: React.FC<LoadingProps> = ({
  size = 'md',
  className,
  color,
}) => {
  return (
    <svg
      className={clsx('animate-spin', sizes[size], className)}
      viewBox="0 0 24 24"
      fill="none"
      style={color ? { color } : undefined}
    >
      <circle
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeOpacity="0.2"
        strokeWidth="3"
      />
      <path
        d="M22 12a10 10 0 00-10-10"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
      />
    </svg>
  );
};

export const LoadingOverlay: React.FC<LoadingOverlayProps> = ({
  visible,
  children,
  text,
}) => {
  if (!visible) return <>{children}</>;

  return (
    <div className="relative">
      {children}
      <div className="absolute inset-0 flex flex-col items-center justify-center bg-[var(--r-neutral-bg-1)]/80 z-10 rounded-xl">
        <Loading size="lg" />
        {text && (
          <p className="mt-3 text-sm text-[var(--r-neutral-foot)]">{text}</p>
        )}
      </div>
    </div>
  );
};
