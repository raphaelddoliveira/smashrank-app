import https from 'node:https';

/**
 * Cliente da API da Cora (Integração Direta).
 *
 * A autenticação é mTLS: toda requisição vai com o certificado e a chave
 * privada da conta. Por isso as credenciais vivem em variável de ambiente
 * (base64) e NUNCA no repositório — quem tem esse par movimenta a conta.
 */
const CERT = Buffer.from(process.env.CORA_CERT_B64 ?? '', 'base64').toString();
const KEY = Buffer.from(process.env.CORA_KEY_B64 ?? '', 'base64').toString();
const CLIENT_ID = process.env.CORA_CLIENT_ID ?? '';
const BASE = process.env.CORA_BASE_URL ?? 'https://matls-clients.api.stage.cora.com.br';

type TokenCache = { token: string; expiraEm: number };
let cache: TokenCache | null = null;

function request(
  path: string,
  { method = 'GET', body, headers = {} }: {
    method?: string;
    body?: string;
    headers?: Record<string, string>;
  } = {},
): Promise<{ status: number; body: string }> {
  const url = new URL(path, BASE);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        host: url.hostname,
        path: url.pathname + url.search,
        method,
        cert: CERT,
        key: KEY,
        headers: {
          ...headers,
          ...(body ? { 'Content-Length': Buffer.byteLength(body).toString() } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode ?? 0, body: data }));
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

/** Token de acesso, reaproveitado enquanto válido (dura 1h em produção). */
export async function getToken(): Promise<string> {
  if (cache && cache.expiraEm > Date.now() + 60_000) return cache.token;

  const { status, body } = await request('/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=client_credentials&client_id=${encodeURIComponent(CLIENT_ID)}`,
  });
  if (status !== 200) throw new Error(`Cora /token respondeu ${status}: ${body.slice(0, 200)}`);

  const json = JSON.parse(body) as { access_token: string; expires_in: number };
  cache = { token: json.access_token, expiraEm: Date.now() + json.expires_in * 1000 };
  return json.access_token;
}

export type CobrancaPix = {
  id: string;
  status: string;
  qrCode?: string;        // copia e cola
  qrCodeImagem?: string;  // URL/base64 do QR, quando a Cora devolve
  valorCentavos: number;
  vencimento: string;
};

/**
 * Cria uma cobrança PIX. `idempotencyKey` evita cobrança duplicada se a
 * chamada for repetida (exigência da Cora: UUID por requisição).
 *
 * Notificação ao cliente fica DESLIGADA de propósito: aqui a pessoa paga
 * dentro do app, olhando o QR na tela — ninguém recebe e-mail ou SMS.
 */
export async function criarCobrancaPix(params: {
  valorCentavos: number;
  vencimento: string;          // YYYY-MM-DD
  nome: string;
  documento: string;           // CPF/CNPJ só dígitos
  email?: string;
  descricao: string;
  idempotencyKey: string;
}): Promise<CobrancaPix> {
  const token = await getToken();
  const payload = {
    code: params.idempotencyKey,
    customer: {
      name: params.nome,
      email: params.email,
      document: { identity: params.documento, type: params.documento.length > 11 ? 'CNPJ' : 'CPF' },
    },
    services: [
      { name: params.descricao, amount: params.valorCentavos },
    ],
    payment_terms: { due_date: params.vencimento },
    payment_forms: ['PIX'],
    notifications: { destination: {}, channels: [] },
  };

  const { status, body } = await request('/v2/invoices', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': params.idempotencyKey,
    },
    body: JSON.stringify(payload),
  });
  if (status >= 300) throw new Error(`Cora /v2/invoices respondeu ${status}: ${body.slice(0, 300)}`);

  const inv = JSON.parse(body) as Record<string, any>;
  return {
    id: inv.id,
    status: inv.status,
    qrCode: inv.pix?.emv ?? inv.pix?.qr_code,
    qrCodeImagem: inv.pix?.qr_code_image,
    valorCentavos: inv.total_amount ?? params.valorCentavos,
    vencimento: inv.payment_terms?.due_date ?? params.vencimento,
  };
}

/** Consulta uma cobrança (usado como confirmação, sem depender do webhook). */
export async function consultarCobranca(id: string): Promise<Record<string, any>> {
  const token = await getToken();
  const { status, body } = await request(`/v2/invoices/${id}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (status >= 300) throw new Error(`Cora GET invoice respondeu ${status}`);
  return JSON.parse(body);
}
