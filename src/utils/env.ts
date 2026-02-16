import browser from 'webextension-polyfill';

export const getSentryEnv = () => {
  let environment = 'production';

  if (process.env.DEBUG) {
    environment = 'debug';
  }

  if (process.env.NODE_ENV === 'development') {
    environment = 'development';
  }

  return environment;
};

export const appIsDebugPkg =
  `${process.env.DEBUG}` === 'true' && process.env.BUILD_ENV === 'PRO';

export const __DEV__ = process.env.NODE_ENV === 'development';
export const appIsProd = process.env.NODE_ENV === 'production';
export const appIsDev = !appIsProd;

// In unit tests `webextension-polyfill` may be partially mocked.
const manifest = browser?.runtime?.getManifest?.();
export const isManifestV3 = manifest?.manifest_version === 3;
