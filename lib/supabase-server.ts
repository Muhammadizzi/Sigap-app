import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { CookieOptions } from "@supabase/ssr";

export function createSupabaseServerClient() {
  const cookieStore = cookies();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  return createServerClient(url, key, {
    cookies: { getAll: () => cookieStore.getAll(), setAll: (cookiesToSet: { name: string; value: string; options: CookieOptions }[]) => cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options)) },
  });
}
