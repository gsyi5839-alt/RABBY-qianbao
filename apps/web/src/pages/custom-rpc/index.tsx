import { useState } from 'react';
import { useChainContext } from '../../contexts/ChainContext';

interface CustomRpcEntry {
  chainId: number;
  chainName: string;
  rpcUrl: string;
  symbol: string;
  explorerUrl: string;
}

const INITIAL_ENTRIES: CustomRpcEntry[] = [
  { chainId: 1, chainName: 'Ethereum', rpcUrl: 'https://rpc.ankr.com/eth', symbol: 'ETH', explorerUrl: 'https://etherscan.io' },
  { chainId: 137, chainName: 'Polygon', rpcUrl: 'https://polygon-rpc.com', symbol: 'MATIC', explorerUrl: 'https://polygonscan.com' },
];

const EMPTY_FORM = { chainName: '', chainId: '', rpcUrl: '', symbol: '', explorerUrl: '' };

export default function CustomRPCPage() {
  const { chains } = useChainContext();
  const [entries, setEntries] = useState<CustomRpcEntry[]>(INITIAL_ENTRIES);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<'success' | 'error' | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<number | null>(null);

  const updateField = (field: string, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setTestResult(null);
  };

  const handleTestConnection = async () => {
    if (!form.rpcUrl) return;
    setTesting(true);
    setTestResult(null);
    try {
      const resp = await fetch(form.rpcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          method: 'eth_chainId',
          params: [],
          id: 1,
        }),
      });
      const data = await resp.json();
      if (data.result) {
        setTestResult('success');
        if (!form.chainId) {
          updateField('chainId', String(parseInt(data.result, 16)));
        }
      } else {
        setTestResult('error');
      }
    } catch {
      setTestResult('error');
    } finally {
      setTesting(false);
    }
  };

  const handleSave = () => {
    const chainId = parseInt(form.chainId, 10);
    if (!form.chainName || !chainId || !form.rpcUrl) return;

    const entry: CustomRpcEntry = {
      chainId,
      chainName: form.chainName,
      rpcUrl: form.rpcUrl,
      symbol: form.symbol || 'ETH',
      explorerUrl: form.explorerUrl,
    };

    setEntries((prev) => {
      const filtered = prev.filter((e) => e.chainId !== chainId);
      return [...filtered, entry];
    });
    setForm(EMPTY_FORM);
    setTestResult(null);
    setShowForm(false);
  };

  const handleDelete = (chainId: number) => {
    setEntries((prev) => prev.filter((e) => e.chainId !== chainId));
    setDeleteConfirm(null);
  };

  const handleSelectKnownChain = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const id = parseInt(e.target.value, 10);
    const chain = chains.find((c) => c.id === id);
    if (chain) {
      setForm((prev) => ({
        ...prev,
        chainName: chain.name,
        chainId: String(chain.id),
      }));
    }
  };

  const inputStyle: React.CSSProperties = {
    width: '100%',
    padding: '12px 16px',
    borderRadius: 8,
    border: '1px solid var(--r-neutral-line, #e5e9ef)',
    outline: 'none',
    fontSize: 14,
    color: 'var(--r-neutral-title-1, #192945)',
    background: 'var(--r-neutral-card-2, #f2f4f7)',
    boxSizing: 'border-box',
  };

  const labelStyle: React.CSSProperties = {
    fontSize: 13,
    fontWeight: 500,
    color: 'var(--r-neutral-title-1, #192945)',
    marginBottom: 6,
    display: 'block',
  };

  const isFormValid = form.chainName && form.chainId && form.rpcUrl;

  return (
    <div style={{ padding: 24, maxWidth: 700, margin: '0 auto' }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 24,
      }}>
        <h2 style={{
          fontSize: 24,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          margin: 0,
        }}>
          Custom RPC
        </h2>
        {!showForm && (
          <button
            onClick={() => setShowForm(true)}
            style={{
              padding: '10px 20px',
              borderRadius: 8,
              border: 'none',
              background: 'var(--r-blue-default, #4c65ff)',
              color: '#fff',
              fontSize: 14,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            + Add Custom RPC
          </button>
        )}
      </div>

      {/* Add RPC Form */}
      {showForm && (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 24,
          marginBottom: 16,
        }}>
          <div style={{
            fontSize: 16,
            fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 20,
          }}>
            Add Custom RPC Endpoint
          </div>

          {/* Quick select known chain */}
          {chains.length > 0 && (
            <div style={{ marginBottom: 16 }}>
              <label style={labelStyle}>Quick Select Chain</label>
              <select
                onChange={handleSelectKnownChain}
                defaultValue=""
                style={{
                  ...inputStyle,
                  cursor: 'pointer',
                }}
              >
                <option value="" disabled>Select a known chain...</option>
                {chains.map((c) => (
                  <option key={c.id} value={c.id}>{c.name} (ID: {c.id})</option>
                ))}
              </select>
            </div>
          )}

          {/* Chain Name */}
          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>Chain Name *</label>
            <input
              type="text"
              placeholder="e.g., Ethereum Mainnet"
              value={form.chainName}
              onChange={(e) => updateField('chainName', e.target.value)}
              style={inputStyle}
            />
          </div>

          {/* Chain ID */}
          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>Chain ID *</label>
            <input
              type="text"
              placeholder="e.g., 1"
              value={form.chainId}
              onChange={(e) => {
                if (/^[0-9]*$/.test(e.target.value)) updateField('chainId', e.target.value);
              }}
              style={inputStyle}
            />
          </div>

          {/* RPC URL */}
          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>RPC URL *</label>
            <input
              type="text"
              placeholder="https://..."
              value={form.rpcUrl}
              onChange={(e) => updateField('rpcUrl', e.target.value)}
              style={inputStyle}
            />
          </div>

          {/* Symbol */}
          <div style={{ marginBottom: 16 }}>
            <label style={labelStyle}>Currency Symbol</label>
            <input
              type="text"
              placeholder="e.g., ETH"
              value={form.symbol}
              onChange={(e) => updateField('symbol', e.target.value)}
              style={inputStyle}
            />
          </div>

          {/* Explorer URL */}
          <div style={{ marginBottom: 20 }}>
            <label style={labelStyle}>Block Explorer URL</label>
            <input
              type="text"
              placeholder="https://etherscan.io"
              value={form.explorerUrl}
              onChange={(e) => updateField('explorerUrl', e.target.value)}
              style={inputStyle}
            />
          </div>

          {/* Test + Result */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            marginBottom: 20,
          }}>
            <button
              onClick={handleTestConnection}
              disabled={!form.rpcUrl || testing}
              style={{
                padding: '10px 20px',
                borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #e5e9ef)',
                background: 'var(--r-neutral-card-2, #f2f4f7)',
                color: 'var(--r-neutral-title-1, #192945)',
                fontSize: 13,
                fontWeight: 600,
                cursor: !form.rpcUrl || testing ? 'not-allowed' : 'pointer',
                opacity: !form.rpcUrl || testing ? 0.5 : 1,
                transition: 'opacity 0.2s',
              }}
            >
              {testing ? 'Testing...' : 'Test Connection'}
            </button>
            {testResult === 'success' && (
              <span style={{
                fontSize: 13,
                fontWeight: 500,
                color: 'var(--r-green-default, #27c193)',
                padding: '4px 12px',
                borderRadius: 6,
                background: 'rgba(39,193,147,0.1)',
              }}>
                Connected
              </span>
            )}
            {testResult === 'error' && (
              <span style={{
                fontSize: 13,
                fontWeight: 500,
                color: 'var(--r-red-default, #ec5151)',
                padding: '4px 12px',
                borderRadius: 6,
                background: 'rgba(236,81,81,0.1)',
              }}>
                Connection Failed
              </span>
            )}
          </div>

          {/* Form Actions */}
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button
              onClick={() => { setShowForm(false); setForm(EMPTY_FORM); setTestResult(null); }}
              style={{
                padding: '10px 24px',
                borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #e5e9ef)',
                background: 'transparent',
                color: 'var(--r-neutral-foot, #6a7587)',
                fontSize: 14,
                fontWeight: 500,
                cursor: 'pointer',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={!isFormValid}
              style={{
                padding: '10px 24px',
                borderRadius: 8,
                border: 'none',
                background: isFormValid
                  ? 'var(--r-blue-default, #4c65ff)'
                  : 'var(--r-neutral-line, #e5e9ef)',
                color: '#fff',
                fontSize: 14,
                fontWeight: 600,
                cursor: isFormValid ? 'pointer' : 'not-allowed',
                transition: 'background 0.2s',
              }}
            >
              Save
            </button>
          </div>
        </div>
      )}

      {/* Existing RPC Entries List */}
      {entries.length === 0 ? (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
        }}>
          <p style={{
            fontSize: 16,
            fontWeight: 500,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 8,
          }}>
            No custom RPC endpoints
          </p>
          <p style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 13 }}>
            Add a custom RPC URL to override the default endpoint for a specific chain.
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {entries.map((entry) => (
            <div
              key={entry.chainId}
              style={{
                background: 'var(--r-neutral-card-1, #fff)',
                borderRadius: 16,
                padding: 20,
              }}
            >
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
              }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                    <span style={{
                      fontSize: 16,
                      fontWeight: 600,
                      color: 'var(--r-neutral-title-1, #192945)',
                    }}>
                      {entry.chainName}
                    </span>
                    <span style={{
                      fontSize: 11,
                      fontWeight: 500,
                      color: 'var(--r-neutral-foot, #6a7587)',
                      background: 'var(--r-neutral-card-2, #f2f4f7)',
                      padding: '2px 8px',
                      borderRadius: 4,
                    }}>
                      ID: {entry.chainId}
                    </span>
                    <span style={{
                      fontSize: 11,
                      fontWeight: 500,
                      color: 'var(--r-blue-default, #4c65ff)',
                      background: 'rgba(76,101,255,0.08)',
                      padding: '2px 8px',
                      borderRadius: 4,
                    }}>
                      {entry.symbol}
                    </span>
                  </div>
                  <div style={{
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: 'var(--r-neutral-foot, #6a7587)',
                    marginBottom: 4,
                    wordBreak: 'break-all',
                  }}>
                    RPC: {entry.rpcUrl}
                  </div>
                  {entry.explorerUrl && (
                    <div style={{
                      fontSize: 12,
                      color: 'var(--r-neutral-foot, #6a7587)',
                    }}>
                      Explorer: {entry.explorerUrl}
                    </div>
                  )}
                </div>

                {/* Delete button */}
                <div style={{ flexShrink: 0, marginLeft: 12 }}>
                  {deleteConfirm === entry.chainId ? (
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        onClick={() => handleDelete(entry.chainId)}
                        style={{
                          padding: '6px 14px',
                          borderRadius: 6,
                          border: 'none',
                          background: 'var(--r-red-default, #ec5151)',
                          color: '#fff',
                          fontSize: 12,
                          fontWeight: 600,
                          cursor: 'pointer',
                        }}
                      >
                        Delete
                      </button>
                      <button
                        onClick={() => setDeleteConfirm(null)}
                        style={{
                          padding: '6px 14px',
                          borderRadius: 6,
                          border: '1px solid var(--r-neutral-line, #e5e9ef)',
                          background: 'transparent',
                          color: 'var(--r-neutral-foot, #6a7587)',
                          fontSize: 12,
                          fontWeight: 500,
                          cursor: 'pointer',
                        }}
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => setDeleteConfirm(entry.chainId)}
                      style={{
                        padding: '6px 14px',
                        borderRadius: 6,
                        border: '1px solid var(--r-neutral-line, #e5e9ef)',
                        background: 'transparent',
                        color: 'var(--r-red-default, #ec5151)',
                        fontSize: 12,
                        fontWeight: 500,
                        cursor: 'pointer',
                      }}
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
