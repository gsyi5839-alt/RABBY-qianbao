import React, { useEffect, useCallback } from 'react';
import clsx from 'clsx';

interface ModalProps {
  visible: boolean;
  onClose: () => void;
  title?: React.ReactNode;
  children?: React.ReactNode;
  maxHeight?: string;
  closeable?: boolean;
  className?: string;
  bodyClassName?: string;
  footer?: React.ReactNode;
}

export const Modal: React.FC<ModalProps> = ({
  visible,
  onClose,
  title,
  children,
  maxHeight = '85vh',
  closeable = true,
  className,
  bodyClassName,
  footer,
}) => {
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape' && closeable) onClose();
    },
    [closeable, onClose]
  );

  useEffect(() => {
    if (visible) {
      document.addEventListener('keydown', handleKeyDown);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = '';
    };
  }, [visible, handleKeyDown]);

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 transition-opacity"
        onClick={closeable ? onClose : undefined}
      />
      {/* Panel */}
      <div
        className={clsx(
          'relative w-full sm:max-w-md bg-[var(--r-neutral-bg-1)] shadow-xl',
          'rounded-t-2xl sm:rounded-2xl',
          'animate-[slideUp_0.25s_ease-out]',
          className
        )}
        style={{ maxHeight }}
      >
        {/* Header */}
        {(title || closeable) && (
          <div className="flex items-center justify-between px-5 pt-5 pb-3">
            <h3 className="text-base font-semibold text-[var(--r-neutral-title-1)] truncate">
              {title}
            </h3>
            {closeable && (
              <button
                onClick={onClose}
                className="ml-auto flex items-center justify-center w-8 h-8 rounded-full
                  hover:bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-foot)]
                  transition-colors min-w-[44px] min-h-[44px]"
              >
                <CloseIcon />
              </button>
            )}
          </div>
        )}
        {/* Body */}
        <div
          className={clsx('px-5 pb-5 overflow-y-auto', bodyClassName)}
          style={{ maxHeight: `calc(${maxHeight} - 120px)` }}
        >
          {children}
        </div>
        {/* Footer */}
        {footer && (
          <div className="px-5 pb-5 pt-2 border-t border-[var(--r-neutral-line)]">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
};

const CloseIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path
      d="M5 5l10 10M15 5L5 15"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
    />
  </svg>
);
