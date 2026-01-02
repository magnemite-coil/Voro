// pages/LoginPage/LoginPage.tsx
import { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router';
import { useAuth } from '../../contexts/AuthContext';
import { useNotification } from '../../contexts/NotificationContext';
import { Button } from '../../components/common/Button/Button';
import { ApiError, formatErrorMessage } from '../../services/api';
import authStyles from '../../styles/auth-form.module.css';

export function LoginPage() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { showNotification } = useNotification();

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

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
          <input
            id="password"
            type="password"
            className={authStyles.input}
            value={password}
            onChange={(e) => handlePasswordChange(e.target.value)}
            placeholder="パスワードを入力"
            autoComplete="current-password"
            aria-describedby={error ? 'login-error' : undefined}
            aria-invalid={!!error}
            required
          />
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
          <Link to="/signup" className={authStyles.link}>
            サインアップ
          </Link>
        </div>
      </form>
    </div>
  );
}
