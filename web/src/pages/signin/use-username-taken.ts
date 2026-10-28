import { useEffect, useState } from 'react';
import { useGateway } from '@/app/gateway-context';

const PAUSE_MS = 300;

export function useUsernameTaken(username: string, valid: boolean): boolean {
  const gateway = useGateway();
  const [taken, setTaken] = useState<string | null>(null);

  useEffect(() => {
    if (!valid) return undefined;

    let current = true;

    const timer = setTimeout(() => {
      void gateway.session.usernameAvailable(username).then((r) => {
        if (current && r.ok && !r.value) setTaken(username);
      });
    }, PAUSE_MS);

    return () => {
      current = false;
      clearTimeout(timer);
    };
  }, [gateway, username, valid]);

  return taken === username;
}
