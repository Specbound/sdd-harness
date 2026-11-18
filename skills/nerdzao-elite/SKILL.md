---
name: nerdzao-elite
description: Use when a pt-BR task needs the full senior engineering pass — planning, architecture, TDD, clean code, then a mandatory visual and UX check before delivery.
risk: safe
source: community
---

# nerdzao-elite

Engenheiro de Software Sênior (15+ anos) somado a Designer de Produto Sênior. Este skill é
um **roteiro de etapas**, não um pacote de conhecimento: o conteúdo mora nos skills
listados abaixo, e este arquivo só define a ordem, o que carregar em cada etapa e o
critério de saída de cada uma.

## Use este skill quando

- A tarefa é de ponta a ponta (planejar, arquitetar, implementar, validar) e não um ajuste
  pontual
- A entrega tem interface e a validação visual precisa acontecer antes do "pronto"
- O usuário escreve em português do Brasil e espera a resposta no mesmo idioma

## Não use quando

- A tarefa é um bugfix de uma linha, uma pergunta de leitura de código, ou uma tarefa sem
  interface — o roteiro completo custa mais contexto do que entrega
- Já existe um plano aprovado e você só precisa executá-lo

## Como carregar os skills

Carregue pela ferramenta Skill, um por vez, **na etapa em que ele é usado**. Não carregue
os dezenove de uma vez: cada skill carregado ocupa contexto durante toda a sessão, e um
roteiro que começa estourando a janela entrega pior do que nenhum roteiro.

## Roteiro

| Etapa | Carregue | Critério de saída |
|---|---|---|
| 1. Planejamento | `concise-planning`, `brainstorming` | Escopo escrito, com o que ficou de fora dito explicitamente |
| 2. Arquitetura | `senior-architect`, `architecture` | Limites de módulo definidos; uma alternativa descartada com motivo |
| 3. Implementação | `test-driven-development`, `testing-patterns` | Teste falhando antes do código que o faz passar |
| 4. Código limpo | `clean-code`, `code-refactoring-refactor-clean` | Sem duplicação nova; nomes revisados |
| 5. Validação técnica | `lint-and-validate`, `error-handling-patterns` | Linter limpo; todo caminho de erro tem tratamento nomeado |
| 6. Validação visual | `ui-visual-validator`, `ui-ux-pro-max`, `frontend-design`, `web-design-guidelines` | Captura de tela conferida contra a lista abaixo |
| 7. Revisão de produção | `production-code-audit`, `code-reviewer` | Segredos, logs e configuração de ambiente conferidos |
| 8. Verificação final | `verification-before-completion`, `kaizen` | Cada afirmação de "funciona" tem um comando executado atrás dela |

Se algo quebrar no meio, pare e use `systematic-debugging` antes de voltar ao roteiro.
Remendar sem diagnosticar é o que faz a etapa 8 falhar.

## Etapa 6 é obrigatória e tem lista fixa

Nunca entregue UI quebrada. Confira, nesta ordem: elementos duplicados; cor e rótulo
inconsistentes entre telas; formatação de moeda e de data no locale certo; alinhamento e
espaçamento; estados vazio, de carregamento e de erro; foco de teclado e contraste. Corrija
na hora — não registre como pendência.

## Nota sobre os nomes

Os nomes na tabela são os nomes reais dos diretórios em `~/.claude/skills/`. A versão
anterior deste arquivo citava `@refactor-clean-code`, que não existe; o skill correspondente
chama-se `code-refactoring-refactor-clean`. A sintaxe `@nome` também foi removida: no Claude
Code `@` referencia um arquivo, não carrega um skill — isso é feito pela ferramenta Skill.
Confirme o nome em `~/.claude/skills/` antes de acrescentar qualquer entrada nova à tabela.
