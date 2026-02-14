/**
 * Number and currency formatting utilities.
 */

/**
 * Insert a separator every `step` digits in the integer part of a number string.
 * @param num  Number (or numeric string) to format
 * @param step Grouping size (default 3)
 * @param sep  Separator character (default ',')
 * @returns Formatted string, e.g. "1,234,567.89"
 */
export function splitNumberByStep(
  num: number | string,
  step = 3,
  sep = ',',
): string {
  const str = String(num);
  const [intPart, decPart] = str.split('.');
  const formatted = intPart.replace(
    new RegExp(`\\B(?=(\\d{${step}})+(?!\\d))`, 'g'),
    sep,
  );
  return decPart !== undefined ? `${formatted}.${decPart}` : formatted;
}

/**
 * Format a number with a given precision.
 * @param num       The number to format
 * @param precision Decimal places (default 2)
 */
export function formatNumber(num: number | string, precision = 2): string {
  const n = typeof num === 'string' ? parseFloat(num) : num;
  if (isNaN(n)) return '0';
  if (n === 0) return '0';

  // For very small numbers, show more precision
  if (Math.abs(n) < 0.01 && Math.abs(n) > 0) {
    return n.toPrecision(precision);
  }

  return splitNumberByStep(n.toFixed(precision));
}

/**
 * Format a token balance for display.
 * Large values are abbreviated (e.g. 1.23M), small values show extra precision.
 * @param amount   Token amount (in human-readable units)
 * @param decimals Decimal places to show (default 4)
 */
export function formatTokenAmount(
  amount: number | string,
  decimals = 4,
): string {
  const n = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(n)) return '0';
  if (n === 0) return '0';

  const abs = Math.abs(n);
  if (abs >= 1e9) return `${(n / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `${(n / 1e6).toFixed(2)}M`;
  if (abs >= 1e3) return splitNumberByStep(n.toFixed(2));
  if (abs < 0.0001 && abs > 0) return `< 0.0001`;

  return n.toFixed(decimals).replace(/\.?0+$/, '');
}

/**
 * Format a USD value for display (always 2 decimal places with $ prefix).
 * @param value USD value as number or string
 */
export function formatUsdValue(value: number | string): string {
  const n = typeof value === 'string' ? parseFloat(value) : value;
  if (isNaN(n)) return '$0.00';
  if (n === 0) return '$0.00';

  const abs = Math.abs(n);
  const sign = n < 0 ? '-' : '';

  if (abs >= 1e9) return `${sign}$${(abs / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `${sign}$${(abs / 1e6).toFixed(2)}M`;
  if (abs < 0.01 && abs > 0) return `${sign}< $0.01`;

  return `${sign}$${splitNumberByStep(abs.toFixed(2))}`;
}

/**
 * Format a gas price value (in Gwei).
 * @param price Gas price in wei (number or string)
 */
export function formatGasPrice(price: number | string): string {
  const n = typeof price === 'string' ? parseFloat(price) : price;
  if (isNaN(n)) return '0';

  // Convert from wei to Gwei
  const gwei = n / 1e9;

  if (gwei < 0.01 && gwei > 0) return '< 0.01';
  if (gwei >= 1000) return splitNumberByStep(Math.round(gwei));
  return gwei.toFixed(2).replace(/\.?0+$/, '');
}
