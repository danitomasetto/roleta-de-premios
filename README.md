# Roleta de Prêmios

Plataforma instalável para ações presenciais: eventos, prêmios por peso, captura de participantes, cupons, relatórios e dois formatos visuais (caça-níquel e roleta circular).

## Arquitetura

- **GitHub Pages:** interface web/PWA.
- **Supabase (projeto Horoteca):** schema privado `roleta`, autenticação e dados.
- **Edge Function `spin`:** registra a participação, faz o sorteio no servidor e devolve o cupom. A regra nunca fica confiada ao navegador.

## Estrutura

- `index.html` — administração e acesso.
- `participar.html` — tela pública do evento.
- `supabase/migrations/0001_roleta.sql` — banco isolado da Horoteca.
- `supabase/functions/spin/index.ts` — giro seguro.

## Implantação

1. Aplicar a migração no projeto Supabase Horoteca.
2. Criar e publicar a Edge Function `spin`.
3. Informar em `js/config.js` a URL e a chave pública do projeto.
4. Publicar a branch `main` no GitHub Pages.

Nunca coloque a chave `service_role` no GitHub ou no navegador.
