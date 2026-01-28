CREATE TABLE "contrato" (
  "id_contrato" integer PRIMARY KEY,
  "valor" numeric(15,2) NOT NULL,
  "data" date NOT NULL,
  "objeto" varchar(255) NOT NULL,
  "id_entidade" integer NOT NULL,
  "id_fornecedor" integer NOT NULL
);

CREATE TABLE "empenho" (
  "id_empenho" varchar(255) PRIMARY KEY,
  "ano" integer NOT NULL,
  "data_empenho" date NOT NULL,
  "cpfcnpjcredor" varchar(20) NOT NULL,
  "credor" varchar(255) NOT NULL,
  "valor" numeric(15,2) NOT NULL,
  "id_entidade" integer NOT NULL,
  "id_contrato" integer
);

CREATE TABLE "liquidacao_nota_fiscal" (
  "id_liq_empnf" integer PRIMARY KEY,
  "chave_danfe" varchar(50) NOT NULL,
  "data_emissao" date NOT NULL,
  "valor" numeric(15,2) NOT NULL,
  "id_empenho" varchar(255) NOT NULL
);

CREATE TABLE "nfe" (
  "id" bigint PRIMARY KEY,
  "chave_nfe" varchar(50) UNIQUE NOT NULL,
  "numero_nfe" varchar(50) NOT NULL,
  "data_hora_emissao" timestamp NOT NULL,
  "cnpj_emitente" varchar(20) NOT NULL,
  "valor_total_nfe" numeric(15,2) NOT NULL
);

CREATE TABLE "pagamento" (
  "id_pagamento" varchar(255) PRIMARY KEY,
  "id_empenho" varchar(255) NOT NULL,
  "datapagamentoemp" date NOT NULL,
  "valor" numeric(15,2) NOT NULL
);

CREATE TABLE "nfe_pagamento" (
  "id" varchar(255) PRIMARY KEY,
  "chave_nfe" varchar(50) UNIQUE NOT NULL,
  "tipo_pagamento" varchar(50) NOT NULL,
  "valor_pagamento" numeric(15,2) NOT NULL
);

CREATE TABLE "fornecedor" (
  "id_fornecedor" integer PRIMARY KEY,
  "nome" varchar(255) NOT NULL,
  "documento" varchar(20) UNIQUE NOT NULL
);

CREATE TABLE "entidade" (
  "id_entidade" integer PRIMARY KEY,
  "nome" varchar(255) NOT NULL,
  "estado" varchar(50) NOT NULL,
  "municipio" varchar(100) NOT NULL,
  "cnpj" varchar(20) UNIQUE NOT NULL
);

CREATE INDEX ON "contrato" ("id_entidade");

CREATE INDEX ON "contrato" ("id_fornecedor");

CREATE INDEX ON "empenho" ("id_entidade");

CREATE INDEX ON "empenho" ("id_contrato");

CREATE INDEX ON "empenho" ("ano");

CREATE INDEX ON "liquidacao_nota_fiscal" ("id_empenho");

CREATE INDEX ON "liquidacao_nota_fiscal" ("chave_danfe");

CREATE INDEX ON "pagamento" ("id_empenho");

CREATE INDEX ON "pagamento" ("datapagamentoemp");

CREATE INDEX ON "nfe_pagamento" ("chave_nfe");

ALTER TABLE "liquidacao_nota_fiscal" ADD FOREIGN KEY ("id_empenho") REFERENCES "empenho" ("id_empenho");

ALTER TABLE "contrato" ADD CONSTRAINT "celebra" FOREIGN KEY ("id_entidade") REFERENCES "entidade" ("id_entidade");

ALTER TABLE "contrato" ADD CONSTRAINT "fornece" FOREIGN KEY ("id_fornecedor") REFERENCES "fornecedor" ("id_fornecedor");

ALTER TABLE "empenho" ADD CONSTRAINT "emite" FOREIGN KEY ("id_entidade") REFERENCES "entidade" ("id_entidade");

ALTER TABLE "empenho" ADD CONSTRAINT "origina" FOREIGN KEY ("id_contrato") REFERENCES "contrato" ("id_contrato");

ALTER TABLE "pagamento" ADD CONSTRAINT "é_pago_por" FOREIGN KEY ("id_empenho") REFERENCES "empenho" ("id_empenho");

ALTER TABLE "nfe" ADD CONSTRAINT "possui_pagamento" FOREIGN KEY ("chave_nfe") REFERENCES "nfe_pagamento" ("chave_nfe");

ALTER TABLE "nfe" ADD CONSTRAINT "possui_registro_de_liquidacao" FOREIGN KEY ("chave_nfe") REFERENCES "liquidacao_nota_fiscal" ("chave_danfe");
