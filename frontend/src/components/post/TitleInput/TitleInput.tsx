// components/post/TitleInput/TitleInput.tsx
import styles from './TitleInput.module.css';

interface TitleInputProps {
  value: string;
  onChange: (value: string) => void;
  error?: string;
  onValidate?: () => void;
  isLoading?: boolean;
}

export function TitleInput({
  value,
  onChange,
  error,
  onValidate,
  isLoading,
}: TitleInputProps) {
  return (
    <div className={styles.titleGroup}>
      <input
        type="text"
        className={`${styles.titleInput} ${error ? styles.hasError : ''} ${isLoading ? styles.loading : ''}`}
        placeholder="記事のタイトル"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onBlur={onValidate}
        readOnly={isLoading}
      />
      {error && <p className={styles.errorMessage}>{error}</p>}
    </div>
  );
}
