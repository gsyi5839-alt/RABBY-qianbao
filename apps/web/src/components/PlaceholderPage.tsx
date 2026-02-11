import React from 'react';
import { useNavigate } from 'react-router-dom';

interface PlaceholderPageProps {
  title: string;
  description?: string;
  actionLabel?: string;
  actionPath?: string;
  icon?: string;
}

export default function PlaceholderPage({
  title,
  description,
  actionLabel,
  actionPath,
  icon = '?',
}: PlaceholderPageProps) {
  const navigate = useNavigate();

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        padding: '60px 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}
    >
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: 18,
          background: 'var(--r-blue-light-1, #edf0ff)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 32,
          marginBottom: 16,
        }}
      >
        {icon}
      </div>
      <h2
        style={{
          margin: 0,
          fontSize: 22,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
        }}
      >
        {title}
      </h2>
      {description && (
        <p
          style={{
            margin: '12px 0 0',
            fontSize: 14,
            color: 'var(--r-neutral-foot, #6a7587)',
            maxWidth: 520,
          }}
        >
          {description}
        </p>
      )}
      {actionLabel && actionPath && (
        <button
          onClick={() => navigate(actionPath)}
          style={{
            marginTop: 20,
            padding: '10px 20px',
            borderRadius: 8,
            border: 'none',
            background: 'var(--r-blue-default, #4c65ff)',
            color: '#fff',
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          {actionLabel}
        </button>
      )}
    </div>
  );
}
