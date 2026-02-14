import React, { useEffect, useMemo, useState } from 'react';
import { getStats, type StatsResponse } from '../services/admin';

const FALLBACK_STATS: StatsResponse = {
  totalUsers: 12345,
  totalAddresses: 45678,
  registrationByDay: {},
};

const formatNumber = (value: number) => value.toLocaleString();

const RECENT_EVENTS = [
  { time: '2min ago', user: 'admin', action: 'Updated ETH chain RPC config', type: 'config' },
  { time: '15min ago', user: 'admin', action: 'Added new phishing address', type: 'security' },
  { time: '1h ago', user: 'system', action: 'Detected anomalous API call', type: 'alert' },
  { time: '3h ago', user: 'admin', action: 'Updated security rule: large transfer', type: 'security' },
  { time: '6h ago', user: 'system', action: 'BSC RPC health check failed', type: 'alert' },
];

const CHAIN_USAGE = [
  { name: 'Ethereum', pct: 45, color: '#627EEA' },
  { name: 'Arbitrum', pct: 25, color: '#28A0F0' },
  { name: 'BSC', pct: 15, color: '#F0B90B' },
  { name: 'Polygon', pct: 10, color: '#8247E5' },
  { name: 'Other', pct: 5, color: '#ccc' },
];

export default function DashboardPage() {
  const [stats, setStats] = useState<StatsResponse | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setLoading(true);
    getStats()
      .then((res) => setStats(res))
      .catch(() => setStats(FALLBACK_STATS))
      .finally(() => setLoading(false));
  }, []);

  const statCards = useMemo(() => [
    { label: 'Total Users', value: formatNumber(stats?.totalUsers ?? FALLBACK_STATS.totalUsers), change: '+12%', icon: 'US', color: 'var(--r-blue-default, #4c65ff)' },
    { label: 'Total Addresses', value: formatNumber(stats?.totalAddresses ?? FALLBACK_STATS.totalAddresses), change: '+8%', icon: 'AD', color: 'var(--r-green-default, #2abb7f)' },
    { label: 'Transactions', value: '89,012', change: '+15%', icon: 'TX', color: 'var(--r-orange-default, #ffb020)' },
    { label: 'Total Assets', value: '$50M', change: '+5%', icon: 'AS', color: 'var(--r-blue-default, #4c65ff)' },
  ], [stats]);

  return (
    <div>
      <h2 style={{ margin: '0 0 24px', fontSize: 22, color: 'var(--r-neutral-title-1, #192945)' }}>Dashboard</h2>

      {/* Stat Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, marginBottom: 24 }}>
        {statCards.map((stat) => (
          <div key={stat.label} style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 12,
            padding: '20px 24px',
            boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
            border: '1px solid var(--r-neutral-line, #f0f0f0)',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>{stat.label}</span>
              <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.08em', color: 'var(--r-neutral-foot, #6a7587)' }}>{stat.icon}</span>
            </div>
            <div style={{ fontSize: 28, fontWeight: 700, color: stat.color, marginBottom: 4 }}>{stat.value}</div>
            <span style={{ fontSize: 12, color: 'var(--r-green-default, #2abb7f)', fontWeight: 500 }}>
              {loading ? 'Loading...' : `${stat.change} vs last week`}
            </span>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 24 }}>
        {/* Chain Usage */}
        <div style={{ background: 'var(--r-neutral-card-1, #fff)', borderRadius: 12, padding: 24, boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))', border: '1px solid var(--r-neutral-line, #f0f0f0)' }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>Chain Usage</h3>
          {CHAIN_USAGE.map((chain) => (
            <div key={chain.name} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4, fontSize: 13 }}>
                <span style={{ color: 'var(--r-neutral-body, #3e495e)' }}>{chain.name}</span>
                <span style={{ color: 'var(--r-neutral-foot, #6a7587)' }}>{chain.pct}%</span>
              </div>
              <div style={{ height: 8, background: 'var(--r-neutral-bg-3, #f0f2f5)', borderRadius: 4, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${chain.pct}%`, background: chain.color, borderRadius: 4 }} />
              </div>
            </div>
          ))}
        </div>

        {/* Recent Events */}
        <div style={{ background: 'var(--r-neutral-card-1, #fff)', borderRadius: 12, padding: 24, boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))', border: '1px solid var(--r-neutral-line, #f0f0f0)' }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>Recent Events</h3>
          {RECENT_EVENTS.map((event, i) => (
            <div key={i} style={{
              display: 'flex', gap: 10, padding: '10px 0',
              borderBottom: i < RECENT_EVENTS.length - 1 ? '1px solid var(--r-neutral-line, #f0f0f0)' : 'none',
            }}>
              <span style={{
                width: 8, height: 8, borderRadius: '50%', marginTop: 5, flexShrink: 0,
                background: event.type === 'alert'
                  ? 'var(--r-red-default, #ff4d4f)'
                  : event.type === 'security'
                    ? 'var(--r-orange-default, #faad14)'
                    : 'var(--r-blue-default, #4c65ff)',
              }} />
              <div>
                <div style={{ fontSize: 13, color: 'var(--r-neutral-body, #3e495e)' }}>
                  <strong>{event.user}</strong> {event.action}
                </div>
                <div style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)', marginTop: 2 }}>{event.time}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
