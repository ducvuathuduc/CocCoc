import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: (string | false | null | undefined)[]): string {
  return twMerge(clsx(inputs));
}

const pad = (n: number): string => String(n).padStart(2, '0');

export function formatDateTime(iso: string): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(
    d.getMinutes(),
  )}`;
}

export function truncate(text: string, max = 60): string {
  const oneLine = text.replace(/\s+/g, ' ').trim();
  return oneLine.length > max ? `${oneLine.slice(0, max - 1)}…` : oneLine;
}

/** “5 phút trước” beats a timestamp for recent work; past a week the date is what people scan. */
export function timeAgo(iso: string, now: Date = new Date()): string {
  const then = new Date(iso);
  const ms = now.getTime() - then.getTime();
  if (!iso || Number.isNaN(ms)) return iso || '—';
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 1) return 'vừa xong';
  if (minutes < 60) return `${minutes} phút trước`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} giờ trước`;
  const days = Math.floor(hours / 24);
  if (days === 1) return `hôm qua ${formatDateTime(iso).slice(11)}`;
  if (days < 7) return `${days} ngày trước`;
  return formatDateTime(iso).slice(0, 10);
}

export function shortHash(value: string, length = 8): string {
  return value.slice(0, length);
}
