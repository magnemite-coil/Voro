// contexts/AuthContext.tsx
import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  useMemo,
  type ReactNode,
} from 'react';
import { api, ApiError } from '../services/api';

interface AuthState {
  isAuthenticated: boolean;
  userId: number | null;
  username: string | null;
  isLoading: boolean;
}

interface AuthContextValue extends AuthState {
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const AUTH_STORAGE_KEY = 'voro_auth';

interface StoredAuthData {
  userId: number;
  username: string;
}

interface LoginResponse {
  user: {
    id: number;
    username: string;
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    userId: null,
    username: null,
    isLoading: true,
  });

  const checkAuth = useCallback(async (signal?: AbortSignal) => {
    const stored = localStorage.getItem(AUTH_STORAGE_KEY);
    if (!stored) {
      setState((prev) => ({ ...prev, isLoading: false }));
      return;
    }

    try {
      const authData: StoredAuthData = JSON.parse(stored);
      // TODO: /api/auth/me が実装されたらそちらに置き換える
      await api.get('/me/posts', { signal });

      if (signal?.aborted) return;

      setState({
        isAuthenticated: true,
        userId: authData.userId,
        username: authData.username,
        isLoading: false,
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') return;

      const stored = localStorage.getItem(AUTH_STORAGE_KEY);
      if (!stored) {
        setState({
          isAuthenticated: false,
          userId: null,
          username: null,
          isLoading: false,
        });
        return;
      }

      const authData: StoredAuthData = JSON.parse(stored);

      if (error instanceof ApiError) {
        if (error.statusCode === 401) {
          localStorage.removeItem(AUTH_STORAGE_KEY);
          setState({
            isAuthenticated: false,
            userId: null,
            username: null,
            isLoading: false,
          });
        } else {
          // 500等のサーバーエラー → 楽観的に認証状態を復元
          console.error('Auth check failed with server error:', error.statusCode);
          setState({
            isAuthenticated: true,
            userId: authData.userId,
            username: authData.username,
            isLoading: false,
          });
        }
      } else {
        // ネットワークエラー等 → 楽観的に認証状態を復元
        console.error('Auth check failed with network error:', error);
        setState({
          isAuthenticated: true,
          userId: authData.userId,
          username: authData.username,
          isLoading: false,
        });
      }
    }
  }, []);

  useEffect(() => {
    const abortController = new AbortController();
    // 初期マウント時の認証チェックは意図的な設計
    // eslint-disable-next-line react-hooks/set-state-in-effect
    checkAuth(abortController.signal);

    return () => {
      abortController.abort();
    };
  }, [checkAuth]);

  const login = useCallback(async (username: string, password: string) => {
    const data = await api.post<LoginResponse>('/auth/login', {
      username,
      password,
    });

    const authData: StoredAuthData = {
      userId: data.user.id,
      username: data.user.username,
    };
    localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(authData));

    setState({
      isAuthenticated: true,
      userId: data.user.id,
      username: data.user.username,
      isLoading: false,
    });
  }, []);

  const logout = useCallback(async () => {
    await api.post('/auth/logout', {});
    localStorage.removeItem(AUTH_STORAGE_KEY);
    setState({
      isAuthenticated: false,
      userId: null,
      username: null,
      isLoading: false,
    });
  }, []);

  const value = useMemo(
    () => ({
      ...state,
      login,
      logout,
      checkAuth,
    }),
    [state, login, logout, checkAuth]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
