import React from 'react';
import clsx from 'clsx';
import { useNavigate } from 'react-router-dom';

interface PageHeaderProps {
  children?: React.ReactNode;
  title?: React.ReactNode;
  canBack?: boolean;
  onBack?: () => void;
  rightSlot?: React.ReactNode;
  fixed?: boolean;
  closeable?: boolean;
  onClose?: () => void;
  className?: string;
  contentClassName?: string;
}

export const PageHeader: React.FC<PageHeaderProps> = ({
  children,
  title,
  canBack = true,
  onBack,
  rightSlot,
  fixed = false,
  closeable = false,
  onClose,
  className,
  contentClassName,
}) => {
  const navigate = useNavigate();

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      navigate(-1);
    }
  };

  const handleClose = () => {
    if (onClose) {
      onClose();
    } else {
      navigate(-1);
    }
  };

  const content = (
    <div
      className={clsx(
        'flex items-center h-14 px-4 gap-2',
        contentClassName
      )}
    >
      {/* Back button */}
      {canBack && (
        <button
          onClick={handleBack}
          className="flex items-center justify-center w-8 h-8 -ml-1
            text-[var(--r-neutral-title-1)] min-w-[44px] min-h-[44px]"
        >
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path
              d="M13 4l-6 6 6 6"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      )}

      {/* Title / children */}
      <div className="flex-1 min-w-0 flex items-center justify-center">
        {title ? (
          <h1 className="text-base font-semibold text-[var(--r-neutral-title-1)] truncate">
            {title}
          </h1>
        ) : (
          children
        )}
      </div>

      {/* Right slot */}
      {rightSlot && <div className="flex-shrink-0">{rightSlot}</div>}

      {/* Close button */}
      {closeable && (
        <button
          onClick={handleClose}
          className="flex items-center justify-center w-8 h-8
            text-[var(--r-neutral-foot)] min-w-[44px] min-h-[44px]"
        >
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path
              d="M5 5l10 10M15 5L5 15"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
          </svg>
        </button>
      )}

      {/* Spacer when no right slot and no close */}
      {!rightSlot && !closeable && canBack && <div className="w-8" />}
    </div>
  );

  if (fixed) {
    return (
      <div
        className={clsx(
          'fixed top-0 left-0 right-0 z-40 bg-[var(--r-neutral-bg-1)]',
          className
        )}
      >
        {content}
      </div>
    );
  }

  return <div className={className}>{content}</div>;
};
