// components/common/Skeleton/Skeleton.tsx
import clsx from 'clsx';
import styles from './Skeleton.module.css';

interface SkeletonProps {
  width?: string | number;
  height?: string | number;
  variant?: 'text' | 'rectangular' | 'circular';
  className?: string;
}

export function Skeleton({
  width = '100%',
  height = '1rem',
  variant = 'text',
  className,
}: SkeletonProps) {
  return (
    <div
      className={clsx(styles.skeleton, styles[variant], className)}
      style={{ width, height }}
      aria-hidden="true"
    />
  );
}
