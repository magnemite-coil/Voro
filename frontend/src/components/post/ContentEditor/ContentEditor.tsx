// components/post/ContentEditor/ContentEditor.tsx
import styles from './ContentEditor.module.css';

interface ContentEditorProps {
  value: string;
  onChange: (value: string) => void;
  error?: string;
  onValidate?: () => void;
  isLoading?: boolean;
}

export function ContentEditor({
  value,
  onChange,
  error,
  onValidate,
  isLoading,
}: ContentEditorProps) {
  return (
    <div className={styles.contentGroup}>
      <textarea
        className={`${styles.contentEditor} ${error ? styles.hasError : ''} ${isLoading ? styles.loading : ''}`}
        placeholder="Markdownで本文を書く..."
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onBlur={onValidate}
        rows={20}
        readOnly={isLoading}
      />
      {error && <p className={styles.errorMessage}>{error}</p>}
    </div>
  );
}
