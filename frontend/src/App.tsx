// App.tsx
import { createBrowserRouter, RouterProvider, Navigate, Link } from 'react-router';
import { AuthProvider } from './contexts/AuthContext';
import { NotificationProvider } from './contexts/NotificationContext';
import { Toast } from './components/common/Toast/Toast';
import { LoginPage } from './pages/LoginPage/LoginPage';
import { SignupPage } from './pages/SignupPage/SignupPage';
import { PostEditorPage } from './pages/PostEditorPage/PostEditorPage';
import { PostListPage } from './pages/PostListPage/PostListPage';
import { ProtectedRoute } from './components/common/ProtectedRoute/ProtectedRoute';
import styles from './App.module.css';

export function NotFoundPage() {
  return (
    <div className={styles.notFoundContainer}>
      <h1 className={styles.notFoundTitle}>404</h1>
      <p className={styles.notFoundMessage}>ページが見つかりません</p>
      <Link to="/posts/new" className={styles.notFoundLink}>
        新規作成ページへ
      </Link>
    </div>
  );
}

const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    path: '/signup',
    element: <SignupPage />,
  },
  {
    path: '/posts',
    element: (
      <ProtectedRoute>
        <PostListPage />
      </ProtectedRoute>
    ),
  },
  {
    path: '/posts/new',
    element: (
      <ProtectedRoute>
        <PostEditorPage mode="create" />
      </ProtectedRoute>
    ),
  },
  {
    path: '/posts/:id/edit',
    element: (
      <ProtectedRoute>
        <PostEditorPage mode="edit" />
      </ProtectedRoute>
    ),
  },
  {
    path: '/',
    element: <Navigate to="/posts/new" replace />,
  },
  {
    path: '*',
    element: <NotFoundPage />,
  },
]);

function App() {
  return (
    <AuthProvider>
      <NotificationProvider>
        <RouterProvider router={router} />
        <Toast />
      </NotificationProvider>
    </AuthProvider>
  );
}

export default App;
