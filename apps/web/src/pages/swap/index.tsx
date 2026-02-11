import React from 'react';
import SwapForm from './components/SwapForm';

export default function SwapPage() {
  return (
    <div>
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        Swap
      </h2>
      <SwapForm />
    </div>
  );
}
