import psycopg2
import pandas as pd
import plotly.graph_objects as go
import plotly.io as pio

# Define o renderer padrão do Plotly para exibir gráficos no navegador
pio.renderers.default = "browser"


def gerar_csv_detalhado_postgres(caminho_csv):
    """
    Função responsável por:
    1. Conectar ao banco PostgreSQL
    2. Executar a query de auditoria
    3. Salvar o resultado em um arquivo CSV
    """

    db_config = {
        'dbname': 'postgres',
        'user': 'candidato.jdazostyahhxukbmxybw',
        'password': 'DesafioInov@2026!',
        'host': 'aws-1-us-east-1.pooler.supabase.com',
        'port': '5432'
    }

    # Query SQL que identifica irregularidades e calcula valores de prejuízo
    query = """
        SELECT en.nome  AS entidade_responsavel, 
               f.nome   AS fornecedor,  
               c.objeto AS objeto_contrato,  
               e.id_empenho,  
               c.id_contrato,  
               c.valor  AS valor_teto_contrato,  
               p.valor  AS valor_total_pago,  

               CASE  
                   WHEN p.valor > c.valor THEN 'Sobrepreço (Acima do Contrato)'  
                   WHEN l.id_empenho IS NULL THEN 'Pagamento Sem Liquidação (Fantasma)'  
               END AS tipo_irregularidade,  

               CASE  
                   WHEN p.valor > c.valor THEN (p.valor - c.valor)  
                   WHEN l.id_empenho IS NULL THEN p.valor  
               END AS valor_prejuizo_estimado

        FROM empenho e
            JOIN pagamento p ON p.id_empenho = e.id_empenho
            JOIN contrato c ON c.id_contrato = e.id_contrato
            JOIN entidade en ON en.id_entidade = c.id_entidade
            JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
            LEFT JOIN liquidacao_nota_fiscal l ON l.id_empenho = e.id_empenho
        WHERE (p.valor > c.valor)
           OR (l.id_empenho IS NULL)
        ORDER BY valor_prejuizo_estimado DESC;
    """

    conn = None
    try:
        # Abre a conexão com o banco
        conn = psycopg2.connect(**db_config)

        # Executa a query e carrega o resultado em um DataFrame
        df = pd.read_sql_query(query, conn)

        # Exporta o DataFrame para CSV, usando separador compatível com Excel PT-BR
        df.to_csv(
            caminho_csv,
            index=False,
            sep=';',
            encoding='utf-8-sig',
            decimal=','
        )

    except Exception as e:
        # Tratamento genérico de erro
        print(f"Erro ao gerar CSV: {e}")

    finally:
        # Garante o fechamento da conexão com o banco
        if conn:
            conn.close()


def gerar_grafico_pizza(caminho_csv, caminho_html):
    """
    Função responsável por:
    1. Ler o CSV gerado a partir do banco
    2. Tratar e agregar os dados
    3. Gerar um gráfico de pizza
    4. Salvar o gráfico em formato HTML
    """

    # Leitura do arquivo CSV
    df = pd.read_csv(caminho_csv, sep=';', encoding='utf-8-sig')

    # Conversão de colunas monetárias de string para float
    col_numericas = ['valor_total_pago', 'valor_prejuizo_estimado']
    for col in col_numericas:
        df[col] = (
            df[col]
            .astype(str)
            .str.replace('.', '', regex=False)
            .str.replace(',', '.', regex=False)
            .astype(float)
        )

    # Agrupa os dados por objeto do contrato
    # Soma o valor total pago e o prejuízo estimado
    df_agg = (
        df.groupby('objeto_contrato')[['valor_total_pago', 'valor_prejuizo_estimado']]
        .sum()
        .reset_index()
        .sort_values('valor_total_pago', ascending=False)
    )

    # Paleta de cores usada no gráfico
    cores = [
        "rgb(95, 70, 144)", "rgb(29, 105, 150)", "rgb(56, 166, 165)",
        "rgb(15, 133, 84)", "rgb(115, 175, 72)", "rgb(237, 173, 8)",
        "rgb(225, 124, 5)", "rgb(204, 80, 62)", "rgb(148, 52, 110)",
        "rgb(111, 64, 112)", "rgb(102, 102, 102)"
    ]

    # Criação do gráfico de pizza
    fig = go.Figure(
        data=[go.Pie(
            labels=df_agg['objeto_contrato'],
            values=df_agg['valor_total_pago'],
            customdata=df_agg['valor_prejuizo_estimado'],
            textinfo='percent+label',
            textposition='inside',
            hovertemplate=(
                "<b>%{label}</b><br>"
                "Total Pago: R$ %{value:,.2f}<br>"
                "Prejuízo (Risco): R$ %{customdata:,.2f}"
                "<extra></extra>"
            )
        )]
    )

    # Ajustes de layout do gráfico
    fig.update_layout(
        title={
            'text': (
                "<b>Divisão das Despesas por Tipo de Contrato</b><br>"
                "<i>Fatias = Volume Total Pago</i>"
            ),
            'x': 0.05
        },
        legend={'title': {'text': "Objeto do Contrato"}},
        piecolorway=cores,
        template='plotly_white'
    )

    # Salva o gráfico como arquivo HTML interativo
    fig.write_html(caminho_html)

    # Exibe o gráfico no navegador
    fig.show()


# Ponto de entrada do script
# Executa primeiro a geração do CSV e, em seguida, o gráfico
if __name__ == "__main__":
    caminho_csv = "01_analise_irregularidades_detalhada.csv"
    caminho_html = "grafico_divisao_despesas.html"

    gerar_csv_detalhado_postgres(caminho_csv)
    gerar_grafico_pizza(caminho_csv, caminho_html)