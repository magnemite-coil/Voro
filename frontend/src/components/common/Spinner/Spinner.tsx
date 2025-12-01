// components/common/Spinner/Spinner.tsx
import styles from './Spinner.module.css';

interface SpinnerProps {
  size?: 'small' | 'medium' | 'large';
}

const SPINNER_SIZES = {
  small: '16px',
  medium: '24px',
  large: '40px',
} as const;

export function Spinner({ size = 'medium' }: SpinnerProps) {
  return (
    <span
      className={styles.spinner}
      style={{
        width: SPINNER_SIZES[size],
        height: SPINNER_SIZES[size],
      }}
      aria-label="読み込み中"
    />
  );
}
