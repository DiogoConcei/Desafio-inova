## Questão 1 — Modelagem do Banco de Dados

Para a **Questão 1**, foram desenvolvidos:

- Um **diagrama relacional**
- Um **texto explicativo** descrevendo a abordagem adotada

O diagrama encontra-se na pasta **`diagrama`**, juntamente com:

- Um arquivo **`.sql`** contendo a criação das tabelas do banco de dados
- O texto explicativo, que foi elaborado utilizando a ferramenta **Overleaf**

Como o diagrama foi gerado por meio da ferramenta **dbdiagram**, a exportação em formato **PDF** resulta em duas páginas distintas:

1. Uma versão _“limpa”_, na qual os nomes dos relacionamentos não aparecem
2. Uma versão detalhada, onde os nomes dos relacionamentos estão visíveis

---

## Questão 2 — Investigação e Análise dos Dados

A **Questão 2** demandou um trabalho extenso de pesquisa, bem como um tempo significativo de refinamento do material produzido. Ainda assim, alguns pontos acabaram não sendo abordados de forma explícita, tais como:

- Quantas entidades existem (apenas uma?)
- Qual o valor total gasto por essa entidade?
- Todos os fornecedores possuem dados válidos?

Essas lacunas ocorreram devido à complexidade e à dimensão que a investigação acabou assumindo. No entanto, ressalta-se que os dados analisados permanecem **válidos e consistentes**.

Os materiais referentes à segunda questão estão organizados na pasta **`investigacao`**, contendo:

- O arquivo **`questionamentos.sql`**, onde é possível visualizar todas as consultas realizadas no banco de dados
- O registro completo do **fluxo de pensamento**, documentado ao longo da análise dos questionamentos

A análise final resultou em um documento **PDF** com aproximadamente **21 páginas**. Para facilitar a leitura e a navegação, foi criada também uma **versão em Markdown** desse mesmo conteúdo, visando maior acessibilidade caso seja necessário revisitar ou revisar as informações.

---

## Questão 3 — Visualização dos Dados

Com base nos dados obtidos durante a etapa de análise, foram elaborados os gráficos utilizados para responder à **Questão 3**.

- Todos os gráficos foram desenvolvidos em **Python puro**, utilizando a biblioteca **Plotly**
- Inicialmente, cada visualização foi exportada no formato **HTML**, preservando totalmente a interatividade
- Em seguida, os gráficos também foram convertidos para o formato **PNG**, com o objetivo de facilitar a visualização e o compartilhamento
  - ⚠️ Ressalta-se que a versão em imagem **não mantém a interatividade**

Antes da geração dos gráficos, foi realizada a consolidação de aproximadamente **16 arquivos CSV** contendo os dados relevantes. No entanto, considerando que a utilização de todos esses conjuntos resultaria em um volume excessivo de visualizações, optou-se pela seleção de apenas **7 conjuntos de dados**, considerados mais representativos, para compor os gráficos finais.

Os gráficos foram organizados em quatro grupos distintos dentro da pasta **`graficos_auditoria`**.

- A versão **interativa** de cada gráfico encontra-se no formato **`.html`**, podendo ser aberta diretamente em qualquer navegador, sem necessidade de configurações adicionais
- Em cada grupo, há também uma **subpasta** contendo a versão correspondente do gráfico no formato de **imagem**

Por questões de **proteção de dados**, os arquivos CSV utilizados não foram disponibilizados no GitHub. Ainda assim, esses arquivos permanecem sob minha posse e podem ser apresentados mediante necessidade ou solicitação futura.

---

## Conclusões Finais

As conclusões finais do trabalho estão consolidadas no arquivo **`relatório final`**.
