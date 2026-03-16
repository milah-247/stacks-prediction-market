interface SpinnerProps {
  size?: number;
  color?: string;
  label?: string;
}

export function LoadingSpinner({ size = 24, color = 'var(--accent-electric)', label }: SpinnerProps) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
      <div style={{
        width: size,
        height: size,
        borderRadius: '50%',
        border: `2px solid var(--border-subtle)`,
        borderTop: `2px solid ${color}`,
        animation: 'spin 0.8s linear infinite',
      }} />
      {label && (
        <div style={{ fontSize: '12px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
          {label}
        </div>
      )}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
