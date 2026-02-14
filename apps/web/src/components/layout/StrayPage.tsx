import React from 'react';
import clsx from 'clsx';
import { Loading } from '../ui/Loading';

interface StrayHeaderProps {
  title?: string;
  secondTitle?: string;
  subTitle?: string;
  center?: boolean;
  className?: string;
}

interface StrayPageProps {
  header?: StrayHeaderProps;
  headerClassName?: string;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
  spinning?: boolean;
  noPadding?: boolean;
  style?: React.CSSProperties;
}

const StrayHeader: React.FC<StrayHeaderProps & { className?: string }> = ({
  title,
  secondTitle,
  subTitle,
  center = false,
  className,
}) => (
  <div className={clsx(className, center && 'text-center')}>
    {title && (
      <h1 className="text-xl font-bold text-[var(--r-neutral-title-1)]">
        {title}
      </h1>
    )}
    {secondTitle && (
      <h2 className="text-xl font-medium text-[var(--r-neutral-title-1)]">
        {secondTitle}
      </h2>
    )}
    {subTitle && (
      <p className="text-sm text-[var(--r-neutral-foot)] mt-2">{subTitle}</p>
    )}
  </div>
);

export const StrayPage: React.FC<StrayPageProps> = ({
  header,
  headerClassName,
  children,
  footer,
  className,
  spinning = false,
  noPadding = false,
  style,
}) => {
  return (
    <div
      className={clsx(
        'relative flex flex-col min-h-screen bg-[var(--r-neutral-bg-2)]',
        'max-w-screen-sm mx-auto',
        className
      )}
      style={style}
    >
      {spinning && (
        <div className="absolute inset-0 flex items-center justify-center bg-[var(--r-neutral-bg-2)]/80 z-20">
          <Loading size="lg" />
        </div>
      )}

      <div
        className={clsx(
          'flex-1 flex flex-col',
          !noPadding && 'px-5 pt-8'
        )}
      >
        {/* Safe area top */}
        <div className="h-[env(safe-area-inset-top,0px)]" />

        {header && (
          <StrayHeader
            className={headerClassName || 'mb-8'}
            {...header}
          />
        )}

        {children && (
          <div className="flex-1 flex flex-col">{children}</div>
        )}
      </div>

      {footer && (
        <div className="flex-shrink-0 px-5 py-5 bg-[var(--r-neutral-bg-1)] border-t border-[var(--r-neutral-line)]">
          {/* Safe area bottom */}
          {footer}
          <div className="h-[env(safe-area-inset-bottom,0px)]" />
        </div>
      )}
    </div>
  );
};
