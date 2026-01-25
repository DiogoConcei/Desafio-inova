CREATE TABLE `contratos` (
  `id_contrato` integer PRIMARY KEY,
  `valor` numeric(15,2) NOT NULL,
  `data` date NOT NULL,
  `objeto` varchar(255) NOT NULL,
  `id_entidade` integer NOT NULL,
  `id_fornecedor` integer NOT NULL
);

CREATE TABLE `empenhos` (
  `id_empenho` varchar(255) PRIMARY KEY,
  `ano` integer NOT NULL,
  `data_empenho` date NOT NULL,
  `cpfcnpjcredor` varchar(20) NOT NULL,
  `credor` varchar(255) NOT NULL,
  `valor` numeric(15,2) NOT NULL,
  `id_entidade` integer NOT NULL,
  `id_contrato` integer
);

CREATE TABLE `liquidacao_nota_fiscal` (
  `id_liq_empnf` integer PRIMARY KEY,
  `chave_danfe` varchar(50) NOT NULL,
  `data_emissao` date NOT NULL,
  `valor` numeric(15,2) NOT NULL,
  `id_empenho` varchar(255) NOT NULL
);

CREATE TABLE `nfe` (
  `id` bigint PRIMARY KEY,
  `chave_nfe` varchar(50) UNIQUE NOT NULL,
  `numero_nfe` varchar(50) NOT NULL,
  `data_hora_emissao` timestamp NOT NULL,
  `cnpj_emitente` varchar(20) NOT NULL,
  `valor_total_nfe` numeric(15,2) NOT NULL
);

CREATE TABLE `pagamentos` (
  `id_pagamento` varchar(255) PRIMARY KEY,
  `id_empenho` varchar(255) NOT NULL,
  `datapagamentoemp` date NOT NULL,
  `valor` numeric(15,2) NOT NULL
);

CREATE TABLE `nfe_pagamentos` (
  `id` varchar(255) PRIMARY KEY,
  `chave_nfe` varchar(50) UNIQUE NOT NULL,
  `tipo_pagamento` varchar(50) NOT NULL,
  `valor_pagamento` numeric(15,2) NOT NULL
);

CREATE TABLE `fornecedores` (
  `id_fornecedor` integer PRIMARY KEY,
  `nome` varchar(255) NOT NULL,
  `documento` varchar(20) UNIQUE NOT NULL
);

CREATE TABLE `entidades` (
  `id_entidade` integer PRIMARY KEY,
  `nome` varchar(255) NOT NULL,
  `estado` varchar(50) NOT NULL,
  `municipio` varchar(100) NOT NULL,
  `cnpj` varchar(20) UNIQUE NOT NULL
);

CREATE INDEX `contratos_index_0` ON `contratos` (`id_entidade`);

CREATE INDEX `contratos_index_1` ON `contratos` (`id_fornecedor`);

CREATE INDEX `empenhos_index_2` ON `empenhos` (`id_entidade`);

CREATE INDEX `empenhos_index_3` ON `empenhos` (`id_contrato`);

CREATE INDEX `empenhos_index_4` ON `empenhos` (`ano`);

CREATE INDEX `liquidacao_nota_fiscal_index_5` ON `liquidacao_nota_fiscal` (`id_empenho`);

CREATE INDEX `liquidacao_nota_fiscal_index_6` ON `liquidacao_nota_fiscal` (`chave_danfe`);

CREATE INDEX `pagamentos_index_7` ON `pagamentos` (`id_empenho`);

CREATE INDEX `pagamentos_index_8` ON `pagamentos` (`datapagamentoemp`);

CREATE INDEX `nfe_pagamentos_index_9` ON `nfe_pagamentos` (`chave_nfe`);

ALTER TABLE `liquidacao_nota_fiscal` ADD FOREIGN KEY (`id_empenho`) REFERENCES `empenhos` (`id_empenho`);

ALTER TABLE `contratos` ADD CONSTRAINT `celebra` FOREIGN KEY (`id_entidade`) REFERENCES `entidades` (`id_entidade`);

ALTER TABLE `contratos` ADD CONSTRAINT `fornece` FOREIGN KEY (`id_fornecedor`) REFERENCES `fornecedores` (`id_fornecedor`);

ALTER TABLE `empenhos` ADD CONSTRAINT `emite` FOREIGN KEY (`id_entidade`) REFERENCES `entidades` (`id_entidade`);

ALTER TABLE `empenhos` ADD CONSTRAINT `origina` FOREIGN KEY (`id_contrato`) REFERENCES `contratos` (`id_contrato`);

ALTER TABLE `pagamentos` ADD CONSTRAINT `é_pago_por` FOREIGN KEY (`id_empenho`) REFERENCES `empenhos` (`id_empenho`);

ALTER TABLE `nfe` ADD CONSTRAINT `é_quitada_por` FOREIGN KEY (`chave_nfe`) REFERENCES `nfe_pagamentos` (`chave_nfe`);

ALTER TABLE `nfe` ADD CONSTRAINT `é_liquidado_por` FOREIGN KEY (`chave_nfe`) REFERENCES `liquidacao_nota_fiscal` (`chave_danfe`);
