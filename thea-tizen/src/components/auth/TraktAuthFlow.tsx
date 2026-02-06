/**
 * Trakt Authentication Flow Component
 *
 * Device code authentication for TV:
 * 1. Show activation code
 * 2. Display QR code for easy mobile access
 * 3. Poll for completion
 * 4. Show success/error state
 */

import React, { useState, useEffect, useCallback } from 'react';
import { useFocusable, FocusContext } from '@noriginmedia/norigin-spatial-navigation';
import { traktAuthService, AuthState, DeviceCode } from '../../services/trakt/TraktAuthService';
import './TraktAuthFlow.css';

interface TraktAuthFlowProps {
  onComplete?: () => void;
  onCancel?: () => void;
}

export const TraktAuthFlow: React.FC<TraktAuthFlowProps> = ({ onComplete, onCancel }) => {
  const [authState, setAuthState] = useState<AuthState>({ status: 'idle' });
  const [deviceCode, setDeviceCode] = useState<DeviceCode | null>(null);
  const [timeRemaining, setTimeRemaining] = useState<number>(0);

  const { ref, focusKey } = useFocusable({
    focusable: true,
    saveLastFocusedChild: true,
  });

  // Subscribe to auth state changes
  useEffect(() => {
    const unsub = traktAuthService.onStateChange(setAuthState);
    return unsub;
  }, []);

  // Start auth flow
  const startAuth = useCallback(async () => {
    try {
      const code = await traktAuthService.startDeviceAuth();
      setDeviceCode(code);
      setTimeRemaining(code.expires_in);
    } catch (error) {
      console.error('Failed to start auth', error);
    }
  }, []);

  // Countdown timer
  useEffect(() => {
    if (authState.status !== 'waiting_for_user' || !deviceCode) return;

    const timer = setInterval(() => {
      setTimeRemaining(prev => {
        if (prev <= 1) {
          clearInterval(timer);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [authState.status, deviceCode]);

  // Handle success
  useEffect(() => {
    if (authState.status === 'success' && onComplete) {
      setTimeout(onComplete, 2000);
    }
  }, [authState.status, onComplete]);

  const handleCancel = useCallback(() => {
    traktAuthService.cancelAuth();
    onCancel?.();
  }, [onCancel]);

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="trakt-auth-flow">
        <div className="auth-container">
          {/* Header */}
          <div className="auth-header">
            <img
              src="https://trakt.tv/assets/logos/header@2x-a87e43d60b0d9cb87e27a13c69a217e8.png"
              alt="Trakt"
              className="trakt-logo"
            />
            <h1>Connect to Trakt</h1>
            <p>Track what you watch automatically</p>
          </div>

          {/* Content based on state */}
          <div className="auth-content">
            {authState.status === 'idle' && (
              <div className="auth-start">
                <p>Connect your Trakt account to:</p>
                <ul className="benefits-list">
                  <li>📊 Track your watch history</li>
                  <li>📅 Get episode reminders</li>
                  <li>⭐ Sync ratings & lists</li>
                  <li>🎯 Personal recommendations</li>
                </ul>
                <FocusableButton
                  label="Connect Account"
                  primary
                  onPress={startAuth}
                />
              </div>
            )}

            {authState.status === 'requesting_code' && (
              <div className="auth-loading">
                <div className="spinner" />
                <p>Getting activation code...</p>
              </div>
            )}

            {authState.status === 'waiting_for_user' && deviceCode && (
              <div className="auth-code">
                <div className="code-instructions">
                  <p>Visit this URL on your phone or computer:</p>
                  <div className="url-box">
                    <span className="url">{deviceCode.verification_url}</span>
                  </div>
                </div>

                <div className="code-display">
                  <p>Enter this code:</p>
                  <div className="activation-code">
                    {deviceCode.user_code.split('').map((char, i) => (
                      <span key={i} className="code-char">{char}</span>
                    ))}
                  </div>
                </div>

                <div className="qr-section">
                  <p>Or scan this QR code:</p>
                  <div className="qr-placeholder">
                    {/* In a real app, generate a QR code for the URL + code */}
                    <span className="qr-text">QR Code</span>
                  </div>
                </div>

                <div className="timer">
                  <span className="timer-icon">⏱️</span>
                  <span className="timer-text">
                    Code expires in {formatTime(timeRemaining)}
                  </span>
                </div>

                <div className="waiting-indicator">
                  <div className="pulse-ring" />
                  <span>Waiting for authorization...</span>
                </div>
              </div>
            )}

            {authState.status === 'success' && (
              <div className="auth-success">
                <div className="success-icon">✓</div>
                <h2>Connected!</h2>
                <p>
                  Welcome, <strong>{authState.user.username}</strong>
                </p>
                {authState.user.vip && (
                  <span className="vip-badge">⭐ VIP</span>
                )}
              </div>
            )}

            {authState.status === 'expired' && (
              <div className="auth-error">
                <div className="error-icon">⏰</div>
                <h2>Code Expired</h2>
                <p>The activation code has expired. Please try again.</p>
                <FocusableButton
                  label="Try Again"
                  primary
                  onPress={startAuth}
                />
              </div>
            )}

            {authState.status === 'error' && (
              <div className="auth-error">
                <div className="error-icon">❌</div>
                <h2>Error</h2>
                <p>{authState.error}</p>
                <FocusableButton
                  label="Try Again"
                  primary
                  onPress={startAuth}
                />
              </div>
            )}
          </div>

          {/* Footer */}
          {(authState.status === 'idle' ||
            authState.status === 'waiting_for_user' ||
            authState.status === 'error' ||
            authState.status === 'expired') && (
            <div className="auth-footer">
              <FocusableButton
                label="Cancel"
                onPress={handleCancel}
              />
            </div>
          )}
        </div>
      </div>
    </FocusContext.Provider>
  );
};

interface FocusableButtonProps {
  label: string;
  primary?: boolean;
  onPress: () => void;
}

const FocusableButton: React.FC<FocusableButtonProps> = ({ label, primary, onPress }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: onPress,
  });

  return (
    <button
      ref={ref}
      className={`auth-button ${focused ? 'focused' : ''} ${primary ? 'primary' : ''}`}
      onClick={onPress}
    >
      {label}
    </button>
  );
};

export default TraktAuthFlow;
