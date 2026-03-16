import { useState, useEffect } from 'react';

interface ToastProps {
  message: string;
  type?: 'success' | 'error' | 'info';
  duration?: number;
  onClose?: () => void;
}

export function Toast({ message, type = 'info', duration = 4000, onClose }: ToastProps) {
  const [visible, setVisible] = useState(true);
  const colors = {
    success: 'var(--accent-green)',
    error: 'var(--accent-red)',
    info: 'var(--accent-electric)',
  };

  useEffect(() => {
    const timer = setTimeout(() => { setVisible(false); onClose?.(); }, duration);
    return () => clearTimeout(timer);
  }, [duration, onClose]);

  if (!visible) return null;
  return (
    <div style={{
      position: 'fixed', bottom: '24px', right: '24px', zIndex: 1000,
      background: 'var(--bg-card)', border: `1px solid ${colors[type]}`,
      borderRadius: 'var(--radius-md)', padding: '14px 20px',
      fontSize: '13px', color: colors[type], maxWidth: '360px',
      boxShadow: `0 0 20px ${colors[type]}33`,
      animation: 'slideIn 0.3s ease forwards',
    }}>
      {message}
    </div>
  );
}
