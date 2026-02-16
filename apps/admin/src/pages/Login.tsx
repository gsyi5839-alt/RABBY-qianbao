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
        setError('账号或密码错误');
        return;
      }
      const data = await res.json();
      if (!data?.accessToken) {
        setError('登录失败,未获取到令牌。');
        return;
      }
      login(data.accessToken);
      navigate('/dashboard');
    } catch {
      setError('登录失败，请确认 API 服务可用。');
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
        border: '1px solid var(--r-neutral-line, var(--r-neutral-line))',
      }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            width: 56, height: 56, borderRadius: 14,
            background: 'linear-gradient(135deg, var(--r-blue-default, #4f8bff), #7aa8ff)',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 24, fontWeight: 700, marginBottom: 16,
          }}>R</div>
          <h2 style={{ margin: 0, fontSize: 22, color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))' }}>Rabby 管理后台</h2>
          <p style={{ margin: '8px 0 0', color: 'var(--r-neutral-foot, var(--r-neutral-foot))', fontSize: 14 }}>登录以管理平台</p>
        </div>

        <form onSubmit={handleSubmit}>
          {error && (
            <div style={{
              padding: '10px 14px', borderRadius: 8, marginBottom: 16,
              background: 'var(--r-red-light, #fff2f0)',
              border: '1px solid rgba(234, 57, 67, 0.35)',
              color: 'var(--r-red-default, var(--r-red-default))',
              fontSize: 13,
            }}>
              {error}
            </div>
          )}
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))', marginBottom: 6 }}>
              用户名
            </label>
            <input
              value={username} onChange={(e) => setUsername(e.target.value)}
              placeholder="请输入用户名"
              style={{
                width: '100%', padding: '10px 14px', borderRadius: 8,
                border: '1px solid var(--r-neutral-line, var(--r-neutral-line))',
                fontSize: 14,
                outline: 'none',
                boxSizing: 'border-box',
                background: 'var(--r-neutral-bg-3, var(--r-neutral-bg-2))',
                color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))',
              }}
            />
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))', marginBottom: 6 }}>
              密码
            </label>
            <input
              type="password" value={password} onChange={(e) => setPassword(e.target.value)}
              placeholder="请输入密码"
              style={{
                width: '100%', padding: '10px 14px', borderRadius: 8,
                border: '1px solid var(--r-neutral-line, var(--r-neutral-line))',
                fontSize: 14,
                outline: 'none',
                boxSizing: 'border-box',
                background: 'var(--r-neutral-bg-3, var(--r-neutral-bg-2))',
                color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))',
              }}
            />
          </div>
          <button
            type="submit" disabled={loading}
            style={{
              width: '100%', padding: '12px 0', borderRadius: 8, border: 'none',
              background: 'var(--r-blue-default, var(--r-blue-default))', color: '#fff', fontSize: 15, fontWeight: 600,
              cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.7 : 1,
            }}
          >
            {loading ? '登录中...' : '登录'}
          </button>
        </form>
      </div>
    </div>
  );
}
