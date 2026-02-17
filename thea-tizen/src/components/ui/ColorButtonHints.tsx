/**
 * Color Button Hints
 * Shows TV remote color button shortcuts at bottom of screen
 */

import { ReactNode } from 'react';

export interface ColorButtonHint {
  color: 'red' | 'green' | 'yellow' | 'blue';
  label: string;
  icon?: ReactNode;
}

export interface ColorButtonHintsProps {
  hints: ColorButtonHint[];
  className?: string;
}

const colorStyles = {
  red: 'bg-red-600',
  green: 'bg-green-600',
  yellow: 'bg-yellow-500',
  blue: 'bg-blue-600',
};

const colorTextStyles = {
  red: 'text-red-400',
  green: 'text-green-400',
  yellow: 'text-yellow-400',
  blue: 'text-blue-400',
};

export function ColorButtonHints({ hints, className = '' }: ColorButtonHintsProps) {
  if (hints.length === 0) return null;

  return (
    <div
      className={`
        fixed bottom-0 left-0 right-0
        bg-gray-900/95 backdrop-blur-sm
        border-t border-gray-700
        px-8 py-3
        flex justify-center gap-12
        ${className}
      `}
    >
      {hints.map((hint) => (
        <div key={hint.color} className="flex items-center gap-3">
          {/* Color dot */}
          <div
            className={`
              w-6 h-6 rounded-full
              ${colorStyles[hint.color]}
              shadow-lg
            `}
          />
          {/* Label */}
          <span className={`text-lg font-medium ${colorTextStyles[hint.color]}`}>
            {hint.icon && <span className="mr-2">{hint.icon}</span>}
            {hint.label}
          </span>
        </div>
      ))}
    </div>
  );
}

/**
 * Common hint configurations
 */
// eslint-disable-next-line react-refresh/only-export-components
export const CommonHints = {
  chat: [
    { color: 'red' as const, label: 'Cancel' },
    { color: 'green' as const, label: 'Send' },
    { color: 'yellow' as const, label: 'Options' },
    { color: 'blue' as const, label: 'Voice' },
  ],

  trakt: [
    { color: 'red' as const, label: 'Cancel Check-in' },
    { color: 'green' as const, label: 'Check In' },
    { color: 'yellow' as const, label: 'History' },
    { color: 'blue' as const, label: 'Search' },
  ],

  navigation: [
    { color: 'red' as const, label: 'Back' },
    { color: 'green' as const, label: 'Select' },
    { color: 'yellow' as const, label: 'Menu' },
    { color: 'blue' as const, label: 'Info' },
  ],

  confirmation: [
    { color: 'red' as const, label: 'No' },
    { color: 'green' as const, label: 'Yes' },
  ],
};
