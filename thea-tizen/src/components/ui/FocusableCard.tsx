/**
 * TV-Focusable Card Component
 * Provides visual feedback for focus state on TV
 */

import { ReactNode } from 'react';
import { useFocusable, FocusableComponentLayout } from '@noriginmedia/norigin-spatial-navigation';
import { TV_UI } from '../../config/constants';

export interface FocusableCardProps {
  children: ReactNode;
  onEnterPress?: () => void;
  onFocus?: (layout: FocusableComponentLayout) => void;
  onBlur?: () => void;
  className?: string;
  focusKey?: string;
  disabled?: boolean;
  /** Extra padding for TV (default true) */
  tvPadding?: boolean;
  /** Show focus ring (default true) */
  showRing?: boolean;
  /** Scale on focus (default true) */
  scaleOnFocus?: boolean;
}

export function FocusableCard({
  children,
  onEnterPress,
  onFocus,
  onBlur,
  className = '',
  focusKey,
  disabled = false,
  tvPadding = true,
  showRing = true,
  scaleOnFocus = true,
}: FocusableCardProps) {
  const { ref, focused, focusSelf } = useFocusable({
    focusKey,
    onEnterPress,
    onFocus,
    onBlur,
    focusable: !disabled,
  });

  const focusStyles = focused
    ? `${scaleOnFocus ? 'scale-105' : ''} ${showRing ? 'ring-4 ring-blue-500' : ''} shadow-lg shadow-blue-500/20`
    : '';

  const paddingStyles = tvPadding ? 'p-4' : '';

  return (
    <div
      ref={ref}
      onClick={focusSelf}
      className={`
        transition-all duration-200
        rounded-lg cursor-pointer
        ${paddingStyles}
        ${focusStyles}
        ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
        ${className}
      `}
      style={{
        transform: focused && scaleOnFocus ? `scale(${TV_UI.FOCUS_SCALE})` : 'scale(1)',
      }}
      tabIndex={disabled ? -1 : 0}
      aria-disabled={disabled}
    >
      {children}
    </div>
  );
}

/**
 * Simple focusable button
 */
export interface FocusableButtonProps {
  children: ReactNode;
  onClick?: () => void;
  className?: string;
  focusKey?: string;
  disabled?: boolean;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
}

export function FocusableButton({
  children,
  onClick,
  className = '',
  focusKey,
  disabled = false,
  variant = 'primary',
  size = 'md',
}: FocusableButtonProps) {
  const { ref, focused } = useFocusable({
    focusKey,
    onEnterPress: onClick,
    focusable: !disabled,
  });

  const variantStyles = {
    primary: 'bg-blue-600 text-white',
    secondary: 'bg-gray-700 text-white',
    danger: 'bg-red-600 text-white',
    ghost: 'bg-transparent text-white',
  };

  const sizeStyles = {
    sm: 'px-4 py-2 text-lg',
    md: 'px-6 py-3 text-xl',
    lg: 'px-8 py-4 text-2xl',
  };

  return (
    <button
      ref={ref}
      onClick={onClick}
      disabled={disabled}
      className={`
        rounded-lg font-medium
        transition-all duration-200
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${focused ? 'ring-4 ring-white/50 scale-105' : ''}
        ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
        ${className}
      `}
      tabIndex={disabled ? -1 : 0}
    >
      {children}
    </button>
  );
}

/**
 * Focusable list container
 */
export interface FocusableListProps {
  children: ReactNode;
  className?: string;
  focusKey?: string;
  direction?: 'horizontal' | 'vertical';
}

export function FocusableList({
  children,
  className = '',
  focusKey,
  direction = 'vertical',
}: FocusableListProps) {
  const { ref } = useFocusable({
    focusKey,
    focusable: false,
    saveLastFocusedChild: true,
    trackChildren: true,
  });

  return (
    <div
      ref={ref}
      className={`
        flex
        ${direction === 'horizontal' ? 'flex-row gap-4 overflow-x-auto' : 'flex-col gap-2'}
        ${className}
      `}
    >
      {children}
    </div>
  );
}
