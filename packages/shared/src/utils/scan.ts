/**
 * 区块链浏览器链接工具
 */

export const getAddressScanLink = (scanLink: string, address: string): string => {
  if (/transaction\/_s_/.test(scanLink)) {
    return scanLink.replace(/transaction\/_s_/, `address/${address}`);
  }
  if (/tx\/_s_/.test(scanLink)) {
    return scanLink.replace(/tx\/_s_/, `address/${address}`);
  }
  return scanLink.endsWith('/')
    ? `${scanLink}address/${address}`
    : `${scanLink}/address/${address}`;
};

export const getTxScanLink = (scanLink: string, hash: string): string => {
  if (scanLink.includes('_s_')) {
    return scanLink.replace('_s_', hash);
  }
  return scanLink.endsWith('/')
    ? `${scanLink}tx/${hash}`
    : `${scanLink}/tx/${hash}`;
};
