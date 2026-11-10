# Checklist de validação antes de publicar

- [ ] Supabase criado e SQL executado sem erros.
- [ ] E-mail de confirmação e recuperação de senha configurados.
- [ ] Conta de cliente criada e login/logout testados.
- [ ] Duas contas de lojista criadas; cada uma só acessa seus dados.
- [ ] Conta proprietária adicionada a `admin_users`.
- [ ] Usuário comum não consegue abrir dados Master nem via API.
- [ ] Loja pendente não aparece na área pública.
- [ ] Loja aprovada aparece para clientes.
- [ ] Produto de loja não aprovada não aparece publicamente.
- [ ] Storage: upload/leitura/alteração/exclusão testados com duas contas.
- [ ] Teste de layout em Android, iOS, tablet e desktop.
- [ ] URLs de Auth do domínio final configuradas.
- [ ] Variáveis de ambiente cadastradas no Netlify.
- [ ] `npm run build` concluído sem erros.
- [ ] Revisão de segurança e privacidade realizada.

## Recursos desta revisão
- [ ] Configure o Supabase e execute `supabase/schema.sql`.
- [ ] Cadastre o e-mail do proprietário em `admin_users` usando o SQL descrito no README.
- [ ] Teste a permissão de localização no celular (HTTPS é necessário fora de localhost).
- [ ] Cadastre coordenadas reais no painel do lojista e confirme o marcador no mapa.
- [ ] Teste upload de capa, logo e fotos de produtos (bucket `vitriny-media`, limite de 5 MB).
- [ ] Teste editar/excluir produtos e visualizar a página individual da loja.
- [ ] Teste favoritos com duas contas e valide as políticas RLS antes do lançamento.
- [ ] Configure domínio, termos, privacidade, backups e monitoramento.
