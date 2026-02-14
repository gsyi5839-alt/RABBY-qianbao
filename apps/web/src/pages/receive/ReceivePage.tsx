import React, { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCurrentAccount } from '../../hooks';
import { useChain } from '../../hooks';
import { PageHeader } from '../../components/layout';
import { toast } from '../../components/ui';
import { QRCodeSVG } from './QRCodeSVG';

export const ReceivePage: React.FC = () => {
  const navigate = useNavigate();
  const { address: currentAddress } = useCurrentAccount();
  const { currentChainInfo } = useChain();
  const [copied, setCopied] = useState(false);

  const displayAddress = currentAddress || '';

  const handleBack = useCallback(() => {
    navigate(-1);
  }, [navigate]);

  const handleCopy = useCallback(async () => {
    if (!displayAddress) return;
    try {
      await navigator.clipboard.writeText(displayAddress);
      setCopied(true);
      toast('Address copied');
      setTimeout(() => setCopied(false), 2000);
    } catch {
      const textarea = document.createElement('textarea');
      textarea.value = displayAddress;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      setCopied(true);
      toast('Address copied');
      setTimeout(() => setCopied(false), 2000);
    }
  }, [displayAddress]);

  const handleShare = useCallback(async () => {
    if (!displayAddress) return;
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'My Wallet Address',
          text: displayAddress,
        });
      } catch {
        // User cancelled or share failed
      }
    } else {
      handleCopy();
    }
  }, [displayAddress, handleCopy]);

  return (
    <div className="min-h-screen bg-[var(--r-blue-default)] flex flex-col">
      <PageHeader
        title="Receive"
        onBack={handleBack}
        className="text-white [&_svg]:text-white [&_h1]:text-white"
      />

      <div className="flex-1 flex flex-col items-center px-6 pt-4">
        {/* Chain info */}
        <div className="mb-4 text-center">
          <p className="text-white/80 text-sm mb-2">Receive on</p>
          <div className="inline-flex items-center gap-2 px-3 py-1.5
            bg-white/20 rounded-full text-white text-sm font-medium">
            {currentChainInfo?.logo && (
              <img src={currentChainInfo.logo} alt="" className="w-4 h-4 rounded-full" />
            )}
            <span>{currentChainInfo?.name || 'All EVM Chains'}</span>
          </div>
        </div>

        {/* QR Card */}
        <div className="w-full max-w-[320px] bg-white rounded-2xl p-6 shadow-lg">
          <div className="flex justify-center mb-4">
            {displayAddress ? (
              <QRCodeSVG value={displayAddress} size={200} />
            ) : (
              <div className="w-[200px] h-[200px] bg-gray-100 rounded-xl flex items-center justify-center">
                <span className="text-gray-400 text-sm">No address</span>
              </div>
            )}
          </div>

          <div className="text-center mb-4">
            <p className="text-xs text-gray-500 font-mono break-all leading-5 px-2">
              {displayAddress}
            </p>
          </div>

          <button
            className="w-full flex items-center justify-center gap-2
              h-11 rounded-xl bg-[var(--r-blue-default)] text-white
              text-sm font-medium active:opacity-90 min-h-[44px]"
            onClick={handleCopy}
          >
            <CopyIcon />
            {copied ? 'Copied!' : 'Copy Address'}
          </button>
        </div>

        {/* Warning */}
        <div className="mt-4 px-4 py-3 bg-white/10 rounded-xl max-w-[320px] w-full">
          <div className="flex gap-2">
            <WarningIcon className="flex-shrink-0 mt-0.5" />
            <p className="text-white/70 text-xs leading-4">
              Only send compatible EVM tokens to this address.
              Sending unsupported tokens may result in permanent loss.
            </p>
          </div>
        </div>

        {/* Share button */}
        {typeof navigator.share === 'function' && (
          <button
            className="mt-4 flex items-center gap-2 px-6 h-10 rounded-full
              bg-white/20 text-white text-sm font-medium min-h-[44px]"
            onClick={handleShare}
          >
            <ShareIcon />
            Share
          </button>
        )}
      </div>

      {/* Footer */}
      <div className="flex justify-center pb-6 pt-4 opacity-50">
        <img
          src="/images/logo-white.svg"
          className="h-7"
          alt="Rabby"
          onError={(e) => {
            (e.target as HTMLImageElement).style.display = 'none';
          }}
        />
      </div>
    </div>
  );
};

const CopyIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <rect x="5.5" y="5.5" width="8" height="8" rx="1.5" stroke="currentColor" strokeWidth="1.2" />
    <path d="M10.5 5.5V3.5A1.5 1.5 0 009 2H3.5A1.5 1.5 0 002 3.5V9a1.5 1.5 0 001.5 1.5h2" stroke="currentColor" strokeWidth="1.2" />
  </svg>
);

const WarningIcon: React.FC<{ className?: string }> = ({ className }) => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className={className}>
    <path d="M7 1L13 12H1L7 1z" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round" fill="none" className="text-yellow-400" />
    <path d="M7 5v3" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" className="text-yellow-400" />
    <circle cx="7" cy="10" r="0.5" fill="currentColor" className="text-yellow-400" />
  </svg>
);

const ShareIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path d="M8 2v8M4 6l4-4 4 4M3 10v2a2 2 0 002 2h6a2 2 0 002-2v-2" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
