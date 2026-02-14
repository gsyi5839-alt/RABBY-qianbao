/**
 * Time / date formatting utilities.
 */

const MINUTE = 60;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;
const MONTH = 30 * DAY;
const YEAR = 365 * DAY;

/**
 * Return a human-readable "time since" string.
 * @param timestamp Unix timestamp in **seconds** (not milliseconds)
 * @returns e.g. "3 minutes ago", "2 hours ago", "5 days ago"
 */
export function sinceTime(timestamp: number): string {
  const now = Math.floor(Date.now() / 1000);
  const diff = now - timestamp;

  if (diff < 0) return 'just now';
  if (diff < MINUTE) return 'just now';
  if (diff < HOUR) {
    const m = Math.floor(diff / MINUTE);
    return `${m} minute${m > 1 ? 's' : ''} ago`;
  }
  if (diff < DAY) {
    const h = Math.floor(diff / HOUR);
    return `${h} hour${h > 1 ? 's' : ''} ago`;
  }
  if (diff < WEEK) {
    const d = Math.floor(diff / DAY);
    return `${d} day${d > 1 ? 's' : ''} ago`;
  }
  if (diff < MONTH) {
    const w = Math.floor(diff / WEEK);
    return `${w} week${w > 1 ? 's' : ''} ago`;
  }
  if (diff < YEAR) {
    const mo = Math.floor(diff / MONTH);
    return `${mo} month${mo > 1 ? 's' : ''} ago`;
  }

  const y = Math.floor(diff / YEAR);
  return `${y} year${y > 1 ? 's' : ''} ago`;
}

/**
 * Format a timestamp to a date/time string.
 * @param timestamp Unix timestamp in **seconds** (not milliseconds)
 * @param format    Format string.
 *   - 'YYYY-MM-DD' (default)
 *   - 'YYYY-MM-DD HH:mm'
 *   - 'YYYY-MM-DD HH:mm:ss'
 *   - 'MM/DD/YYYY'
 *   - 'HH:mm'
 */
export function formatTime(
  timestamp: number,
  format: string = 'YYYY-MM-DD',
): string {
  const date = new Date(timestamp * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');

  const YYYY = String(date.getFullYear());
  const MM = pad(date.getMonth() + 1);
  const DD = pad(date.getDate());
  const HH = pad(date.getHours());
  const mm = pad(date.getMinutes());
  const ss = pad(date.getSeconds());

  return format
    .replace('YYYY', YYYY)
    .replace('MM', MM)
    .replace('DD', DD)
    .replace('HH', HH)
    .replace('mm', mm)
    .replace('ss', ss);
}
