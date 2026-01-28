--  Total de Empenhos Registrados no Sistema

sql
SELECT
    COUNT(*) AS total_empenhos
FROM empenho;

-- Total de Empenhos com Ordem de Pagamento Emitida
sql
SELECT 
    COUNT(DISTINCT id_empenho) AS total_empenhos_com_pagamento
FROM pagamento;

-- Empenhos com Ciclo Completo (Empenho + Liquidação + Pagamento)
sql
SELECT COUNT(DISTINCT e.id_empenho)
AS total_empenhos_regulares
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho;

-- Identificação de Pagamentos sem Registro de Liquidação
sql
SELECT DISTINCT e.id_empenho,
       p.id_pagamento,
       p.valor AS valor_pago
FROM empenho e
JOIN pagamento p ON p.id_empenho = e.id_empenho
LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
WHERE l.id_empenho IS NULL;

-- Verificação de Existência de NF-e em Pagamentos sem Liquidação
sql
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

-- Total de Contratos Registrados
sql
SELECT 
    COUNT(*) AS total_contratos 
FROM contrato;

-- Classificação da Integridade Fiscal dos Contratos Executados
sql
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

-- Contratos/Empenhos em Aberto com Valores Pagos sem Liquidação e sem NF-e
sql
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

-- Identificação de Contratos sem Empenho Vinculado
sql
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

-- Identificação Cadastral dos Contratos sem Empenho
sql
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

-- Comparação entre Valor Empenhado e Valor Contratual em Contratos em Aberto
sql
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

-- Apuração do Excesso Financeiro Real em Empenhos Acima do Valor Contratual
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

-- Verificação de Pagamentos em Relação à Vigência do Contrato (Contratos em Aberto)
sql
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

-- Pagamentos Realizados Antes da Emissão do Empenho
sql
SELECT
    e.id_empenho,
    e.data_empenho,
    p.datapagamentoempenho 
FROM empenho e
JOIN pagamento p
    ON p.id_empenho = e.id_empenho
WHERE e.data_empenho > p.datapagamentoempenho;

-- Pagamentos Realizados Antes do Início da Vigência Contratual
sql
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

-- Classificação de Pagamentos Antecipados em Relação à Liquidação
sql
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

-- Identificação de Empenhos com Pagamento Superior ao Valor Empenhado
sql
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

-- Classificação Geral dos Empenhos quanto ao Valor Pago
sql
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

-- Análise do Intervalo Temporal entre Liquidação e Pagamento
sql
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

-- Verificação Temporal de Pagamentos em Empenhos Finalizados
sql
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

-- Empenhos sem Qualquer Ordem de Pagamento Emitida
sql
SELECT COUNT(*) AS empenhos_sem_pagamento
FROM empenho e
LEFT JOIN pagamento p ON p.id_empenho = e.id_empenho
WHERE p.id_empenho IS NULL;

-- Empenhos Liquidados e com NF-e, mas sem Pagamento
sql
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

-- Identificação de Adiantamentos Completos (Antes do Contrato e da Liquidação)
sql
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

-- Pagamentos Acima do Valor do Contrato ou do Empenho
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

-- Verificação da Vigência dos Pagamentos Acima do Contrato
sql
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

-- Pagamentos Acima do Contrato sem Registro de Liquidação
sql
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

-- Total de Fornecedores Cadastrados
sql
SELECT 
    COUNT(*) AS total_fornecedores
FROM fornecedor;

-- Quantidade de Contratos por Fornecedor
sql
SELECT 
    f.id_fornecedor, 
    f.nome AS nome_fornecedor, 
    COUNT(c.id_contrato) AS quantidade_contratos
FROM fornecedor f
LEFT JOIN contrato c 
    ON c.id_fornecedor = f.id_fornecedor
GROUP BY f.id_fornecedor, f.nome
ORDER BY quantidade_contratos DESC;

-- Identificação dos Casos Críticos para Auditoria Presencial
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

-- Verificação de Pagamento Superior ao Valor Total das Notas Fiscais
sql
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

-- Detecção de Divergências entre Valor Real da NF-e e Valor Liquidado
sql
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

-- Identificação do Meio de Pagamento nas Transações Irregulares com Lastro Fiscal
sql
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

-- Consolidação de Empenhos Problemáticos e Impacto Financeiro por Entidade
sql
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
    (NOT EXISTS (
        SELECT 1 FROM liquidacao_nota_fiscal l
        WHERE l.id_empenho = e.id_empenho
    ))
GROUP BY en.nome
ORDER BY total_risco_financeiro DESC;

-- Consolidação de Recebimentos Irregulares e Pagamentos Antecipados por Fornecedor
sql
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
