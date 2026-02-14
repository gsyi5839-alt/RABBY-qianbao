import React from 'react';
import clsx from 'clsx';

interface MainLayoutProps {
  children: React.ReactNode;
  className?: string;
  header?: React.ReactNode;
  footer?: React.ReactNode;
  noPadding?: boolean;
}

export const MainLayout: React.FC<MainLayoutProps> = ({
  children,
  className,
  header,
  footer,
  noPadding = false,
}) => {
  return (
    <div
      className={clsx(
        'flex flex-col min-h-screen bg-[var(--r-neutral-bg-2)]',
        'max-w-screen-sm mx-auto',
        className
      )}
    >
      {/* Safe area top */}
      <div className="h-[env(safe-area-inset-top,0px)]" />

      {/* Header */}
      {header && (
        <div className="flex-shrink-0 bg-[var(--r-neutral-bg-1)]">
          {header}
        </div>
      )}

      {/* Content */}
      <main
        className={clsx(
          'flex-1 overflow-y-auto',
          !noPadding && 'px-4 py-4'
        )}
      >
        {children}
      </main>

      {/* Footer */}
      {footer && (
        <div className="flex-shrink-0 bg-[var(--r-neutral-bg-1)] border-t border-[var(--r-neutral-line)]">
          {footer}
        </div>
      )}

      {/* Safe area bottom */}
      <div className="h-[env(safe-area-inset-bottom,0px)]" />
    </div>
  );
};
