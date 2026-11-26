# Pix e agências bancárias nos municípios brasileiros

Repositório do trabalho empírico de Econometria I (FGV EESP, 2º semestre de 2026), de Thiago Watanabe Salvador e Gabriel Rodrigues.

**Pergunta de pesquisa:** os municípios brasileiros que tinham menos agências bancárias por habitante antes do lançamento do Pix (dezembro de 2019) passaram a usar mais o Pix em 2025?

O trabalho estima modelos de Mínimos Quadrados Ordinários (MQO) em corte transversal para 5.566 municípios, com controles socioeconômicos, efeitos fixos de UF e erros-padrão robustos à heterocedasticidade (HC1).

## Conteúdo

| Arquivo | Descrição |
| --- | --- |
| `base_pix_municipios.csv` | Base de dados usada na análise: 5.570 municípios e 24 variáveis |
| `codigo econo versao final mesmo.R` | Script em R com a montagem da base (comentada, no início) e toda a análise |
| `README.md` | Este arquivo |

## Como reproduzir

1. Baixe o script e a base e coloque os dois **na mesma pasta**.
2. Abra o script no RStudio e defina essa pasta como diretório de trabalho (*Session → Set Working Directory → To Source File Location*).
3. Rode o script inteiro. Os pacotes que faltarem são instalados automaticamente na primeira execução.

O script gera:

- as estatísticas descritivas, as regressões, o teste F conjunto, o teste de White e o VIF, no console;
- as figuras `figura1.png` a `figura4.png`;
- as tabelas em LaTeX usadas no relatório, na pasta `tabelas/`.

Pacotes usados na análise: `readr`, `lmtest`, `sandwich`, `car`, `stargazer` e `ggplot2`.

## Montagem da base a partir das fontes oficiais

O início do script traz, comentado, o código que constrói a base do zero a partir das fontes públicas. Para rodá-lo, descomente esse trecho. Ele usa também os pacotes `jsonlite`, `sidrar` e `estbanr`.

Etapas da montagem:

1. **Pix (Banco Central):** transações e pessoas físicas pagadoras por município nos 12 meses de 2025, pela API de dados abertos. As transações são somadas no ano, e os pagadores, calculados como média mensal.
2. **IBGE (SIDRA):** estimativas de população de 2015 e 2019 (tabela 6579), população e área do Censo 2022 (tabela 4714), PIB municipal de 2019 (tabela 5938) e população com 60 anos ou mais do Censo 2022 (tabela 9514, baixada estado por estado por causa do limite da API).
3. **Agências (ESTBAN, Banco Central):** agências de todas as instituições somadas por município, em dezembro de 2015 e de 2019. As regiões administrativas do DF são consolidadas em Brasília, e as poucas linhas sem código municipal são descartadas.
4. **Banda larga fixa (Anatel):** acessos por município em dezembro de 2019. O arquivo da Anatel tem cerca de 1 GB, então o download demora.
5. **Junção:** as bases são unidas pelo código IBGE do município. Municípios ausentes da ESTBAN recebem zero agências. Boa Esperança do Norte (MT), criado após o Censo 2022, fica de fora por não ter dados do IBGE.

Esse trecho está comentado e não roda por padrão: a análise usa diretamente a base `base_pix_municipios.csv` do repositório. Como as fontes oficiais podem revisar seus dados ao longo do tempo (em especial as estatísticas do Pix), uma reconstrução feita em outra data pode apresentar pequenas diferenças em relação à base do repositório.

## Amostra

A base tem 5.570 municípios. Na análise, são excluídos 4 municípios com valores implausíveis em indicadores por habitante: Pacaraima (RR) e Águas de São Pedro (SP), com mais usuários de Pix do que habitantes, e Joca Claudino (PB) e Santa Margarida do Sul (RS), com mais acessos de banda larga do que habitantes. A amostra final tem **5.566 municípios**.

## Dicionário de variáveis

| Variável | Descrição | Fonte |
| --- | --- | --- |
| `cod_ibge` | Código IBGE do município (7 dígitos) | IBGE |
| `municipio`, `uf` | Nome do município e da UF | Banco Central |
| `pop_2015`, `pop_2019` | População estimada em 2015 e 2019 | IBGE |
| `pop_2022` | População residente no Censo 2022 | IBGE |
| `area_km2` | Área territorial (km²) | IBGE |
| `agencias_dez2015`, `agencias_dez2019` | Número de agências bancárias em dez/2015 e dez/2019 | ESTBAN |
| `banda_larga_dez2019` | Acessos de banda larga fixa em dez/2019 | Anatel |
| `pib_2019_mil` | PIB municipal de 2019 (R$ mil) | IBGE |
| `pix_pessoas_pf_media_mensal_2025` | Média mensal de pessoas físicas que pagaram com Pix em 2025 | Banco Central |
| `pix_transacoes_pf_2025` | Total de transações Pix de pessoas físicas em 2025 | Banco Central |
| `pix_usuarios` | Pagadores ÷ população de 2022 × 100 | calculada |
| `ln_pix_transacoes` | ln(transações ÷ população de 2022): **variável dependente principal** | calculada |
| `agencias_2019`, `agencias_2015` | Agências por 10 mil habitantes (população do mesmo ano) | calculada |
| `sem_agencia_2019` | 1 se o município não tinha agência em dez/2019 | calculada |
| `var_agencias` | `agencias_2019` − `agencias_2015` | calculada |
| `internet_2019` | Acessos de banda larga por 100 habitantes (população de 2019) | calculada |
| `ln_pibpc_2019` | ln(PIB per capita de 2019, em R$) | calculada |
| `ln_pop` | ln(população de 2022) | calculada |
| `ln_densidade` | ln(população de 2022 ÷ área) | calculada |
| `pct_idosos` | % da população com 60 anos ou mais (Censo 2022) | calculada |

## Fontes dos dados

- Banco Central do Brasil, Transações Pix por Município: https://dadosabertos.bcb.gov.br/dataset/pix/resource/268e3bf6-b096-4006-83cd-813697012ece
- Banco Central do Brasil, ESTBAN (Estatística Bancária por Município): https://www.bcb.gov.br/estatisticas/estatisticabancariamunicipios
- IBGE, SIDRA (tabelas 6579, 4714, 5938 e 9514): https://sidra.ibge.gov.br
- Anatel, Dados Abertos (acessos de banda larga fixa): https://www.gov.br/anatel/pt-br/dados/dados-abertos
