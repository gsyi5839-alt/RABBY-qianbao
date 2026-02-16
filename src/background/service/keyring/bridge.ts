import { KEYRING_CLASS } from '@/constant';
import { isManifestV3 } from '@/utils/env';

const getImKeyBridge = () =>
  isManifestV3
    ? require('./eth-imkey-keyring/imkey-offscreen-bridge')
    : require('./eth-imkey-keyring/imkey-bridge');

const getOneKeyBridge = () =>
  isManifestV3
    ? require('./eth-onekey-keyring/onekey-offscreen-bridge')
    : require('./eth-onekey-keyring/onekey-bridge');

const getTrezorBridge = () =>
  isManifestV3
    ? require('./eth-trezor-keyring/trezor-offscreen-bridge')
    : require('@rabby-wallet/eth-trezor-keyring/dist/trezor-bridge');

// BitBox02 depends on `bitbox-api` which may not be present in unit-test environments.
// Load it lazily so unrelated tests (and non-BitBox users) won't fail at module import time.
const getBitBox02Bridge = () =>
  isManifestV3
    ? require('./eth-bitbox02-keyring/bitbox02-offscreen-bridge')
    : require('./eth-bitbox02-keyring/bitbox02-bridge');

export const getKeyringBridge = async (type: string) => {
  if (type === KEYRING_CLASS.HARDWARE.IMKEY) {
    const Mod = await getImKeyBridge();
    return new Mod.default();
  }

  if (type === KEYRING_CLASS.HARDWARE.ONEKEY) {
    const Mod = await getOneKeyBridge();
    return new Mod.default();
  }

  if (type === KEYRING_CLASS.HARDWARE.TREZOR) {
    const Mod = await getTrezorBridge();
    return new Mod.default();
  }

  if (type === KEYRING_CLASS.HARDWARE.BITBOX02) {
    const Mod = await getBitBox02Bridge();
    return new Mod.default();
  }

  return;
};

export const hasBridge = async (type: string) => {
  return !!(await getKeyringBridge(type));
};
