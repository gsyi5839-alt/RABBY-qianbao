import React, { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Copy } from 'ui/component';
import './style.less';
import { InfoCircleOutlined } from '@ant-design/icons';
import QRCode from 'qrcode.react';
import { Button } from 'antd';
import { useHistory, useLocation } from 'react-router-dom';
import IconCopy from 'ui/assets/component/icon-copy.svg';
import IconMaskIcon from '@/ui/assets/create-mnemonics/mask-lock.svg';
import { ReactComponent as IconRcMask } from '@/ui/assets/create-mnemonics/mask-lock.svg';
import clsx from 'clsx';

const AddressBackupPrivateKey: React.FC<{
  isInModal?: boolean;
  onClose?(): void;
}> = ({ isInModal, onClose }) => {
  const { t } = useTranslation();
  const history = useHistory();
  const location = useLocation<{
    data: string;
  }>();
  const { state } = location;

  // Keep secret out of history state (and thus out of back/forward cache) once page is mounted.
  const [privateKey] = useState<string | null>(() => state?.data ?? null);
  const [masked, setMasked] = useState(true);
  const [isShowPrivateKey, setIsShowPrivateKey] = useState(false);
  const sanitizedLocationStateRef = useRef(false);

  useEffect(() => {
    if (!privateKey) {
      if (isInModal) {
        onClose?.();
      } else {
        history.goBack();
      }
    }
  }, [privateKey, history, isInModal]);

  useEffect(() => {
    // Sanitize history state to avoid leaving the secret in memory across navigation.
    if (sanitizedLocationStateRef.current) return;
    if (!state?.data) return;
    sanitizedLocationStateRef.current = true;
    const nextState = { ...(state as any) };
    delete nextState.data;
    history.replace({ ...location, state: nextState });
  }, [history, location, state]);

  useEffect(() => {
    const remask = () => {
      setMasked(true);
      setIsShowPrivateKey(false);
    };
    const onVisibilityChange = () => {
      if (document.visibilityState !== 'visible') remask();
    };
    window.addEventListener('blur', remask);
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      window.removeEventListener('blur', remask);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, []);

  if (!privateKey) {
    return null;
  }
  return (
    <div
      className={clsx(
        'page-address-backup',
        isInModal ? 'min-h-0 h-[600px]' : ''
      )}
    >
      <header>{t('page.backupPrivateKey.title')}</header>
      <div className="alert mb-[20px]">
        <InfoCircleOutlined />
        {t('page.backupPrivateKey.alert')}
      </div>
      <div className="qrcode mb-[32px] relative">
        <div
          className={clsx('mask', !masked && 'hidden')}
          onClick={() => {
            setMasked(false);
          }}
        >
          <img src={IconMaskIcon} className="w-[44px] h-[44px]" />
          <p className="mt-[16px] mb-0 text-white px-[15px]">
            {t('page.backupPrivateKey.clickToShowQr')}
          </p>
        </div>
        {masked ? (
          // Do not render sensitive QR into DOM until user explicitly reveals.
          <div className="w-[180px] h-[180px] rounded-[12px] bg-r-neutral-card-2" />
        ) : (
          <QRCode value={privateKey} size={180}></QRCode>
        )}
      </div>
      <div className="private-key mb-[24px]">
        {!isShowPrivateKey ? (
          <div
            className="private-key-mask"
            onClick={() => {
              setIsShowPrivateKey(true);
            }}
          >
            <IconRcMask width={20} height={20} viewBox="0 0 44 44"></IconRcMask>
            {t('page.backupPrivateKey.clickToShow')}
          </div>
        ) : (
          <p className="private-key-text">{privateKey}</p>
        )}
        {isShowPrivateKey ? (
          <Copy
            icon={IconCopy}
            data={privateKey}
            className="icon-copy"
          ></Copy>
        ) : null}
      </div>

      <div className="footer pb-[20px]">
        <Button
          type="primary"
          size="large"
          className="w-full"
          onClick={() => history.goBack()}
        >
          {t('global.Done')}
        </Button>
      </div>
    </div>
  );
};

export default AddressBackupPrivateKey;
