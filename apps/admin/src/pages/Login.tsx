import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export default function LoginPage() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';
      const res = await fetch(`${apiUrl}/api/admin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      if (!res.ok) {
        setError('Invalid credentials. Try admin/admin');
        return;
      }
      const data = await res.json();
      if (!data?.accessToken) {
        setError('Login failed. Missing token.');
        return;
      }
      login(data.accessToken);
      navigate('/dashboard');
    } catch {
      setError('Login failed. Please ensure the API server is running.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'radial-gradient(900px 450px at 20% 10%, rgba(79, 139, 255, 0.25), transparent 55%), var(--r-neutral-bg-2, #0b0e11)',
    }}>
      <div style={{
        width: 400,
        padding: 40,
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        boxShadow: 'var(--rabby-shadow-lg, 0 20px 60px rgba(0,0,0,0.15))',
        border: '1px solid var(--r-neutral-line, #f0f0f0)',
      }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            width: 56, height: 56, borderRadius: 14,
            background: 'linear-gradient(135deg, var(--r-blue-default, #4f8bff), #7aa8ff)',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 24, fontWeight: 700, marginBottom: 16,
          }}>R</div>
          <h2 style={{ margin: 0, fontSize: 22, color: 'var(--r-neutral-title-1, #192945)' }}>Rabby Admin</h2>
          <p style={{ margin: '8px 0 0', color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>Sign in to manage your platform</p>
        </div>

        <form onSubmit={handleSubmit}>
          {error && (
            <div style={{
              padding: '10px 14px', borderRadius: 8, marginBottom: 16,
              background: 'var(--r-red-light, #fff2f0)',
              border: '1px solid rgba(234, 57, 67, 0.35)',
              color: 'var(--r-red-default, #cf1322)',
              fontSize: 13,
            }}>
              {error}
            </div>
          )}
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 6 }}>
              Username
            </label>
            <input
              value={username} onChange={(e) => setUsername(e.target.value)}
              placeholder="admin"
              style={{
                width: '100%', padding: '10px 14px', borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #d9d9d9)',
                fontSize: 14,
                outline: 'none',
                boxSizing: 'border-box',
                background: 'var(--r-neutral-bg-3, #f2f4f7)',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            />
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 6 }}>
              Password
            </label>
            <input
              type="password" value={password} onChange={(e) => setPassword(e.target.value)}
              placeholder="\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022"
              style={{
                width: '100%', padding: '10px 14px', borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #d9d9d9)',
                fontSize: 14,
                outline: 'none',
                boxSizing: 'border-box',
                background: 'var(--r-neutral-bg-3, #f2f4f7)',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            />
          </div>
          <button
            type="submit" disabled={loading}
            style={{
              width: '100%', padding: '12px 0', borderRadius: 8, border: 'none',
              background: 'var(--r-blue-default, #4c65ff)', color: '#fff', fontSize: 15, fontWeight: 600,
              cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.7 : 1,
            }}
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
