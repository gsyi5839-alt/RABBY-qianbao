/**
 * 地址相关工具函数
 */
import { isAddress as viemIsAddress } from 'viem';

export const isSameAddress = (a: string, b: string): boolean => {
  if (!a || !b) return false;
  return a.toLowerCase() === b.toLowerCase();
};

export const isAddress = (value: string): boolean => {
  return viemIsAddress(value);
};

export const resemblesETHAddress = (str: string): boolean => {
  return str.length === 42 && /^0x[0-9a-fA-F]{40}$/.test(str);
};
