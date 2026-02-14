import React, { useEffect, useRef, useCallback } from 'react';
import clsx from 'clsx';

interface PopupProps {
  visible: boolean;
  onClose: () => void;
  title?: React.ReactNode;
  children?: React.ReactNode;
  height?: string;
  closeable?: boolean;
  className?: string;
}

export const Popup: React.FC<PopupProps> = ({
  visible,
  onClose,
  title,
  children,
  height = '60vh',
  closeable = true,
  className,
}) => {
  const startY = useRef<number>(0);
  const currentY = useRef<number>(0);
  const panelRef = useRef<HTMLDivElement>(null);

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    startY.current = e.touches[0].clientY;
  }, []);

  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    currentY.current = e.touches[0].clientY;
    const diff = currentY.current - startY.current;
    if (diff > 0 && panelRef.current) {
      panelRef.current.style.transform = `translateY(${diff}px)`;
    }
  }, []);

  const handleTouchEnd = useCallback(() => {
    const diff = currentY.current - startY.current;
    if (diff > 100 && closeable) {
      onClose();
    }
    if (panelRef.current) {
      panelRef.current.style.transform = '';
    }
    startY.current = 0;
    currentY.current = 0;
  }, [closeable, onClose]);

  useEffect(() => {
    if (visible) {
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [visible]);

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={closeable ? onClose : undefined}
      />
      {/* Panel */}
      <div
        ref={panelRef}
        className={clsx(
          'relative w-full bg-[var(--r-neutral-bg-1)]',
          'rounded-t-2xl shadow-xl',
          'transition-transform',
          'animate-[slideUp_0.25s_ease-out]',
          className
        )}
        style={{ height, maxHeight: '90vh' }}
      >
        {/* Drag handle */}
        <div
          className="flex justify-center pt-2 pb-1 cursor-grab"
          onTouchStart={handleTouchStart}
          onTouchMove={handleTouchMove}
          onTouchEnd={handleTouchEnd}
        >
          <div className="w-9 h-1 rounded-full bg-[var(--r-neutral-line)]" />
        </div>

        {/* Header */}
        {(title || closeable) && (
          <div className="flex items-center justify-between px-5 pb-3">
            <h3 className="text-base font-semibold text-[var(--r-neutral-title-1)]">
              {title}
            </h3>
            {closeable && (
              <button
                onClick={onClose}
                className="flex items-center justify-center w-8 h-8 rounded-full
                  hover:bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-foot)]
                  min-w-[44px] min-h-[44px]"
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
          </div>
        )}

        {/* Body */}
        <div className="px-5 pb-5 overflow-y-auto" style={{ height: 'calc(100% - 80px)' }}>
          {children}
        </div>
      </div>
    </div>
  );
};
