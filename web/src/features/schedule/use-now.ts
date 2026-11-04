import { useEffect, useState } from 'react';

/** The current time, moved on each minute so labels like "today at" stay true */
export function useNow(): Date {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 60_000);

    return () => window.clearInterval(timer);
  }, []);

  return now;
}
