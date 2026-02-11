/**
 * 字符串工具函数
 */

export function ensurePrefix(str = '', prefix = '/'): string {
  return str.startsWith(prefix) ? str : prefix + str;
}

export function ensureSuffix(str = '', suffix = '/'): string {
  return str.endsWith(suffix) ? str : str + suffix;
}

export function unPrefix(str = '', prefix = '/'): string {
  return str.startsWith(prefix) ? str.slice(prefix.length) : str;
}

export function unSuffix(str = '', suffix = '/'): string {
  return str.endsWith(suffix) ? str.slice(0, -suffix.length) : str;
}

export const safeJSONParse = <T = unknown>(str: string): T | null => {
  try {
    return JSON.parse(str) as T;
  } catch {
    return null;
  }
};

/**
 * Regex for input number
 * 1. Can't have more than one dot
 * 2. Can't have more than one leading zero
 * 3. Can't have non-numeric characters
 */
export const INPUT_NUMBER_RE = /^(?!0{2,})[0-9]*(?!.*\..*\.)[0-9.]*$/;

export const filterNumber = (value = ''): string => {
  return value.replace(/^0*(\d+)/, '$1').replace(/^\./, '0.');
};
