// pages/LoginPage/LoginPage.tsx
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

export function LoginPage() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { showNotification } = useNotification();

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const from =
    (location.state as { from?: Location })?.from?.pathname || '/posts/new';

  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true });
    }
  }, [isAuthenticated, navigate, from]);

  // ユーザー名変更時にエラーをクリア
  const handleUsernameChange = (value: string) => {
    setUsername(value);
    if (error) {
      setError(null);
    }
  };

  // パスワード変更時にエラーをクリア
  const handlePasswordChange = (value: string) => {
    setPassword(value);
    if (error) {
      setError(null);
    }
  };

  const handleFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      await login(username, password);
      showNotification('success', 'ログインしました');
      navigate(from, { replace: true });
    } catch (err) {
      if (err instanceof ApiError) {
        // formatErrorMessage で 500 エラー時に error_id を含めて表示
        setError(formatErrorMessage(err));
      } else {
        setError('ログインに失敗しました');
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className={authStyles.container}>
      <h1 className={authStyles.title}>ログイン</h1>
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
            placeholder="ユーザー名を入力"
            autoComplete="username"
            aria-describedby={error ? 'login-error' : undefined}
            aria-invalid={!!error}
            required
          />
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
              placeholder="パスワードを入力"
              autoComplete="current-password"
              aria-describedby={error ? 'login-error' : undefined}
              aria-invalid={!!error}
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
        </div>
        {error && (
          <p id="login-error" className={authStyles.error} role="alert">
            {error}
          </p>
        )}
        <Button
          type="submit"
          variant="primary"
          isLoading={isLoading}
          disabled={!username.trim() || !password.trim()}
        >
          ログイン
        </Button>

        <div className={authStyles.linkContainer}>
          <span className={authStyles.linkText}>アカウントをお持ちでない方は</span>
          <Link to="/signup" state={{ from: { pathname: from } }} className={authStyles.link}>
            サインアップ
          </Link>
        </div>
      </form>
    </div>
  );
}
