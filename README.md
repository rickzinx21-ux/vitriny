# Vitriny

**Sua cidade inteira em uma vitrine.**

Primeira base executável do marketplace local Vitriny: React + Vite + Supabase + Leaflet.

## O que já está nesta entrega

- Interface responsiva para clientes: busca, lojas, produtos, ofertas e chamada para lojistas.
- Mapa Leaflet/OpenStreetMap com pedido de geolocalização, marcador da posição do visitante, filtro por raio, ordenação por distância e links para traçar rota no Google Maps.
- Cadastro, login, logout e recuperação de senha via Supabase Auth (após configurar credenciais).
- Área do lojista com edição do estabelecimento, endereço, coordenadas, fotos de capa/logo, cadastro/edição/exclusão de produtos, preço promocional, estoque e upload de imagens no Supabase Storage.
- Painel Master fora da navegação: três toques rápidos na sacolinha superior esquerda.
- Checagem de autorização Master usando a tabela `admin_users`; o gesto não é segurança.
- SQL inicial com tabelas, relacionamentos, trigger de perfil, RLS e bucket Storage.
- Configuração de deploy Netlify.

## O que ainda NÃO está concluído

Esta é a primeira entrega de fundação, não o lançamento final. Ainda precisam ser implementados e testados: limite de produtos aplicado no banco; favoritos de lojas com tela de conteúdo completo; geocodificação automática de endereços; filtros avançados por categoria; horários e redes sociais completos; dashboards analíticos; bloqueio de usuários; gestão financeira e assinaturas; banners; pagamentos reais; testes automatizados e auditoria de segurança. A tela de detalhe da loja é um placeholder nesta versão. Os cards de exemplo aparecem apenas quando o Supabase não está configurado e não representam lojas reais.

Não há cobrança nem pagamento simulado. Os valores dos planos Profissional e Premium permanecem indefinidos.

## Requisitos

- Node.js 20 ou superior
- Conta Supabase
- (Opcional) conta Netlify para publicação

## Instalação local

1. Extraia o ZIP.
2. Abra a pasta `vitriny` no terminal.
3. Execute `npm install`.
4. Copie `.env.example` para `.env.local`.
5. No painel Supabase, abra **Project Settings > API** e copie Project URL e `anon`/publishable key para `.env.local`:

```env
VITE_SUPABASE_URL=https://SEU-PROJETO.supabase.co
VITE_SUPABASE_ANON_KEY=SUA_CHAVE_PUBLICA_ANON
```

6. No Supabase, abra **SQL Editor > New query**, cole todo o arquivo `supabase/schema.sql` e execute.
7. Crie uma conta pela aplicação. Confirme o e-mail, se a confirmação estiver habilitada no Supabase.
8. Para autorizar o proprietário, execute no SQL Editor (substitua pelo e-mail correto):

```sql
insert into public.admin_users(user_id, role)
select id, 'owner' from auth.users
where email = 'SEU_EMAIL_DE_LOGIN'
on conflict (user_id) do nothing;
```

9. Execute `npm run dev` e abra o endereço local informado pelo Vite.

## Segurança

- Use somente a chave `anon`/publishable no frontend.
- **Nunca** coloque `service_role` em `.env` com prefixo `VITE_`, no frontend, Git ou Netlify.
- O RLS é a barreira real; não confie em ocultar rotas ou botões.
- O primeiro usuário não vira admin automaticamente. A autorização inicial é feita manualmente no SQL Editor.
- Revise as políticas RLS com testes em contas separadas antes de produção.
- A política de inserção de views permite eventos anônimos; implemente rate limiting/antifraude antes de usar como métrica financeira.

## Publicação no Netlify

1. Envie o projeto para um repositório Git privado ou público.
2. No Netlify, escolha **Add new site > Import an existing project**.
3. Build command: `npm run build`.
4. Publish directory: `dist`.
5. Em **Site configuration > Environment variables**, cadastre `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`.
6. Publique e teste cadastro, login, RLS e navegação em celular.
7. Configure no Supabase **Authentication > URL Configuration**: Site URL e Redirect URLs para o domínio Netlify e domínio oficial.

## Observações importantes

- O mapa desta versão usa coordenadas demonstrativas apenas quando o banco não está conectado. Não representam endereço real.
- O mapa solicita a localização do visitante somente após tocar no botão. As lojas precisam ter latitude/longitude reais cadastradas pelo lojista; o botão da área do lojista preenche as coordenadas do próprio estabelecimento com autorização.
- Para pagamentos futuros, escolha um provedor (ex.: Mercado Pago ou Stripe, conforme disponibilidade no Brasil), crie Edge Functions/webhooks e valide assinatura do webhook no servidor. Não aceite confirmação de pagamento enviada pelo navegador.
- Configure backups, domínio, política de privacidade, termos de uso e monitoramento antes do lançamento oficial.
