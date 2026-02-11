/**
 * URL 相关工具函数
 */

export const getOriginFromUrl = (url: string): string => {
  try {
    const urlObj = new URL(url);
    return urlObj.origin;
  } catch {
    return '';
  }
};

/**
 * @param url (exchange.pancakeswap.finance/blabla)
 * @returns (pancakeswap.finance)
 */
export const getMainDomain = (url: string): string => {
  try {
    const origin = getOriginFromUrl(url);
    const arr = origin.split('.');
    const mainDomainWithPath = [arr[arr.length - 2], arr[arr.length - 1]].join(
      '.'
    );
    return mainDomainWithPath.replace(/^https?:\/\//, '');
  } catch {
    return '';
  }
};
