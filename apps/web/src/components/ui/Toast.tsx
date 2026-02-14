import React, { useEffect, useState, useCallback, useRef } from 'react';
import clsx from 'clsx';

type ToastType = 'success' | 'error' | 'warning' | 'info';
type ToastPosition = 'top' | 'bottom';

interface ToastConfig {
  message: string;
  type?: ToastType;
  duration?: number;
  position?: ToastPosition;
}

interface ToastItem extends ToastConfig {
  id: number;
}

const iconMap: Record<ToastType, React.ReactNode> = {
  success: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <circle cx="9" cy="9" r="8" stroke="currentColor" strokeWidth="1.5" />
      <path d="M5.5 9.5l2 2 5-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  error: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <circle cx="9" cy="9" r="8" stroke="currentColor" strokeWidth="1.5" />
      <path d="M6.5 6.5l5 5M11.5 6.5l-5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  warning: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M9 2l7.8 14H1.2L9 2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
      <path d="M9 7v4M9 13v.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  info: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <circle cx="9" cy="9" r="8" stroke="currentColor" strokeWidth="1.5" />
      <path d="M9 8v5M9 5.5v.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
};

const typeStyles: Record<ToastType, string> = {
  success: 'text-[var(--r-green-default)] bg-green-50',
  error: 'text-[var(--r-red-default)] bg-red-50',
  warning: 'text-amber-600 bg-amber-50',
  info: 'text-[var(--rabby-brand)] bg-[var(--r-blue-light-1)]',
};

let toastId = 0;
let addToastFn: ((config: ToastConfig) => void) | null = null;

export const toast = (config: ToastConfig | string) => {
  const cfg = typeof config === 'string' ? { message: config } : config;
  addToastFn?.(cfg);
};

toast.success = (message: string, duration?: number) =>
  toast({ message, type: 'success', duration });
toast.error = (message: string, duration?: number) =>
  toast({ message, type: 'error', duration });
toast.warning = (message: string, duration?: number) =>
  toast({ message, type: 'warning', duration });
toast.info = (message: string, duration?: number) =>
  toast({ message, type: 'info', duration });

export const ToastContainer: React.FC<{ position?: ToastPosition }> = ({
  position = 'top',
}) => {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const timersRef = useRef<Map<number, ReturnType<typeof setTimeout>>>(new Map());

  const removeToast = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    const timer = timersRef.current.get(id);
    if (timer) {
      clearTimeout(timer);
      timersRef.current.delete(id);
    }
  }, []);

  const addToast = useCallback(
    (config: ToastConfig) => {
      const id = ++toastId;
      const item: ToastItem = { ...config, id };
      setToasts((prev) => [...prev, item]);
      const timer = setTimeout(() => removeToast(id), config.duration ?? 3000);
      timersRef.current.set(id, timer);
    },
    [removeToast]
  );

  useEffect(() => {
    addToastFn = addToast;
    return () => {
      addToastFn = null;
    };
  }, [addToast]);

  return (
    <div
      className={clsx(
        'fixed left-0 right-0 z-[100] flex flex-col items-center pointer-events-none px-4 gap-2',
        position === 'top' ? 'top-[env(safe-area-inset-top,16px)] pt-4' : 'bottom-[env(safe-area-inset-bottom,16px)] pb-4'
      )}
    >
      {toasts.map((t) => (
        <div
          key={t.id}
          className={clsx(
            'flex items-center gap-2 px-4 py-3 rounded-xl shadow-md pointer-events-auto',
            'animate-[fadeIn_0.2s_ease-out] max-w-sm w-full',
            typeStyles[t.type ?? 'info']
          )}
          onClick={() => removeToast(t.id)}
        >
          <span className="flex-shrink-0">{iconMap[t.type ?? 'info']}</span>
          <span className="text-sm font-medium">{t.message}</span>
        </div>
      ))}
    </div>
  );
};
