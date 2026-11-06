'use client';

import { useSyncExternalStore } from 'react';
import { Toaster } from 'sonner';

type Theme = 'light' | 'dark';

const KEY = 'cms-theme';
const listeners = new Set<() => void>();

function read(): Theme {
  return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  // A second tab that flips the theme writes the same storage key.
  window.addEventListener('storage', onChange);
  return () => {
    listeners.delete(onChange);
    window.removeEventListener('storage', onChange);
  };
}

function write(theme: Theme) {
  const root = document.documentElement;
  // The class swap alone repaints every surface at once; one beat of
  // `.theme-anim` turns that into a crossfade instead of a hard cut.
  root.classList.add('theme-anim');
  root.classList.toggle('dark', theme === 'dark');
  root.style.colorScheme = theme;
  window.setTimeout(() => root.classList.remove('theme-anim'), 360);
  try {
    localStorage.setItem(KEY, theme);
  } catch {
    // Private mode / disabled storage: the theme still applies for this page.
  }
  for (const notify of listeners) notify();
}

function useTheme(): Theme {
  return useSyncExternalStore(subscribe, read, () => 'light');
}

export function ThemeToggle() {
  const theme = useTheme();

  // Both icons ship in the markup and CSS picks the visible one off `.dark`,
  // because the pre-paint script in the document head already flipped <html>
  // before React hydrated.
  return (
    <button
      type="button"
      onClick={() => write(theme === 'dark' ? 'light' : 'dark')}
      aria-label={theme === 'dark' ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối'}
      className="flex h-8 w-full items-center justify-center rounded-lg border border-line bg-elevated text-fg-3 hover:border-primary/40 hover:bg-primary-soft hover:text-primary-text active:scale-[0.98]"
    >
      <span className="relative block h-4 w-4">
        <svg
          viewBox="0 0 24 24"
          className="t-sun absolute inset-0 size-4"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
        <svg
          viewBox="0 0 24 24"
          className="t-moon absolute inset-0 size-4"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
        </svg>
      </span>
      <span className="ml-2 text-xs">{theme === 'dark' ? 'Nền tối' : 'Nền sáng'}</span>
    </button>
  );
}

export function ThemedToaster() {
  const theme = useTheme();
  // Bottom-right: a top-right toast sat on top of the sticky "Lưu" button and ate the next click.
  return <Toaster position="bottom-right" richColors closeButton theme={theme} />;
}
