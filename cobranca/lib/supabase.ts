/**
 * Acesso ao Supabase pelo service role. Fica SÓ no servidor: essa chave passa
 * por cima de toda a RLS.
 */
const URL_BASE = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

function headers(extra: Record<string, string> = {}) {
  return {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    'Content-Type': 'application/json',
    ...extra,
  };
}

export async function rest<T = any>(
  path: string,
  init: { method?: string; body?: unknown; prefer?: string } = {},
): Promise<T> {
  const res = await fetch(`${URL_BASE}/rest/v1${path}`, {
    method: init.method ?? 'GET',
    headers: headers(init.prefer ? { Prefer: init.prefer } : {}),
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
  if (!res.ok) throw new Error(`Supabase ${path} respondeu ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const texto = await res.text();
  return texto ? (JSON.parse(texto) as T) : (null as T);
}

/**
 * Identifica o jogador pelo token do próprio app. Sem isso qualquer um
 * chamaria a rota pedindo cobrança no nome de outro.
 */
export async function jogadorDoToken(accessToken: string) {
  const res = await fetch(`${URL_BASE}/auth/v1/user`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const user = (await res.json()) as { id: string };
  const players = await rest<any[]>(
    `/players?select=id,full_name,nickname,email,document&auth_id=eq.${user.id}&limit=1`,
  );
  return players[0] ?? null;
}
