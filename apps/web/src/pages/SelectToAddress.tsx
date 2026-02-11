import { useState, useMemo } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useWallet } from '../contexts/WalletContext';

const RECENT_ADDRESSES = [
  { address: '0x1234567890abcdef1234567890abcdef12345678', label: 'Friend Wallet' },
  { address: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd', label: 'Exchange Deposit' },
  { address: '0x9876543210fedcba9876543210fedcba98765432', label: '' },
];

const CONTACTS = [
  { address: '0xaabbccddee11223344556677889900aabbccddee', name: 'Alice' },
  { address: '0x112233445566778899aabbccddeeff0011223344', name: 'Bob' },
  { address: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', name: 'Treasury' },
];

function truncateAddress(addr: string) {
  return addr.slice(0, 8) + '...' + addr.slice(-6);
}

export default function SelectToAddress() {
  const navigate = useNavigate();
  const location = useLocation();
  const { accounts } = useWallet();
  const [inputAddr, setInputAddr] = useState('');

  const query = new URLSearchParams(location.search);
  const returnPath = query.get('return') || '/send-token';

  const isValidAddress = useMemo(() => {
    return /^0x[a-fA-F0-9]{40}$/.test(inputAddr);
  }, [inputAddr]);

  const selectAddress = (addr: string) => {
    const params = new URLSearchParams();
    params.set('to', addr);
    ['amount', 'chain', 'token'].forEach((k) => {
      const v = query.get(k);
      if (v) params.set(k, v);
    });
    const path = returnPath.split('?')[0];
    navigate(`${path}?${params.toString()}`, { replace: true });
  };

  const handleConfirmInput = () => {
    if (isValidAddress) {
      selectAddress(inputAddr);
    }
  };

  const addressRowStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '14px 16px',
    borderRadius: 12,
    background: 'var(--r-neutral-card-2, #f2f4f7)',
    cursor: 'pointer',
    marginBottom: 8,
    transition: 'background 0.15s',
  };

  return (
    <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 24,
        fontWeight: 600,
        color: 'var(--r-neutral-title-1, #192945)',
        marginBottom: 24,
      }}>
        Select Recipient
      </h2>

      {/* Address Search / Input */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <input
            type="text"
            placeholder="Enter address 0x..."
            value={inputAddr}
            onChange={(e) => setInputAddr(e.target.value)}
            style={{
              flex: 1,
              padding: '12px 16px',
              borderRadius: 8,
              border: inputAddr && !isValidAddress
                ? '1px solid var(--r-red-default, #ec5151)'
                : '1px solid var(--r-neutral-line, #e5e9ef)',
              outline: 'none',
              fontSize: 14,
              fontFamily: 'monospace',
              color: 'var(--r-neutral-title-1, #192945)',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
            }}
          />
          <button
            onClick={handleConfirmInput}
            disabled={!isValidAddress}
            style={{
              padding: '12px 24px',
              borderRadius: 8,
              border: 'none',
              fontSize: 14,
              fontWeight: 600,
              cursor: isValidAddress ? 'pointer' : 'not-allowed',
              color: '#fff',
              background: isValidAddress
                ? 'var(--r-blue-default, #4c65ff)'
                : 'var(--r-neutral-line, #e5e9ef)',
              flexShrink: 0,
              transition: 'background 0.2s',
            }}
          >
            Confirm
          </button>
        </div>
        {inputAddr && !isValidAddress && (
          <div style={{
            fontSize: 12,
            color: 'var(--r-red-default, #ec5151)',
            marginTop: 6,
          }}>
            Enter a valid Ethereum address
          </div>
        )}
      </div>

      {/* My Accounts */}
      {accounts.length > 0 && (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 20,
          marginBottom: 16,
        }}>
          <div style={{
            fontSize: 14,
            fontWeight: 500,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 14,
          }}>
            My Accounts
          </div>
          {accounts.map((a, i) => (
            <div
              key={i}
              onClick={() => selectAddress(a.address)}
              style={addressRowStyle}
            >
              <div>
                <div style={{
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: 'var(--r-neutral-title-1, #192945)',
                }}>
                  {truncateAddress(a.address)}
                </div>
                <div style={{
                  fontSize: 12,
                  color: 'var(--r-neutral-foot, #6a7587)',
                  marginTop: 2,
                }}>
                  {a.brandName}
                </div>
              </div>
              <div style={{
                fontSize: 12,
                color: 'var(--r-blue-default, #4c65ff)',
                fontWeight: 500,
              }}>
                Select
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Recent Addresses */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}>
        <div style={{
          fontSize: 14,
          fontWeight: 500,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 14,
        }}>
          Recent Addresses
        </div>
        {RECENT_ADDRESSES.map((item, i) => (
          <div
            key={i}
            onClick={() => selectAddress(item.address)}
            style={addressRowStyle}
          >
            <div>
              <div style={{
                fontSize: 14,
                fontFamily: 'monospace',
                color: 'var(--r-neutral-title-1, #192945)',
              }}>
                {truncateAddress(item.address)}
              </div>
              {item.label && (
                <div style={{
                  fontSize: 12,
                  color: 'var(--r-neutral-foot, #6a7587)',
                  marginTop: 2,
                }}>
                  {item.label}
                </div>
              )}
            </div>
            <div style={{
              fontSize: 12,
              color: 'var(--r-blue-default, #4c65ff)',
              fontWeight: 500,
            }}>
              Select
            </div>
          </div>
        ))}
      </div>

      {/* Contacts / Address Book */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
      }}>
        <div style={{
          fontSize: 14,
          fontWeight: 500,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 14,
        }}>
          Address Book
        </div>
        {CONTACTS.map((contact, i) => (
          <div
            key={i}
            onClick={() => selectAddress(contact.address)}
            style={addressRowStyle}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: 'var(--r-blue-default, #4c65ff)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                fontSize: 14,
                fontWeight: 600,
                flexShrink: 0,
              }}>
                {contact.name.charAt(0).toUpperCase()}
              </div>
              <div>
                <div style={{
                  fontSize: 14,
                  fontWeight: 500,
                  color: 'var(--r-neutral-title-1, #192945)',
                }}>
                  {contact.name}
                </div>
                <div style={{
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: 'var(--r-neutral-foot, #6a7587)',
                  marginTop: 2,
                }}>
                  {truncateAddress(contact.address)}
                </div>
              </div>
            </div>
            <div style={{
              fontSize: 12,
              color: 'var(--r-blue-default, #4c65ff)',
              fontWeight: 500,
            }}>
              Select
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
