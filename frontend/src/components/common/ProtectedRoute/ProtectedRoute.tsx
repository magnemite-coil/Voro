// components/common/ProtectedRoute/ProtectedRoute.tsx
import { type ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import { useAuth } from '../../../contexts/AuthContext';
import { Spinner } from '../Spinner/Spinner';
import styles from './ProtectedRoute.module.css';

interface ProtectedRouteProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className={styles.loadingContainer}>
        <Spinner size="large" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}
