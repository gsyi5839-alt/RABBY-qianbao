import React from 'react';
import clsx from 'clsx';

interface EmptyProps {
  description?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}

const DefaultIcon = () => (
  <svg
    width="64"
    height="64"
    viewBox="0 0 64 64"
    fill="none"
    className="text-[var(--r-neutral-line)]"
  >
    <rect
      x="8"
      y="16"
      width="48"
      height="36"
      rx="4"
      stroke="currentColor"
      strokeWidth="2"
    />
    <path
      d="M8 38l14-10 8 6 12-14 14 10"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <circle cx="22" cy="26" r="3" stroke="currentColor" strokeWidth="2" />
  </svg>
);

export const Empty: React.FC<EmptyProps> = ({
  description = 'No data',
  icon,
  action,
  className,
}) => {
  return (
    <div
      className={clsx(
        'flex flex-col items-center justify-center py-16 px-6',
        className
      )}
    >
      <div className="mb-4">{icon || <DefaultIcon />}</div>
      <p className="text-sm text-[var(--r-neutral-foot)] text-center mb-4">
        {description}
      </p>
      {action && <div>{action}</div>}
    </div>
  );
};
