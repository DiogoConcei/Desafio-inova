# Estado dos Empenhos

O passo inicial da auditoria consiste em quantificar o volume de empenhos emitidos e verificar quantos destes possuem execução financeira iniciada. O objetivo é estabelecer o universo de análise para os pagamentos.

```sql
SELECT
    COUNT(*) AS total_empenhos
FROM empenho;

SELECT
    COUNT(DISTINCT id_empenho) AS total_empenhos_com_pagamento
FROM
    pagamento;
```

Identificou-se um total de **497 empenhos registrados** e **497 empenhos com ordens de pagamento associadas**. Diante da paridade numérica, a investigação aprofunda-se na qualidade e conformidade destes pagamentos.

---

# Processo de Pagamento e Liquidação

Conforme a legislação vigente (Lei nº 4.320/1964), para que um empenho seja regularmente pago, é imprescindível a existência prévia da liquidação da despesa. O fluxo regular exige:

**Empenho → Liquidação → Pagamento.**

A query abaixo verifica quantos empenhos cumprem o rito completo:

```sql
SELECT COUNT(DISTINCT e.id_empenho)
AS total_empenhos_regulares
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho;
```

Dos **497 empenhos totais**, apenas **457** possuem simultaneamente ordem de pagamento e registro de liquidação. Restam, portanto, **40 casos de pagamentos realizados sem o devido registro de liquidação**. A investigação a seguir isola estes casos para detalhamento:

```sql
SELECT DISTINCT e.id_empenho,
       p.id_pagamento,
       p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE l.id_empenho IS NULL;
```

Para verificar se a falha é apenas no registro da liquidação ou se há ausência total de lastro fiscal, cruzou-se os dados desses 40 empenhos com a tabela de notas fiscais vinculadas ao pagamento.

```sql
SELECT
    CASE
        WHEN np.chave_nfe IS NOT NULL THEN 'COM_NFE_VINCULADA'
        ELSE 'SEM_NFE_VINCULADA'
    END AS status_fiscal,
    COUNT(DISTINCT p.id_pagamento) AS qtd_pagamentos
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
LEFT JOIN nfe_pagamento np ON np.id = p.id_pagamento
WHERE l.id_empenho IS NULL
GROUP BY status_fiscal;
```

Constatou-se que, dos 40 empenhos sem liquidação, **nenhum apresenta vínculo com Nota Fiscal Eletrônica (NF-e)** no momento do pagamento, configurando uma irregularidade documental completa.

---

# Estado dos Contratos

Considerando que o contrato é o instrumento que origina a despesa, é necessário verificar a cobertura contratual. Existem **500 contratos registrados** no sistema. A análise busca segmentar quantos finalizaram o fluxo corretamente e quantos permanecem em aberto.

```sql
SELECT
    COUNT(*) AS total_contratos
FROM contrato;
```

Para classificar a integridade fiscal de cada contrato executado, utilizou-se a seguinte consulta:

```sql
SELECT
    e.id_empenho,
    p.id_pagamento,
    p.valor AS valor_pago,
    l.id_liq_empnf AS registro_liquidacao,
    l.chave_danfe AS chave_nfe_liquidacao,
    CASE
        WHEN np.chave_nfe IS NOT NULL THEN 'CONCLUÍDO COM NF-E'
        ELSE 'PENDENTE DE VINCULAÇÃO FISCAL (SEM NF-E NO PAGAMENTO)'
    END AS status_integridade_fiscal
FROM empenho e
INNER JOIN pagamento p ON e.id_empenho = p.id_empenho
INNER JOIN liquidacao_nota_fiscal l ON e.id_empenho = l.id_empenho
LEFT JOIN nfe_pagamento np ON p.id_pagamento = np.id
ORDER BY e.id_empenho;
```

Confirmou-se que **457 contratos/empenhos** completaram o ciclo de validação. Para os 40 restantes, que possuem pagamento mas não possuem liquidação/NF-e, aplicou-se a query abaixo para confirmar o status "Em Aberto" e os valores envolvidos:

```sql
SELECT
    c.id_contrato,
    e.id_empenho,
    f.nome AS fornecedor,
    SUM(p.valor) AS total_pago_em_aberto
FROM contrato c
INNER JOIN fornecedor f ON c.id_fornecedor = f.id_fornecedor
INNER JOIN empenho e ON c.id_contrato = e.id_contrato
INNER JOIN pagamento p ON e.id_empenho = p.id_empenho
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND NOT EXISTS (
    SELECT 1 FROM nfe_pagamento np WHERE np.id = p.id_pagamento
)
GROUP BY c.id_contrato, e.id_empenho, f.nome;
```

---

# Contratos sem Empenho (Excedentes)

A diferença numérica entre contratos (500) e empenhos (497) sugere a existência de instrumentos contratuais sem reserva orçamentária.

```sql
SELECT
    c.id_contrato,
    c.valor AS valor_contrato,
    e.id_empenho,
    CASE
        WHEN e.id_empenho IS NULL THEN 'SEM_EMPENHO'
        ELSE 'COM_EMPENHO'
    END AS status_contrato_empenho
FROM contrato c
LEFT JOIN empenho e ON e.id_contrato = c.id_contrato
WHERE e.id_empenho IS NULL;
```

Foram identificados **3 contratos sem empenho**. Buscou-se verificar se houve execução financeira indevida para estes casos. Contudo, como o vínculo entre `contrato` e `pagamento` ocorre obrigatoriamente através da tabela `empenho`, não há registro sistêmico de pagamento direto para contratos não empenhados nesta base de dados.

```sql
SELECT
    c.id_contrato,
    c.objeto,
    en.nome AS nome_entidade,
    f.nome AS nome_fornecedor
FROM contrato c
JOIN entidade en ON en.id_entidade = c.id_entidade
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
LEFT JOIN empenho e ON e.id_contrato = c.id_contrato
WHERE e.id_empenho IS NULL;
```

---

# Análise de Sobrevalor nos Contratos em Aberto

Focando nos **40 contratos** classificados como "Em Aberto" (pagos, mas sem liquidação), realizou-se uma verificação crítica: o valor empenhado respeita o limite do valor contratado?

```sql
SELECT
    CASE
        WHEN e.valor > c.valor THEN 'EMPENHO_SUPERIOR_AO_CONTRATO'
        WHEN e.valor < c.valor THEN 'EMPENHO_INFERIOR_AO_CONTRATO'
        ELSE 'EMPENHO_IGUAL_AO_CONTRATO'
    END AS relacao_empenho_contrato,
    COUNT(DISTINCT e.id_empenho) AS quantidade_empenhos,
    SUM(e.valor) AS total_reservado,
    SUM(c.valor) AS total_contratado
FROM contrato c
INNER JOIN empenho e ON c.id_contrato = e.id_contrato
INNER JOIN pagamento p ON e.id_empenho = p.id_empenho
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND NOT EXISTS (
    SELECT 1 FROM nfe_pagamento np WHERE np.id = p.id_pagamento
)
GROUP BY 1;
```

Os resultados indicam uma gravidade adicional: **12 empenhos possuem valor superior ao contrato**. Isso significa que, além da ausência de documentação fiscal (liquidação/NF-e), estes pagamentos foram realizados com base em reservas orçamentárias que violam o teto contratual.

Abaixo, detalha-se o "Excesso Pago Real" (diferença entre o que saiu do caixa e o valor do contrato) para estes 12 casos críticos:

```sql
SELECT
    e.id_empenho,
    f.nome AS fornecedor,
    c.valor AS valor_contrato,
    e.valor AS valor_empenhado,
    (e.valor - c.valor) AS excesso_no_empenho,
    SUM(p.valor) AS total_ja_pago,
    (SUM(p.valor) - c.valor) AS excesso_pago_real
FROM contrato c
INNER JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
INNER JOIN empenho e ON c.id_contrato = e.id_contrato
INNER JOIN pagamento p ON e.id_empenho = p.id_empenho
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND NOT EXISTS (
    SELECT 1 FROM nfe_pagamento np WHERE np.id = p.id_pagamento
)
GROUP BY e.id_empenho, f.nome, c.valor, e.valor
HAVING e.valor > c.valor
ORDER BY excesso_pago_real DESC;
```

---

# Verificação de datas nos contratos em aberto

Já sabemos que existem **40 casos** onde o pagamento foi feito, mas não existe o registro de liquidação (a "entrega" oficial). Eu quis verificar se, além desse problema de papelada, esses pagamentos também foram feitos antes da hora, ou seja, antes do início do contrato.

Para isso, classifiquei as datas desses pagamentos em relação ao início da vigência do contrato:

```sql
SELECT
    CASE
        WHEN p.datapagamentoempenho < c.data THEN 'PAGOU_ANTES_DO_CONTRATO'
        WHEN p.datapagamentoempenho >= c.data THEN 'PAGOU_DURANTE_VIGENCIA'
    END AS checagem_data,
    COUNT(*) AS qtd_pagamentos
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND NOT EXISTS (
    SELECT 1 FROM nfe_pagamento np WHERE np.id = p.id_pagamento
)
GROUP BY 1;
```

O resultado foi positivo nesse ponto: **todos os 40 pagamentos foram feitos dentro do prazo de vigência**. Ou seja, o problema aqui é "apenas" a falta de documento (nota fiscal/liquidação) e o valor excedente em alguns casos, mas a cronologia do contrato foi respeitada.

---

# Data de pagamento

É possível notar inconsistência entre a data de pagamento registrada nas ordens de pagamento e a data de registro contábil da reserva. Não deve existir nenhum tipo de pagamento posterior à criação de um empenho, salvo em casos especiais. Em todo caso, é importante verificar esses dados.

```sql
SELECT
    e.id_empenho,
    e.data_empenho,
    p.datapagamentoempenho
FROM empenho e
JOIN pagamento p
    ON p.id_empenho = e.id_empenho
WHERE e.data_empenho > p.datapagamentoempenho;
```

Existem **41 casos** onde o pagamento foi realizado **ANTES** da emissão do empenho. O que por si só é muito grave.

O próximo passo é saber se ocorreu pagamento dentro do período de vigência do contrato.

```sql
SELECT
    e.id_empenho,
    f.nome AS fornecedor,
    c.data AS data_inicio_contrato,
    e.data_empenho,
    p.datapagamentoempenho AS data_pagamento,
    (c.data - p.datapagamentoempenho) AS dias_pagou_antes_do_contrato,
    p.valor
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
WHERE e.data_empenho > p.datapagamentoempenho
  AND p.datapagamentoempenho < c.data;
```

Aconteceram **16 pagamentos** antes mesmo do período de vigência do contrato. Para finalizar essa etapa de investigação, também verifiquei se destes 41 casos, alguns foram pagos antes mesmo do processo de liquidação.

```sql
SELECT
    CASE
        WHEN p.datapagamentoempenho < l.data_emissao
        THEN 'PAGOU_ANTES_DE_LIQUIDAR (GRAVÍSSIMO)'
        WHEN p.datapagamentoempenho >= l.data_emissao
        THEN 'LIQUIDOU_ANTES_MAS_EMPENHOU_DEPOIS (ERRO_CONTABIL)'
        ELSE 'SEM_LIQUIDACAO'
    END AS tipo_inconsistencia,
    COUNT(*) AS qtd_casos,
    SUM(p.valor) AS total_envolvido
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE e.data_empenho > p.datapagamentoempenho
GROUP BY 1;
```

Em todos esses casos **o pagamento foi antes de liquidar**.

---

# Conformidade da Execução Orçamentária

Após a análise contratual, a auditoria voltou-se para a execução orçamentária propriamente dita. O objetivo foi verificar se os pagamentos realizados respeitaram os limites estabelecidos nas Notas de Empenho, conforme preconiza a legislação financeira (despesa não pode exceder o crédito orçamentário).

Inicialmente, buscou-se identificar individualmente quais empenhos apresentam desembolso financeiro superior ao valor reservado.

```sql
SELECT
    e.id_empenho,
    e.valor AS valor_empenhado,
    SUM(p.valor) AS total_pago,
    (SUM(p.valor) - e.valor) AS diferenca
FROM empenho e
JOIN pagamento p
    ON p.id_empenho = e.id_empenho
GROUP BY
    e.id_empenho,
    e.valor
HAVING
    SUM(p.valor) > e.valor
ORDER BY
    diferenca DESC;
```

Esta consulta preliminar retornou **255 casos** onde o valor pago superou o empenhado, indicando uma falha sistêmica no bloqueio de despesas excedentes.

Para obter um panorama completo da carteira de 497 empenhos, os registros foram classificados em três categorias: **"Pago a Maior"**, **"Devidamente Pago"** (valor exato) e **"Não Devidamente Pago"** (valor inferior, indicando saldo a pagar ou economia).

```sql
SELECT
    status_pagamento,
    COUNT(*) AS quantidade_empenhos
FROM (
    SELECT
        e.id_empenho,
        e.valor AS valor_empenhado,
        COALESCE(SUM(p.valor), 0) AS total_pago,
        CASE
            WHEN COALESCE(SUM(p.valor), 0) > e.valor
                THEN 'PAGO_A_MAIOR'
            WHEN COALESCE(SUM(p.valor), 0) = e.valor
                THEN 'DEVIDAMENTE_PAGO'
            ELSE
                'NAO_DEVIDAMENTE_PAGO'
        END AS status_pagamento
    FROM empenho e
    LEFT JOIN pagamento p
        ON p.id_empenho = e.id_empenho
    GROUP BY
        e.id_empenho,
        e.valor
) t
GROUP BY
    status_pagamento
ORDER BY
    status_pagamento;
```

A consolidação dos dados revela um cenário de descontrole:

- **225 Empenhos Pagos a Maior:** Confirmando a tendência de execução acima do planejado.
- **272 Empenhos Pagos a Menor:** Indicando empenhos com saldo residual, anulações parciais ou restos a pagar não processados.

A inexistência de empenhos com status "Devidamente Pago" (diferença zero) sugere que a gestão orçamentária opera consistentemente com desvios, seja por excesso de gastos ou por ineficiência na estimativa inicial da despesa.

---

# Análise Temporal: Liquidação vs. Pagamento

Considerando os riscos fiscais associados à inadimplência contratual, como a incidência de juros e mora administrativa, é fundamental auditar o lapso temporal entre o reconhecimento da dívida e seu efetivo desembolso.

Esta análise busca identificar atrasos excessivos entre a entrega do produto/serviço (registrada na data de emissão da liquidação) e a data da ordem de pagamento.

```sql
SELECT
    e.id_empenho,
    MIN(l.data_emissao) AS data_liquidacao,
    MAX(p.datapagamentoempenho) AS data_pagamento,
    (MAX(p.datapagamentoempenho) - MIN(l.data_emissao))
    AS dias_entre_liquidacao_e_pagamento
FROM empenho e
INNER JOIN liquidacao_nota_fiscal l
    ON l.id_empenho = e.id_empenho
INNER JOIN pagamento p
    ON p.id_empenho = e.id_empenho
GROUP BY
    e.id_empenho
ORDER BY
    dias_entre_liquidacao_e_pagamento DESC;
```

Resultados positivos indicam a quantidade de dias de espera para o fornecedor receber. Resultados negativos ou iguais a zero, se existirem, devem ser auditados como prioritários, pois indicam potencial quebra da ordem cronológica legal (pagamento realizado antes ou no mesmo instante da conferência da entrega).

---

# Verificação de datas nos empenhos finalizados

Por garantia, decidi aplicar a mesma verificação de datas no grupo dos **457 empenhos** que eu considerei "Finalizados" (aqueles que têm liquidação e nota fiscal certinhas). A ideia é ver se, mesmo estando com a documentação em dia, eles respeitaram os prazos do contrato.

```sql
SELECT
    CASE
        WHEN p.datapagamentoempenho < c.data THEN 'PAGAMENTO_ANTES_DA_VIGENCIA'
        WHEN p.datapagamentoempenho = c.data THEN 'PAGAMENTO_NO_INICIO_DA_VIGENCIA'
        ELSE 'PAGAMENTO_DURANTE_VIGENCIA'
    END AS status_temporal_pagamento,
    COUNT(*) AS quantidade_pagamentos,
    SUM(p.valor) AS total_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
WHERE EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l
    JOIN nfe n ON n.chave_nfe = l.chave_danfe
    WHERE l.id_empenho = e.id_empenho
)
GROUP BY 1
ORDER BY 1;
```

O resultado confirmou minhas suspeitas anteriores: os **16 pagamentos feitos antes do contrato começar** estão justamente dentro desse grupo de empenhos "Finalizados". Ou seja, eles têm a nota fiscal e a liquidação, mas falharam gravemente no cronograma, pagando antes de haver cobertura contratual.

---

# Empenhos sem pagamento

Para fechar a análise de integridade, precisei ter certeza se existe algum empenho no sistema que foi esquecido ou que não teve nenhuma ordem de pagamento emitida.

```sql
SELECT COUNT(*) AS empenhos_sem_pagamento
FROM empenho e
LEFT JOIN pagamento p ON p.id_empenho = e.id_empenho
WHERE p.id_empenho IS NULL;
```

Também verifiquei se existe algum caso em que o empenho foi finalizado (tem nota e liquidação), mas o dinheiro nunca saiu.

```sql
SELECT COUNT(*) AS finalizados_sem_pagamento
FROM empenho e
WHERE EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l
    JOIN nfe n ON n.chave_nfe = l.chave_danfe
    WHERE l.id_empenho = e.id_empenho
)
AND NOT EXISTS (
    SELECT 1 FROM pagamento p WHERE p.id_empenho = e.id_empenho
);
```

Ambas as pesquisas deram **0**. Isso é positivo: não há "empenhos fantasmas" ou dívidas reconhecidas e não pagas nesta base de dados. Todos os empenhos gerados tiveram suas respectivas ordens de pagamento emitidas.

---

# Adiantamentos Irregulares

Já identificamos pagamentos feitos antes do contrato começar. Agora, quis ser mais rigoroso: verifiquei se existem casos que violam duas regras ao mesmo tempo — foram pagos antes do início do contrato **E** antes da liquidação (a conferência da entrega). Isso caracterizaria um adiantamento completo, sem base jurídica nem material.

```sql
SELECT
    COUNT(DISTINCT e.id_empenho) AS qtd_empenhos,
    COUNT(p.id_pagamento) AS qtd_pagamentos,
    SUM(p.valor) AS total_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE p.datapagamentoempenho < c.data
  AND p.datapagamentoempenho < l.data_emissao;
```

O sistema encontrou **16 empenhos** nessa situação crítica, somando **R$ 352.832,69**. Basicamente, esse dinheiro saiu do caixa sem contrato assinado e sem produto entregue.

---

# Pagamentos acima do valor contratado

Outra verificação vital é o teto financeiro. O pagamento nunca deve ser maior que o valor do contrato. Cruzei o valor da ordem de pagamento com o valor original do contrato para ver se esse limite foi respeitado.

```sql
SELECT
    status_pagamento,
    COUNT(*) AS quantidade_pagamentos,
    SUM(valor_pago) AS total_pago
FROM (
    SELECT
        p.id_pagamento,
        p.valor AS valor_pago,
        c.valor AS valor_contrato,
        CASE
            WHEN p.valor > c.valor THEN 'PAGAMENTO_MAIOR_QUE_CONTRATO'
            WHEN p.valor > e.valor THEN 'PAGAMENTO_MAIOR_QUE_EMPENHO'
            ELSE 'PAGAMENTO_DENTRO_DO_LIMITE'
        END AS status_pagamento
    FROM pagamento p
    JOIN empenho e ON e.id_empenho = p.id_empenho
    JOIN contrato c ON c.id_contrato = e.id_contrato
) t
GROUP BY status_pagamento
ORDER BY status_pagamento;
```

O resultado é preocupante: **255 pagamentos** (mais da metade do total) foram feitos com valores superiores ao estabelecido no contrato.

Para entender o tamanho do problema, verifiquei se esses pagamentos "exagerados" pelo menos aconteceram durante a vigência correta do contrato:

```sql
SELECT
    status_vigencia_pagamento,
    COUNT(*) AS quantidade_pagamentos,
    SUM(valor_pago) AS total_pago
FROM (
    SELECT
        p.id_pagamento,
        p.valor AS valor_pago,
        c.data AS data_inicio_vigencia,
        p.datapagamentoempenho,
        CASE
            WHEN p.datapagamentoempenho < c.data
            THEN 'ANTES_DA_VIGENCIA'
            WHEN p.datapagamentoempenho = c.data
            THEN 'NO_INICIO_DA_VIGENCIA'
            ELSE 'DURANTE_A_VIGENCIA'
        END AS status_vigencia_pagamento
    FROM pagamento p
    JOIN empenho e ON e.id_empenho = p.id_empenho
    JOIN contrato c ON c.id_contrato = e.id_contrato
    WHERE p.valor > c.valor
) t
GROUP BY status_vigencia_pagamento
ORDER BY status_vigencia_pagamento;
```

A maioria (**240**) ocorreu durante a vigência, mas **12 pagamentos excedentes** ocorreram antes mesmo do contrato começar, o que agrava a irregularidade.

Por fim, a verificação mais crítica desse grupo: quantos desses pagamentos que "estouraram" o valor do contrato foram feitos sem registro de liquidação?

```sql
SELECT
    status_liquidacao,
    COUNT(*) AS quantidade_pagamentos,
    SUM(valor_pago) AS total_pago
FROM (
    SELECT
        p.id_pagamento,
        p.valor AS valor_pago,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM liquidacao_nota_fiscal l
                WHERE l.id_empenho = e.id_empenho
            ) THEN 'COM_LIQUIDACAO'
            ELSE 'SEM_LIQUIDACAO'
        END AS status_liquidacao
    FROM pagamento p
    JOIN empenho e ON e.id_empenho = p.id_empenho
    JOIN contrato c ON c.id_contrato = e.id_contrato
    WHERE p.valor > c.valor
) t
GROUP BY status_liquidacao
ORDER BY status_liquidacao;
```

Detectamos **16 pagamentos** nessa condição. Ou seja: pagou-se mais do que o contrato permitia e **não há registro formal de que o serviço foi entregue**. Isso totaliza mais de meio milhão de reais sem a devida auditoria de entrega.

---

# Análise dos Fornecedores

Para fechar a auditoria, fui verificar quem está recebendo esses recursos. Primeiro, precisava saber o tamanho da rede de fornecedores e se todos possuem contratos formais.

```sql
SELECT
    COUNT(*) AS total_fornecedores
FROM fornecedor;
```

Identifiquei **12 fornecedores cadastrados**. Verifiquei em seguida se todos eles possuem contratos ativos.

```sql
SELECT
    f.id_fornecedor,
    f.nome AS nome_fornecedor,
    COUNT(c.id_contrato) AS quantidade_contratos
FROM fornecedor f
LEFT JOIN contrato c
    ON c.id_fornecedor = f.id_fornecedor
GROUP BY f.id_fornecedor, f.nome
ORDER BY quantidade_contratos DESC;
```

Todos os 12 possuem contratos e, cruzando com a tabela de empenhos, confirmei que todos esses contratos geraram reservas de despesa (empenhos).

---

# Identificação dos Casos Críticos

O passo mais importante desta seção final é dar nome aos responsáveis pelas irregularidades graves encontradas anteriormente. Focamos naqueles **16 casos críticos** onde o pagamento foi **maior que o valor do contrato** e, para piorar, **não houve registro de liquidação** (sem prova de entrega do serviço).

A query abaixo gera a "lista suja" para auditoria presencial, detalhando o empenho, a entidade pagadora e o fornecedor beneficiado:

```sql
SELECT DISTINCT
    e.id_empenho,
    e.valor AS valor_empenhado,
    c.valor AS valor_contrato,
    p.valor AS valor_pago,
    (p.valor - c.valor) AS valor_excedente,
    f.nome AS nome_fornecedor,
    en.nome AS orgao_pagador
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN entidade en ON en.id_entidade = c.id_entidade
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
WHERE p.valor > c.valor
AND NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
ORDER BY e.id_empenho;
```

Essa lista finaliza a investigação de dados, entregando os alvos exatos onde há indício material de dano ao erário.

---

# Integridade financeira fina

Observando a possibilidade de pagar quaisquer valores a mais, verifiquei se existiu algum "troco" sobressalente. Felizmente não.

> Observação: no SQL abaixo havia uma junção que aparenta incorreta (`JOIN fornecedor f ON f.id_fornecedor = e.id_contrato`) — mantive exatamente como no original, mas recomendo revisar o `ON` caso precise executar a query.

```sql
SELECT
    e.id_empenho,
    f.nome AS fornecedor,
    SUM(l.valor) AS total_nota_fiscal,
    SUM(p.valor) AS total_pago_banco,
    (SUM(p.valor) - SUM(l.valor)) AS diferenca_indevida
FROM empenho e
JOIN fornecedor f ON f.id_fornecedor = e.id_contrato
JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
JOIN pagamento p ON p.id_empenho = e.id_empenho
GROUP BY e.id_empenho, f.nome
HAVING SUM(p.valor) > SUM(l.valor)
ORDER BY diferenca_indevida DESC;
```

---

# Fraudes fiscais

Também verifiquei se houve algum desvio mais técnico, onde o sistema afirma um pagamento com um valor não existente.

```sql
SELECT
    f.nome AS fornecedor,
    n.numero_nfe,
    n.valor_total_nfe AS valor_real_da_nota,
    lnf.valor AS valor_lancado_no_sistema,
    (n.valor_total_nfe - lnf.valor) AS divergencia_fiscal,
    e.id_empenho
FROM fornecedor f
INNER JOIN nfe n ON f.documento = n.cnpj_emitente
INNER JOIN liquidacao_nota_fiscal lnf ON n.chave_nfe = lnf.chave_danfe
INNER JOIN empenho e ON lnf.id_empenho = e.id_empenho
WHERE n.valor_total_nfe <> lnf.valor
ORDER BY ABS(n.valor_total_nfe - lnf.valor) DESC;
```

Felizmente, todas as notas estão condizentes.

---

# Modus Operandi dos Pagamentos Irregulares

Ao analisar os meios de pagamento utilizados nas **255 transações** que excederam o valor contratual, a investigação revelou uma divisão clara na natureza da irregularidade.

A consulta retornou dados para apenas **239 transações**. Isso confirma, por exclusão, que os **16 casos críticos** identificados anteriormente (pagamentos acima do contrato sem liquidação) não possuem sequer registro na tabela de pagamentos fiscais (`nfe_pagamento`), reforçando a tese de pagamentos realizados sem qualquer lastro documental (pagamentos fantasmas). Para os 239 casos onde houve vínculo fiscal, os métodos de transferência utilizados foram:

```sql
SELECT
    np.tipo_pagamento,
    COUNT(*) AS frequencia,
    SUM(np.valor_pagamento) AS volume_financeiro_suspeito
FROM nfe_pagamento np
WHERE EXISTS (
    SELECT 1
    FROM pagamento p
    JOIN empenho e ON p.id_empenho = e.id_empenho
    JOIN contrato c ON e.id_contrato = c.id_contrato
    WHERE p.valor > c.valor
      AND p.valor = np.valor_pagamento
)
GROUP BY np.tipo_pagamento
ORDER BY volume_financeiro_suspeito DESC;
```

Estes mostram que as **239 indevidas** foram feitas via **boleto**.

---

# Consolidação de Responsabilidade por Entidade

Para fins de responsabilização administrativa, unificaram-se as duas principais irregularidades detectadas nesta auditoria:

1. Pagamentos realizados acima do valor contratual (Sobrepreço).
2. Pagamentos realizados sem registro de liquidação (Ausência de comprovação de entrega).

A consolidação desses dois grupos revelou um universo de **279 empenhos problemáticos distintos**. Note-se que o número é superior aos 255 identificados inicialmente, pois agrega também os casos onde o valor estava correto, mas não havia liquidação.

O impacto financeiro total dessas irregularidades (calculado apenas sobre o montante excedente ao contrato ou pago sem liquidação) soma **R$ 4.110.067,27**.

Abaixo, a distribuição desses 279 casos e do montante financeiro por Entidade Governamental:

```sql
SELECT
    en.nome AS entidade_responsavel,
    COUNT(DISTINCT e.id_empenho) AS qtd_empenhos_problematicos,
    SUM(CASE
        WHEN p.valor > c.valor THEN p.valor - c.valor
        ELSE p.valor
    END) AS total_risco_financeiro
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN entidade en ON en.id_entidade = c.id_entidade
WHERE
    (p.valor > c.valor)
    OR
    (NOT EXISTS (SELECT 1 FROM liquidacao_nota_fiscal l
    WHERE l.id_empenho = e.id_empenho))
GROUP BY en.nome
ORDER BY total_risco_financeiro DESC;
```

Esta tabela encerra o diagnóstico, apontando não apenas _o que_ aconteceu, mas _onde_ e _quanto_ custou ao erário cada falha de gestão.

---

# Dossiê dos Fornecedores Beneficiados

Concluindo o rastreamento do fluxo financeiro, a auditoria identificou os destinatários finais dos recursos pagos irregularmente. Esta análise consolida o "saldo excedente" (valor recebido acima do contrato) e a reincidência em pagamentos antecipados (antes da vigência contratual) por fornecedor.

```sql
SELECT
    f.nome AS fornecedor,
    f.documento AS cnpj,
    SUM(p.valor) AS total_recebido,
    SUM(p.valor) - SUM(DISTINCT c.valor) AS saldo_excedente_recebido,
    COUNT(CASE WHEN p.datapagamentoempenho < c.data THEN 1 END)
    AS qtd_pagamentos_antecipados
FROM fornecedor f
INNER JOIN contrato c ON f.id_fornecedor = c.id_fornecedor
INNER JOIN empenho e ON c.id_contrato = e.id_contrato
INNER JOIN pagamento p ON e.id_empenho = p.id_empenho
GROUP BY f.id_fornecedor, f.nome, f.documento
ORDER BY saldo_excedente_recebido DESC;
```

Os resultados revelam uma concentração preocupante de irregularidades em três empresas específicas, que juntas acumulam grande parte do passivo descoberto:

- **1º Lugar — Ti Inovação:** excedente de **R$ 161.891,81** acima do valor contratado, com **2 pagamentos** realizados antes do início da vigência.
- **2º Lugar — ConstruRio:** excedente de **R$ 150.163,74**, com **2 pagamentos** antecipados.
- **3º Lugar — Eventos & Promo:** excedente de **R$ 144.917,05**, com **4 pagamentos** antecipados.

Estes dados sugerem a necessidade de abertura imediata de Tomada de Contas Especial (TCE) focada nestes contratos específicos.

---

# Síntese Consolidada dos Dados Extraídos

Esta seção reúne, de forma estruturada e objetiva, todos os dados quantitativos extraídos ao longo da auditoria, permitindo uma visão global do cenário fiscal, contratual e orçamentário analisado.

## Universo Analisado

- **Contratos registrados:** 500
- **Empenhos emitidos:** 497
- **Contratos sem empenho:** 3
- **Empenhos sem pagamento:** 0
- **Fornecedores cadastrados:** 12

## Execução do Ciclo da Despesa

- **Empenhos com pagamento registrado:** 497
- **Empenhos com liquidação e pagamento regulares:** 457
- **Empenhos pagos sem liquidação:** 40
- **Empenhos pagos sem liquidação e sem NF-e vinculada:** 40

## Irregularidades Temporais

- **Pagamentos realizados antes da emissão do empenho:** 41
- **Pagamentos realizados antes do início da vigência contratual:** 16
- **Pagamentos realizados antes da liquidação da despesa:** 41
- **Adiantamentos completos (antes do contrato e da liquidação):** 16 empenhos
- **Valor total dos adiantamentos completos:** R$ 352.832,69

## Conformidade Financeira dos Empenhos

- **Empenhos com pagamento superior ao valor empenhado:** 255
- **Empenhos pagos a menor (saldo residual):** 272
- **Empenhos pagos exatamente no valor empenhado:** 0

## Pagamentos em Relação ao Valor Contratual

- **Pagamentos superiores ao valor do contrato:** 255
- **Pagamentos acima do contrato realizados antes da vigência:** 12
- **Pagamentos acima do contrato sem liquidação registrada:** 16

## Empenhos em Aberto com Sobrevalor

- **Empenhos pagos sem liquidação:** 40
- **Empenhos com valor empenhado superior ao contrato:** 12
- **Casos com excesso financeiro efetivamente pago:** 12

## Integridade Fiscal

- **Casos de divergência entre valor da NF-e e valor liquidado:** 0
- **Casos de pagamento maior que o total das notas fiscais:** 0

## Método dos Pagamentos Irregulares

- **Pagamentos irregulares com lastro fiscal identificado:** 239
- **Meio de pagamento predominante:** Boleto bancário
- **Pagamentos irregulares sem qualquer registro fiscal (pagamentos fantasmas):** 16

## Impacto Financeiro Consolidado

- **Empenhos problemáticos distintos:** 279
- **Impacto financeiro total estimado:** R$ 4.110.067,27

## Fornecedores com Maior Exposição ao Risco

- **Ti Inovação:** R$ 161.891,81 em excedentes contratuais e 2 pagamentos antecipados
- **ConstruRio:** R$ 150.163,74 em excedentes contratuais e 2 pagamentos antecipados
- **Eventos & Promo:** R$ 144.917,05 em excedentes contratuais e 4 pagamentos antecipados

Aqui está o texto adaptado para Markdown:

### Inconsistência de Registros Fiscais (Tabela Órfã)

Durante a reconciliação entre os pagamentos bancários e os registros fiscais detalhados, identificou-se uma divergência numérica: existem 459 registros de pagamentos de notas, contra apenas 457 vínculos de liquidação válidos.

Para investigar essa diferença, realizou-se uma varredura em busca de registros na tabela de pagamentos de notas (`nfe_pagamento`) que não possuem correspondência na tabela de liquidação (`liquidacao_nota_fiscal`).

```sql
SELECT
    np.chave_nfe,
    np.tipo_pagamento,
    np.valor_pagamento AS valor_nfe_pagamento,
    'REGISTRO ORFÃO (SEM LIQUIDAÇÃO VINCULADA)' AS status_auditoria
FROM nfe_pagamento np
LEFT JOIN liquidacao_nota_fiscal l ON np.chave_nfe = l.chave_danfe
WHERE l.chave_danfe IS NULL;
```

**Resultado:** A consulta revelou a existência de **2 registros órfãos** (Chaves: `NFE...12` e `NFE...64`). Estes registros indicam pagamentos fiscais lançados no sistema, mas que não possuem vínculo com nenhuma liquidação ou empenho, constituindo "resíduos de dados" que não devem ser contabilizados na execução financeira válida.

---

# Referências

- Brasil. **Lei nº 4.320, de 17 de março de 1964.** Estatui Normas Gerais de Direito Financeiro para elaboração e controle dos orçamentos e balanços da União, dos Estados, dos Municípios e do Distrito Federal. (Art. 60 e seguintes).
- Brasil. **Lei nº 8.666, de 21 de junho de 1993.** Regulamenta o art. 37, inciso XXI, da Constituição Federal, institui normas para licitações e contratos da Administração Pública. (Art. 62).
- Secretaria do Tesouro Nacional (STN). **Manual de Contabilidade Aplicada ao Setor Público (MCASP).** Procedimentos Contábeis Orçamentários - Execução da Despesa.
