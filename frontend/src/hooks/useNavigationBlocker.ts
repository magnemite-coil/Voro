// hooks/useNavigationBlocker.ts
import { useBlocker } from 'react-router';
import { useCallback } from 'react';

interface UseNavigationBlockerReturn {
  isBlocked: boolean;
  proceed: () => void;
  reset: () => void;
}

export function useNavigationBlocker(isDirty: boolean, skipBlock = false): UseNavigationBlockerReturn {
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      isDirty && !skipBlock && currentLocation.pathname !== nextLocation.pathname
  );

  const proceed = useCallback(() => {
    if (blocker.state === 'blocked') {
      blocker.proceed();
    }
  }, [blocker]);

  const reset = useCallback(() => {
    if (blocker.state === 'blocked') {
      blocker.reset();
    }
  }, [blocker]);

  return {
    isBlocked: blocker.state === 'blocked',
    proceed,
    reset,
  };
}
