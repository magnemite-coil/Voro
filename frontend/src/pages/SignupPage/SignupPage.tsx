// pages/SignupPage/SignupPage.tsx
import { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router';
import clsx from 'clsx';
import { useAuth } from '../../contexts/AuthContext';
import { useNotification } from '../../contexts/NotificationContext';
import { Button } from '../../components/common/Button/Button';
import { ApiError, formatErrorMessage } from '../../services/api';
import authStyles from '../../styles/auth-form.module.css';

// パスワード表示トグル用アイコン
function EyeIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

function EyeOffIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
      <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
      <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
      <line x1="1" y1="1" x2="23" y2="23" />
    </svg>
  );
}

// フィールド別エラー状態の型
interface FieldErrors {
  username?: string;
  email?: string;
  password?: string;
  general?: string;
}

// サーバーエラーをフィールド別に分類
// 複数フィールド名が含まれる場合は general に分類（WCAG SC 3.3.1 対応）
function categorizeError(message: string): FieldErrors {
  // 大文字小文字を無視するため、小文字化して判定
  const lowerMessage = message.toLowerCase();

  // フィールド名の出現数をカウント
  const fieldCount = [
    lowerMessage.includes('username'),
    lowerMessage.includes('email'),
    lowerMessage.includes('password'),
  ].filter(Boolean).length;

  // 複数フィールドに関連するエラーは general
  if (fieldCount >= 2) return { general: message };

  // 単一フィールドに関連するエラーは該当フィールドに表示
  if (lowerMessage.includes('username')) return { username: message };
  if (lowerMessage.includes('email')) return { email: message };
  if (lowerMessage.includes('password')) return { password: message };

  return { general: message };
}

export function SignupPage() {
  const { signup, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { showNotification } = useNotification();

  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  // フィールド別エラー状態（WCAG SC 3.3.1 対応）
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [passwordMismatch, setPasswordMismatch] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // パスワード表示トグル状態
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // リダイレクト先を決定（LoginPage と同じパターン）
  // 保護されたページから来た場合はそこに戻り、それ以外は /posts/new へ
  const from =
    (location.state as { from?: Location })?.from?.pathname || '/posts/new';

  // 認証済みならリダイレクト
  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true });
    }
  }, [isAuthenticated, navigate, from]);

  // フォーム送信可能かどうか（空チェックのみ）
  // すべてのフィールドで trim() 後に判定（LoginPageとの一貫性）
  // 注意: 送信時にはパスワードをトリムしない
  const canSubmit =
    username.trim() &&
    email.trim() &&
    password.trim() &&
    confirmPassword.trim();

  // 確認パスワードからフォーカスアウト時のチェック
  const handleConfirmPasswordBlur = () => {
    if (confirmPassword && password !== confirmPassword) {
      setPasswordMismatch(true);
    } else {
      setPasswordMismatch(false);
    }
  };

  // パスワード変更時にミスマッチ状態をリセット
  const handlePasswordChange = (value: string) => {
    setPassword(value);
    if (passwordMismatch && value === confirmPassword) {
      setPasswordMismatch(false);
    }
    // パスワードフィールドとgeneralエラーをクリア
    if (fieldErrors.password || fieldErrors.general) {
      setFieldErrors((prev) => ({
        ...prev,
        password: undefined,
        general: undefined,
      }));
    }
  };

  const handleConfirmPasswordChange = (value: string) => {
    setConfirmPassword(value);
    if (passwordMismatch && password === value) {
      setPasswordMismatch(false);
    }
  };

  // ユーザー名変更時にエラーをクリア
  const handleUsernameChange = (value: string) => {
    setUsername(value);
    if (fieldErrors.username || fieldErrors.general) {
      setFieldErrors((prev) => ({
        ...prev,
        username: undefined,
        general: undefined,
      }));
    }
  };

  // メール変更時にエラーをクリア
  const handleEmailChange = (value: string) => {
    setEmail(value);
    if (fieldErrors.email || fieldErrors.general) {
      setFieldErrors((prev) => ({
        ...prev,
        email: undefined,
        general: undefined,
      }));
    }
  };

  const handleFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFieldErrors({});

    // 送信時にもパスワード一致チェック
    if (password !== confirmPassword) {
      setPasswordMismatch(true);
      return;
    }

    // 送信前にトリム処理（ユーザー名・メールのみ、パスワードはそのまま）
    const trimmedUsername = username.trim();
    const trimmedEmail = email.trim();

    setIsLoading(true);

    try {
      await signup(trimmedUsername, trimmedEmail, password);
      showNotification('success', 'アカウントを作成しました');
      navigate(from, { replace: true });
    } catch (err) {
      if (err instanceof ApiError) {
        // formatErrorMessage で 500 エラー時に error_id を含めて表示
        // フィールド別に分類して該当箇所に表示
        setFieldErrors(categorizeError(formatErrorMessage(err)));
      } else {
        setFieldErrors({ general: 'アカウントの作成に失敗しました' });
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className={authStyles.container}>
      <h1 className={authStyles.title}>サインアップ</h1>
      <form onSubmit={handleFormSubmit} className={authStyles.form}>
        <div className={authStyles.formGroup}>
          <label htmlFor="username" className={authStyles.label}>
            ユーザー名
          </label>
          <input
            id="username"
            type="text"
            className={authStyles.input}
            value={username}
            onChange={(e) => handleUsernameChange(e.target.value)}
            placeholder="英字で始まる3文字以上（英数字と_のみ）"
            autoComplete="username"
            minLength={3}
            maxLength={50}
            aria-describedby={fieldErrors.username ? 'username-error' : undefined}
            aria-invalid={!!fieldErrors.username}
            required
          />
          {fieldErrors.username && (
            <p
              id="username-error"
              className={authStyles.fieldError}
              aria-live="polite"
            >
              {fieldErrors.username}
            </p>
          )}
        </div>

        <div className={authStyles.formGroup}>
          <label htmlFor="email" className={authStyles.label}>
            メールアドレス
          </label>
          <input
            id="email"
            type="email"
            className={authStyles.input}
            value={email}
            onChange={(e) => handleEmailChange(e.target.value)}
            placeholder="example@email.com"
            autoComplete="email"
            maxLength={254}
            aria-describedby={fieldErrors.email ? 'email-error' : undefined}
            aria-invalid={!!fieldErrors.email}
            required
          />
          {fieldErrors.email && (
            <p
              id="email-error"
              className={authStyles.fieldError}
              aria-live="polite"
            >
              {fieldErrors.email}
            </p>
          )}
        </div>

        <div className={authStyles.formGroup}>
          <label htmlFor="password" className={authStyles.label}>
            パスワード
          </label>
          <div className={authStyles.passwordWrapper}>
            <input
              id="password"
              type={showPassword ? 'text' : 'password'}
              className={clsx(authStyles.input, authStyles.inputWithToggle)}
              value={password}
              onChange={(e) => handlePasswordChange(e.target.value)}
              placeholder="8文字以上（英字と数字を含む）"
              autoComplete="new-password"
              minLength={8}
              aria-describedby={
                fieldErrors.password ? 'password-error' : undefined
              }
              aria-invalid={!!fieldErrors.password}
              required
            />
            <button
              type="button"
              className={authStyles.toggleButton}
              onClick={() => setShowPassword(!showPassword)}
              aria-label={showPassword ? 'パスワードを隠す' : 'パスワードを表示'}
              aria-pressed={showPassword}
            >
              {showPassword ? <EyeOffIcon /> : <EyeIcon />}
            </button>
          </div>
          {fieldErrors.password && (
            <p
              id="password-error"
              className={authStyles.fieldError}
              aria-live="polite"
            >
              {fieldErrors.password}
            </p>
          )}
        </div>

        <div className={authStyles.formGroup}>
          <label htmlFor="confirmPassword" className={authStyles.label}>
            パスワード（確認）
          </label>
          <div className={authStyles.passwordWrapper}>
            <input
              id="confirmPassword"
              type={showConfirmPassword ? 'text' : 'password'}
              className={clsx(authStyles.input, authStyles.inputWithToggle)}
              value={confirmPassword}
              onChange={(e) => handleConfirmPasswordChange(e.target.value)}
              onBlur={handleConfirmPasswordBlur}
              placeholder="パスワードを再入力"
              autoComplete="new-password"
              minLength={8}
              aria-describedby={
                passwordMismatch ? 'confirmPassword-error' : undefined
              }
              aria-invalid={passwordMismatch}
              required
            />
            <button
              type="button"
              className={authStyles.toggleButton}
              onClick={() => setShowConfirmPassword(!showConfirmPassword)}
              aria-label={
                showConfirmPassword
                  ? '確認パスワードを隠す'
                  : '確認パスワードを表示'
              }
              aria-pressed={showConfirmPassword}
            >
              {showConfirmPassword ? <EyeOffIcon /> : <EyeIcon />}
            </button>
          </div>
          {passwordMismatch && (
            <p
              id="confirmPassword-error"
              className={authStyles.fieldError}
              aria-live="polite"
            >
              パスワードが一致しません
            </p>
          )}
        </div>

        {fieldErrors.general && (
          <p className={authStyles.error} role="alert">
            {fieldErrors.general}
          </p>
        )}

        <Button
          type="submit"
          variant="primary"
          isLoading={isLoading}
          disabled={!canSubmit}
        >
          サインアップ
        </Button>

        <div className={authStyles.linkContainer}>
          <span className={authStyles.linkText}>アカウントをお持ちの方は</span>
          <Link to="/login" state={{ from: { pathname: from } }} className={authStyles.link}>
            ログイン
          </Link>
        </div>
      </form>
    </div>
  );
}
