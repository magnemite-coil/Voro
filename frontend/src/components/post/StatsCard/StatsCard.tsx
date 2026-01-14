// components/post/StatsCard/StatsCard.tsx
import styles from './StatsCard.module.css';

interface StatsCardProps {
  label: string;
  value: number;
}

export function StatsCard({ label, value }: StatsCardProps) {
  return (
    <div className={styles.card}>
      <span className={styles.label}>{label}</span>
      <span className={styles.value}>{value.toLocaleString()}</span>
    </div>
  );
}
