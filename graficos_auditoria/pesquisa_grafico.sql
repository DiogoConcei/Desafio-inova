-- 01_analise_irregularidades_detalhada.csv
sql
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

-- 02_cronologia_antecipacoes.csv
SELECT 
    f.nome AS fornecedor,
    en.nome AS entidade,
    c.id_contrato,
    c.data AS data_inicio_contrato,
    p.datapagamentoemp AS data_pagamento,
    (c.data - p.datapagamentoemp) AS dias_antecipacao,
    p.valor AS valor_pago_indevido,
    'PAGAMENTO ANTECIPADO (Antes da vigência)' AS gravidade_temporal
FROM contrato c
JOIN entidade en ON c.id_entidade = en.id_entidade
JOIN fornecedor f ON c.id_fornecedor = f.id_fornecedor
JOIN empenho e ON c.id_contrato = e.id_contrato
JOIN pagamento p ON e.id_empenho = p.id_empenho
WHERE p.datapagamentoemp < c.data
ORDER BY dias_antecipacao DESC;

  -- 21_9_impacto_financeiro_consolidado.csv
SELECT 
    e.id_empenho,
    en.nome AS entidade_responsavel,
    CASE 
        WHEN SUM(p.valor) > c.valor THEN 'Sobrepreço Contratual'
        WHEN COUNT(l.id_liq_empnf) = 0 THEN 'Pagamento Sem Liquidação'
        ELSE 'Outra Irregularidade'
    END AS categoria_risco,
    CASE 
        WHEN SUM(p.valor) > c.valor THEN (SUM(p.valor) - c.valor)
        ELSE SUM(p.valor)
    END AS valor_risco_financeiro
FROM empenho e
JOIN contrato c ON e.id_contrato = c.id_contrato
JOIN entidade en ON c.id_entidade = en.id_entidade
JOIN pagamento p ON e.id_empenho = p.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON e.id_empenho = l.id_empenho
GROUP BY e.id_empenho, en.nome, c.valor
HAVING (SUM(p.valor) > c.valor) OR (COUNT(l.id_liq_empnf) = 0)
ORDER BY valor_risco_financeiro DESC;

-- 21_10_top_fornecedores_risco.csv
SELECT 
    f.nome AS fornecedor,
    f.documento AS cnpj,
    SUM(CASE WHEN p_total.total_pago > c.valor THEN p_total.total_pago - c.valor ELSE 0 END) AS saldo_excedente_recebido,
    COUNT(CASE WHEN p.datapagamentoemp < c.data THEN 1 END) AS qtd_pagamentos_antecipados,
    SUM(p.valor) AS total_recebido_geral
FROM fornecedor f
JOIN contrato c ON f.id_fornecedor = c.id_fornecedor
JOIN empenho e ON c.id_contrato = e.id_contrato
JOIN pagamento p ON e.id_empenho = p.id_empenho
JOIN (
    SELECT id_empenho, SUM(valor) as total_pago 
    FROM pagamento GROUP BY id_empenho
) p_total ON e.id_empenho = p_total.id_empenho
GROUP BY f.nome, f.documento
ORDER BY saldo_excedente_recebido DESC;

-- secao_02_sem_liquidacao.csv
sql
SELECT DISTINCT e.id_empenho,
       p.id_pagamento,
       p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE l.id_empenho IS NULL;

-- secao_13_sobrepreco.csv
sql
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

-- secao_15_casos_criticos.csv
sql
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

-- secao_05_sobrevalor_contratos_abertos.csv
SELECT 
    c.id_contrato,
    e.id_empenho,
    f.nome AS fornecedor,
    c.valor AS valor_contrato,
    e.valor AS valor_reservado_empenho,
    (e.valor - c.valor) AS excesso_reservado,
    SUM(p.valor) AS total_ja_pago,
    'EMPENHO MAIOR QUE CONTRATO (SEM LIQUIDAÇÃO)' AS risco_detectado
FROM contrato c
JOIN fornecedor f ON c.id_fornecedor = f.id_fornecedor
JOIN empenho e ON c.id_contrato = e.id_contrato
JOIN pagamento p ON e.id_empenho = p.id_empenho
WHERE e.valor > c.valor
AND NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
GROUP BY c.id_contrato, e.id_empenho, f.nome, c.valor, e.valor
ORDER BY excesso_reservado DESC;

-- secao_06_datas_contratos_aberto.csv
SELECT 
    e.id_empenho,
    p.id_pagamento,
    p.datapagamentoemp AS datapagamentoempenho,
    c.data AS data_inicio_contrato,
    CASE 
        WHEN p.datapagamentoemp < c.data THEN 'PAGOU_ANTES_DO_CONTRATO'
        ELSE 'PAGOU_DURANTE_VIGENCIA'
    END AS checagem_data,
    p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
ORDER BY p.datapagamentoemp;

SELECT 
    e.id_empenho,
    p.id_pagamento,
    p.datapagamentoemp AS datapagamentoempenho,
    c.data AS data_inicio_contrato,
    CASE 
        WHEN p.datapagamentoemp < c.data THEN 'PAGOU_ANTES_DO_CONTRATO'
        ELSE 'PAGOU_DURANTE_VIGENCIA'
    END AS checagem_data,
    p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
WHERE NOT EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
ORDER BY p.datapagamentoemp;

-- secao_07_pagamento_antes_empenho.csv
SELECT
    e.id_empenho,
    f.nome AS fornecedor,
    e.data_empenho,
    p.datapagamentoemp AS data_pagamento,
    (e.data_empenho - p.datapagamentoemp) AS dias_inconsistencia,
    p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN contrato c ON e.id_contrato = c.id_contrato
LEFT JOIN fornecedor f ON c.id_fornecedor = f.id_fornecedor
WHERE e.data_empenho > p.datapagamentoemp
ORDER BY dias_inconsistencia DESC;

-- secao_08_execucao_orcamentaria.csv
SELECT
    e.id_empenho,
    e.valor AS valor_empenhado,
    SUM(p.valor) AS total_pago,
    (SUM(p.valor) - e.valor) AS diferenca_estouro,
    'PAGO A MAIOR QUE EMPENHO' AS status_execucao
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
GROUP BY e.id_empenho, e.valor
HAVING SUM(p.valor) > e.valor
ORDER BY diferenca_estouro DESC;

-- secao_10_finalizados_mas_antecipados.csv
SELECT
    e.id_empenho,
    c.id_contrato,
    f.nome AS fornecedor,
    p.datapagamentoemp AS data_pagamento,
    c.data AS data_inicio_contrato,
    p.valor AS valor_pago,
    'FINALIZADO (COM DOC) MAS ANTECIPADO' AS status_auditoria
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
WHERE EXISTS (
    SELECT 1 FROM liquidacao_nota_fiscal l WHERE l.id_empenho = e.id_empenho
)
AND p.datapagamentoemp < c.data
ORDER BY p.datapagamentoemp;

-- secao_12_adiantamentos_irregulares.csv
SELECT
    e.id_empenho,
    c.id_contrato,
    f.nome AS fornecedor,
    p.valor AS valor_pago,
    p.datapagamentoemp AS data_pagamento,
    c.data AS data_inicio_contrato,
    l.data_emissao AS data_liquidacao,
    'PAGAMENTO ANTES DO CONTRATO E DA LIQUIDAÇÃO' AS tipo_infracao
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN contrato c ON c.id_contrato = e.id_contrato
JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE p.datapagamentoemp < c.data
  AND p.datapagamentoemp < l.data_emissao
ORDER BY p.datapagamentoemp;

-- secao_18_modus_operandi.csv
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

-- secao_20_dossie_fornecedores.csv
SELECT 
    f.nome AS fornecedor,
    f.documento AS cnpj,
    SUM(p.valor) AS total_recebido,
    SUM(CASE WHEN p_total.total_pago > c.valor THEN p_total.total_pago - c.valor ELSE 0 END) AS saldo_excedente_recebido,
    COUNT(CASE WHEN p.datapagamentoemp < c.data THEN 1 END) AS qtd_pagamentos_antecipados
FROM fornecedor f
JOIN contrato c ON f.id_fornecedor = c.id_fornecedor
JOIN empenho e ON c.id_contrato = e.id_contrato
JOIN pagamento p ON e.id_empenho = p.id_empenho
JOIN (
    SELECT id_empenho, SUM(valor) as total_pago 
    FROM pagamento GROUP BY id_empenho
) p_total ON e.id_empenho = p_total.id_empenho
GROUP BY f.nome, f.documento
ORDER BY saldo_excedente_recebido DESC;

-- secao_22_tabela_orfa.csv
SELECT 
    np.chave_nfe,
    np.tipo_pagamento,
    np.valor_pagamento AS valor_nfe_pagamento,
    'REGISTRO ORFÃO (SEM LIQUIDAÇÃO VINCULADA)' AS status_auditoria
FROM nfe_pagamento np
LEFT JOIN liquidacao_nota_fiscal l ON np.chave_nfe = l.chave_danfe
WHERE l.chave_danfe IS NULL
ORDER BY valor_nfe_pagamento DESC;