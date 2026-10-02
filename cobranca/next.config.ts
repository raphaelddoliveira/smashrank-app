import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Só API: nenhuma página. As rotas rodam no runtime Node (precisam de
  // mTLS com certificado, que o runtime Edge não suporta).
};

export default nextConfig;
