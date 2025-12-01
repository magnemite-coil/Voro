// App.tsx
import { createBrowserRouter, RouterProvider, Navigate, Link } from 'react-router';
import { AuthProvider } from './contexts/AuthContext';
import { NotificationProvider } from './contexts/NotificationContext';
import { Toast } from './components/common/Toast/Toast';
import { LoginPage } from './pages/LoginPage/LoginPage';
import { PostEditorPage } from './pages/PostEditorPage/PostEditorPage';
import { ProtectedRoute } from './components/common/ProtectedRoute/ProtectedRoute';

function NotFoundPage() {
  return (
    <div style={{ textAlign: 'center', padding: '40px' }}>
      <h1 style={{ color: 'var(--neon-pink)' }}>404</h1>
      <p style={{ color: 'var(--text-muted)' }}>ページが見つかりません</p>
      <Link to="/posts/new" style={{ color: 'var(--neon-cyan)' }}>
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
