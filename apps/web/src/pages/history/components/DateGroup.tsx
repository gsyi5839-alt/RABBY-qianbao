import React from 'react';

interface DateGroupProps {
  /** Date label, e.g. "Today", "Yesterday", "2024-01-15" */
  label: string;
  children: React.ReactNode;
}

/**
 * Groups a list of transactions under a date header.
 * Used inside the HistoryPage to visually separate transactions by day.
 */
export const DateGroup: React.FC<DateGroupProps> = ({ label, children }) => {
  return (
    <div className="mb-2">
      <div className="sticky top-0 z-10 px-4 py-2 bg-[var(--r-neutral-bg-2)]">
        <span className="text-xs font-medium text-[var(--r-neutral-foot)]">
          {label}
        </span>
      </div>
      <div className="flex flex-col">{children}</div>
    </div>
  );
};
