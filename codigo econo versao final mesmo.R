# 
# MONTAGEM DA BASE (criacao_base.R) - #############################################
#
#
# # montagem da base - pix e agencias bancarias nos municipios
# # gera o arquivo base_pix_municipios.csv usado no codigo do trabalho
#
# # pacotes (install.packages so na primeira vez)
# # install.packages(c("readr", "jsonlite", "sidrar", "estbanr"))
# library(readr)
# library(jsonlite)   # le a api do banco central
# library(sidrar)     # baixa tabelas do ibge
# library(estbanr)    # baixa a estban do banco central
# options(timeout = 1200)
#
#
# # etapa 1 - pix por municipio em 2025 (banco central)
#
# url_pix <- "https://olinda.bcb.gov.br/olinda/servico/Pix_DadosAbertos/versao/v1/odata/TransacoesPixPorMunicipio(DataBase=@DataBase)?@DataBase='202501'&$format=json&$filter=AnoMes%20le%20202512&$select=AnoMes,Municipio_Ibge,Municipio,Estado,QT_PagadorPF,QT_PES_PagadorPF&$top=100000"
# pix_bruto <- fromJSON(url_pix)$value
# pix_bruto <- subset(pix_bruto, !is.na(Municipio_Ibge))
#
# # conferencia: 12 meses e cerca de 5.570 municipios
# unique(pix_bruto$AnoMes)
# length(unique(pix_bruto$Municipio_Ibge))
#
# # total de transacoes no ano e media mensal de pessoas que pagaram com pix
# pix_trans <- aggregate(QT_PagadorPF ~ Municipio_Ibge + Municipio + Estado, data = pix_bruto, FUN = sum)
# pix_pess  <- aggregate(QT_PES_PagadorPF ~ Municipio_Ibge, data = pix_bruto, FUN = mean)
# pix <- merge(pix_trans, pix_pess, by = "Municipio_Ibge")
# names(pix) <- c("cod_ibge", "municipio", "uf", "pix_transacoes_pf_2025", "pix_pessoas_pf_media_mensal_2025")
# pix$pix_pessoas_pf_media_mensal_2025 <- round(pix$pix_pessoas_pf_media_mensal_2025)
# nrow(pix)
#
#
# # etapa 2 - dados do ibge (sidra)
#
# # populacao estimada de 2015 e 2019 (tabela 6579)
# pop15 <- get_sidra(api = "/t/6579/n6/all/v/9324/p/2015")
# pop15 <- data.frame(cod_ibge = as.numeric(pop15[["Município (Código)"]]), pop_2015 = pop15$Valor)
#
# pop19 <- get_sidra(api = "/t/6579/n6/all/v/9324/p/2019")
# pop19 <- data.frame(cod_ibge = as.numeric(pop19[["Município (Código)"]]), pop_2019 = pop19$Valor)
#
# # censo 2022: populacao e area (tabela 4714)
# censo <- get_sidra(api = "/t/4714/n6/all/v/93/p/2022")
# pop22 <- data.frame(cod_ibge = as.numeric(censo[["Município (Código)"]]), pop_2022 = censo$Valor,
#                     nome = censo[["Município"]])
#
# area <- get_sidra(api = "/t/4714/n6/all/v/6318/p/2022")
# area <- data.frame(cod_ibge = as.numeric(area[["Município (Código)"]]), area_km2 = area$Valor)
#
# # pib de 2019 em mil reais (tabela 5938)
# pib <- get_sidra(api = "/t/5938/n6/all/v/37/p/2019")
# pib <- data.frame(cod_ibge = as.numeric(pib[["Município (Código)"]]), pib_2019_mil = pib$Valor)
#
# # pessoas com 60 anos ou mais no censo 2022 (tabela 9514)
# # a tabela e grande, entao baixamos um estado de cada vez
# # pega os codigos das idades de 60+ em rondonia (estado pequeno)
# x <- get_sidra(api = "/t/9514/n6/in%20n3%2011/v/93/p/2022/c287/allxt")
# cats <- unique(x[, c("Idade (Código)", "Idade")])
# anos_cat <- suppressWarnings(as.numeric(sub(" anos?$", "", cats$Idade)))
# cod_60 <- cats[["Idade (Código)"]][(anos_cat >= 60 & grepl("^[0-9]+ anos?$", cats$Idade)) |
#                                      cats$Idade == "100 anos ou mais"]
# length(cod_60)   # esperado: 41
#
# # baixa so essas idades, um estado de cada vez
# codigos_uf <- c(11:17, 21:29, 31:33, 35, 41:43, 50:53)
# idade <- data.frame()
# for (u in codigos_uf) {
#   x <- get_sidra(api = paste0("/t/9514/n6/in%20n3%20", u, "/v/93/p/2022/c287/",
#                               paste(cod_60, collapse = ",")))
#   idade <- rbind(idade, data.frame(cod_ibge = as.numeric(x[["Município (Código)"]]), valor = x$Valor))
# }
# idosos <- aggregate(valor ~ cod_ibge, data = idade, FUN = sum)
# names(idosos) <- c("cod_ibge", "pop_60mais_2022")
#
# # conferencia: o brasil tinha cerca de 32,1 milhoes de pessoas com 60 anos ou mais
# sum(idosos$pop_60mais_2022)
#
#
# # etapa 3 - agencias bancarias em dez/2015 e dez/2019 (estban)
#
# # o pacote estban ja traz o codigo do ibge de cada municipio (coluna codmun_ibge)
# est19 <- estban_read(estban_download("201912", level = "municipio"))
# names(est19) <- tolower(names(est19))
# est19 <- data.frame(uf = est19$uf, municipio = est19$municipio,
#                     cod_ibge = as.numeric(est19$codmun_ibge),
#                     agencias = as.numeric(est19$agen_esperadas))
#
# est15 <- estban_read(estban_download("201512", level = "municipio"))
# names(est15) <- tolower(names(est15))
# est15 <- data.frame(uf = est15$uf, municipio = est15$municipio,
#                     cod_ibge = as.numeric(est15$codmun_ibge),
#                     agencias = as.numeric(est15$agen_esperadas))
#
# # regioes administrativas do df entram como brasilia
# est19$cod_ibge[est19$uf == "DF"] <- 5300108
# est15$cod_ibge[est15$uf == "DF"] <- 5300108
#
# # algumas linhas vem sem o codigo do ibge; descartamos
# est19 <- subset(est19, !is.na(cod_ibge))
# est15 <- subset(est15, !is.na(cod_ibge))
# # conferencia: linhas sem codigo do ibge (o ideal e zero)
# sum(is.na(est19$cod_ibge))
# sum(is.na(est15$cod_ibge))
#
# # soma as agencias de todos os bancos em cada municipio
# ag19 <- aggregate(agencias ~ cod_ibge, data = est19, FUN = sum)
# ag15 <- aggregate(agencias ~ cod_ibge, data = est15, FUN = sum)
# names(ag19) <- c("cod_ibge", "agencias_dez2019")
# names(ag15) <- c("cod_ibge", "agencias_dez2015")
#
# # conferencia: codigos da estban que nao existem no ibge (o ideal e zero)
# sum(!(ag19$cod_ibge %in% pop22$cod_ibge))
# sum(!(ag15$cod_ibge %in% pop22$cod_ibge))
#
# # etapa 4 - banda larga fixa em dez/2019 (anatel)
#
# # se o download nao funcionar, baixe o arquivo na pagina de dados abertos da anatel
# # (acessos - banda larga fixa) e coloque na mesma pasta deste script
# if (!file.exists("acessos_banda_larga_fixa.zip")) {
#   download.file("https://www.anatel.gov.br/dadosabertos/paineis_de_dados/acessos/acessos_banda_larga_fixa.zip",
#                 "acessos_banda_larga_fixa.zip", mode = "wb")
# }
# arquivos <- unzip("acessos_banda_larga_fixa.zip", list = TRUE)$Name
# arquivos   # conferir o nome do arquivo de 2019
# arq_2019 <- arquivos[grepl("2019", arquivos)][1]
# unzip("acessos_banda_larga_fixa.zip", files = arq_2019)
#
# bl <- read_csv2(arq_2019, show_col_types = FALSE)
# names(bl)   # conferir o nome das colunas
# bl <- subset(bl, Ano == 2019 & `Mês` == 12)
# bl <- data.frame(cod_ibge = as.numeric(bl$`Código IBGE Município`), banda_larga_dez2019 = bl$Acessos)
# bl <- aggregate(banda_larga_dez2019 ~ cod_ibge, data = bl, FUN = sum)
# nrow(bl)
#
#
# # etapa 5 - juntar tudo pelo codigo do ibge e criar as variaveis
#
# base <- merge(pix, pop15, by = "cod_ibge")
# base <- merge(base, pop19, by = "cod_ibge")
# base <- merge(base, pop22[, c("cod_ibge", "pop_2022")], by = "cod_ibge")
# base <- merge(base, area, by = "cod_ibge")
# base <- merge(base, pib, by = "cod_ibge")
# base <- merge(base, idosos, by = "cod_ibge")
# base <- merge(base, bl, by = "cod_ibge")
# base <- merge(base, ag15, by = "cod_ibge", all.x = TRUE)
# base <- merge(base, ag19, by = "cod_ibge", all.x = TRUE)
#
# # quem nao aparece na estban nao tinha agencia
# base$agencias_dez2015[is.na(base$agencias_dez2015)] <- 0
# base$agencias_dez2019[is.na(base$agencias_dez2019)] <- 0
#
# # variaveis do trabalho
# base$pix_usuarios      <- base$pix_pessoas_pf_media_mensal_2025 / base$pop_2022 * 100
# base$ln_pix_transacoes <- log(base$pix_transacoes_pf_2025 / base$pop_2022)
# base$agencias_2019     <- base$agencias_dez2019 / base$pop_2019 * 10000
# base$agencias_2015     <- base$agencias_dez2015 / base$pop_2015 * 10000
# base$sem_agencia_2019  <- ifelse(base$agencias_dez2019 == 0, 1, 0)
# base$var_agencias      <- base$agencias_2019 - base$agencias_2015
# base$internet_2019     <- base$banda_larga_dez2019 / base$pop_2019 * 100
# base$ln_pibpc_2019     <- log(base$pib_2019_mil * 1000 / base$pop_2019)
# base$ln_pop            <- log(base$pop_2022)
# base$ln_densidade      <- log(base$pop_2022 / base$area_km2)
# base$pct_idosos        <- base$pop_60mais_2022 / base$pop_2022 * 100
#
# # conferencia
# nrow(base)                    # esperado: 5.570
# sum(base$sem_agencia_2019)    # esperado: perto de 2.331
# summary(base)                 # nenhuma variavel deve ter NA
#
# base$pop_60mais_2022 <- NULL
#
# write_csv(base, "base_pix_municipios_nova.csv")
#
#
# # etapa 6 - comparar com a base usada no trabalho
#
# antiga <- read_csv("/Users/gabrielrodrigues/Downloads/base_pix_municipios (1).csv", show_col_types = FALSE)
# comp <- merge(antiga, base, by = "cod_ibge", suffixes = c("_antiga", "_nova"))
# nrow(comp)
#
# # diferenca maxima entre a base antiga e a nova (o ideal e perto de zero)
# max(abs(comp$pix_usuarios_antiga - comp$pix_usuarios_nova))
# max(abs(comp$ln_pix_transacoes_antiga - comp$ln_pix_transacoes_nova))
# max(abs(comp$agencias_2019_antiga - comp$agencias_2019_nova))
# max(abs(comp$agencias_2015_antiga - comp$agencias_2015_nova))
# max(abs(comp$internet_2019_antiga - comp$internet_2019_nova))
# max(abs(comp$ln_pibpc_2019_antiga - comp$ln_pibpc_2019_nova))
# max(abs(comp$ln_pop_antiga - comp$ln_pop_nova))
# max(abs(comp$ln_densidade_antiga - comp$ln_densidade_nova))
# max(abs(comp$pct_idosos_antiga - comp$pct_idosos_nova))
#
# 
# FIM DA MONTAGEM DA BASE ######################################
# 

pacotes <- c("readr", "lmtest", "sandwich", "car", "stargazer", "ggplot2")
faltando <- pacotes[!pacotes %in% rownames(installed.packages())]
if (length(faltando) > 0) install.packages(faltando)

library(readr)
library(lmtest)
library(sandwich)
library(car)
library(stargazer)
library(ggplot2)
base <- read_csv("https://raw.githubusercontent.com/gl9528562-creator/PIX-E-AGENCIAS-BANCARIAS-NOS-MUNICIPIOS-BRASILEIROS/main/base_pix_municipios.csv",
                 show_col_types = FALSE)

base_limpa <- subset(base, pix_usuarios <= 100 & internet_2019 <= 100)

nrow(base)
nrow(base_limpa)
nrow(base) - nrow(base_limpa)

modelo <- lm(ln_pix_transacoes~ agencias_2019 + ln_pibpc_2019 + internet_2019 +
               ln_densidade + ln_pop + pct_idosos + var_agencias+ factor(uf),data = base_limpa)
modelo2 <- lm(ln_pix_transacoes ~ agencias_2019 + sem_agencia_2019 + var_agencias +
                ln_pibpc_2019 + internet_2019 + ln_densidade + ln_pop + pct_idosos +
                factor(uf), data = base_limpa)

coeftest(modelo2, vcov = vcovHC(modelo2, type = "HC1"))

# teste conjunto: H0 = agencias_2019 e sem_agencia_2019 são ambos zero
linearHypothesis(modelo2, c("agencias_2019 = 0", "sem_agencia_2019 = 0"),
                 vcov = vcovHC(modelo2, type = "HC1"))


coeftest(modelo, vcov = vcovHC(modelo, type = "HC1"))

summary(base_limpa)
sum(base_limpa$agencias_2019 == 0, na.rm = TRUE)

# figura 3 - uso do pix por faixa de agencias
faixa <- cut(base_limpa$agencias_2019,
             breaks = c(-Inf, 0, 0.5, 1, 1.5, 2, Inf),
             labels = c("0", "(0; 0,5]", "(0,5; 1]", "(1; 1,5]", "(1,5; 2]", "> 2"))
fig3 <- data.frame(faixa = levels(faixa),
                   media = as.vector(tapply(base_limpa$ln_pix_transacoes, faixa, mean)),
                   n = as.vector(table(faixa)))
fig3$faixa <- factor(fig3$faixa, levels = fig3$faixa)

g3 <- ggplot(fig3, aes(faixa, media, group = 1)) +
  geom_line(color = "grey50") +
  geom_point(size = 3, color = "#2166AC") +
  geom_text(aes(label = paste("n =", n)), vjust = -1, size = 3) +
  labs(x = "Agências por 10 mil habitantes (2019)",
       y = "Média de ln(transações Pix per capita)") +
  theme_minimal()
print(g3)
ggsave("figura3.png", g3, width = 8, height = 5, dpi = 300)
# regressoes em sequencia

# m1 - so agencias
m1 <- lm(ln_pix_transacoes ~ agencias_2019, data = base_limpa)

# m2 - com controles
m2 <- lm(ln_pix_transacoes ~ agencias_2019 + ln_pibpc_2019 + internet_2019 +
           ln_densidade + ln_pop + pct_idosos, data = base_limpa)

# m3 - com efeito fixo de uf
m3 <- lm(ln_pix_transacoes ~ agencias_2019 + ln_pibpc_2019 + internet_2019 +
           ln_densidade + ln_pop + pct_idosos + factor(uf), data = base_limpa)

# erros robustos
coeftest(m1, vcov = vcovHC(m1, type = "HC1"))
coeftest(m2, vcov = vcovHC(m2, type = "HC1"))
coeftest(m3, vcov = vcovHC(m3, type = "HC1"))

# correlacao entre as variaveis de agencia
cor(base_limpa$agencias_2019, base_limpa$sem_agencia_2019, use = "complete.obs")

# robustez com y = % de usuarios de pix
rob <- lm(pix_usuarios ~ agencias_2019 + sem_agencia_2019 + var_agencias +
            ln_pibpc_2019 + internet_2019 + ln_densidade + ln_pop + pct_idosos +
            factor(uf), data = base_limpa)
coeftest(rob, vcov = vcovHC(rob, type = "HC1"))

# teste conjunto na robustez
linearHypothesis(rob, c("agencias_2019 = 0", "sem_agencia_2019 = 0"),
                 vcov = vcovHC(rob, type = "HC1"))

# teste de white
bptest(modelo2, ~ fitted(modelo2) + I(fitted(modelo2)^2))

# multicolinearidade - vif
vif(modelo2)

# numeros citados no texto

# efeito exato da ausencia de agencia (em %)
100 * (exp(coef(modelo2)["sem_agencia_2019"]) - 1)

# diferenca bruta entre sem e com agencia (em %)
medias <- tapply(base_limpa$ln_pix_transacoes, base_limpa$sem_agencia_2019, mean)
100 * (exp(medias["1"] - medias["0"]) - 1)

# media de transacoes pix por habitante
mean(base_limpa$pix_transacoes_pf_2025 / base_limpa$pop_2022)

# % de idosos por faixa de agencias
tapply(base_limpa$pct_idosos, faixa, mean)

# intervalos de confianca em %
100 * (exp(coefci(m3, parm = "agencias_2019", vcov. = vcovHC(m3, type = "HC1"))) - 1)
100 * (exp(coefci(modelo2, parm = "sem_agencia_2019", vcov. = vcovHC(modelo2, type = "HC1"))) - 1)

# tabela de estatisticas descritivas
desc <- as.data.frame(base_limpa[, c("ln_pix_transacoes", "pix_usuarios", "agencias_2019",
                                     "sem_agencia_2019", "var_agencias", "ln_pibpc_2019",
                                     "internet_2019", "ln_densidade", "ln_pop", "pct_idosos")])
stargazer(desc, type = "text", digits = 2)

# figura 1 - matriz de correlacao
vars_cor <- c("ln_pix_transacoes", "pix_usuarios", "agencias_2019", "sem_agencia_2019",
              "var_agencias", "ln_pibpc_2019", "internet_2019", "ln_densidade",
              "ln_pop", "pct_idosos")
nomes_cor <- c("ln Pix per capita", "% usuários", "Agências/10 mil", "Sem agência",
               "Var. agências", "ln PIB per capita", "Banda larga", "ln densidade",
               "ln pop.", "% idosos")
cm <- cor(base_limpa[, vars_cor], use = "complete.obs")
dimnames(cm) <- list(nomes_cor, nomes_cor)
cm_df <- as.data.frame(as.table(cm))

g1 <- ggplot(cm_df, aes(Var2, Var1, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", Freq)), size = 2.5) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC",
                       limits = c(-1, 1), name = "Correlação") +
  scale_y_discrete(limits = rev(nomes_cor)) +
  labs(x = NULL, y = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(g1)
ggsave("figura1.png", g1, width = 8, height = 6, dpi = 300)

# figura 2 - distribuicao das principais variaveis
vars_dist <- c("ln_pix_transacoes", "pix_usuarios", "agencias_2019",
               "ln_pibpc_2019", "internet_2019", "pct_idosos")
nomes_dist <- c("ln Pix per capita", "% usuários", "Agências/10 mil",
                "ln PIB per capita", "Banda larga", "% idosos")
dist_df <- data.frame(
  variavel = factor(rep(nomes_dist, each = nrow(base_limpa)), levels = nomes_dist),
  valor = unlist(base_limpa[, vars_dist], use.names = FALSE))
medianas <- aggregate(valor ~ variavel, data = dist_df, FUN = median)

g2 <- ggplot(dist_df, aes(valor)) +
  geom_histogram(aes(y = after_stat(density)), bins = 40, fill = "grey80", color = "grey30") +
  geom_vline(data = medianas, aes(xintercept = valor),
             linetype = "dashed", color = "darkred") +
  facet_wrap(~ variavel, scales = "free") +
  labs(x = NULL, y = "Densidade") +
  theme_minimal()
print(g2)
ggsave("figura2.png", g2, width = 9, height = 5, dpi = 300)
# erros padrao robustos para as tabelas
ep <- function(m) sqrt(diag(vcovHC(m, type = "HC1")))

# tabela das regressoes em sequencia
stargazer(m1, m2, m3, modelo, modelo2,
          se = list(ep(m1), ep(m2), ep(m3), ep(modelo), ep(modelo2)),
          omit = "uf",
          add.lines = list(c("EF de UF", "Não", "Não", "Sim", "Sim", "Sim")),
          omit.stat = c("ser", "f"),
          type = "text", digits = 4)

# tabela modelo principal x robustez
stargazer(modelo2, rob,
          se = list(ep(modelo2), ep(rob)),
          omit = "uf",
          add.lines = list(c("EF de UF", "Sim", "Sim")),
          omit.stat = c("ser", "f"),
          type = "text", digits = 4)

# figura 4 - intervalos de confianca
modelos <- list(m1, m2, m3, modelo, modelo2)
ic_ag <- do.call(rbind, lapply(seq_along(modelos), function(i) {
  ci <- coefci(modelos[[i]], parm = "agencias_2019",
               vcov. = vcovHC(modelos[[i]], type = "HC1"))
  data.frame(modelo = paste0("(", i, ")"), variavel = "Agências por 10 mil hab.",
             coef = coef(modelos[[i]])["agencias_2019"], inf = ci[1], sup = ci[2])
}))
ci_sem <- coefci(modelo2, parm = "sem_agencia_2019",
                 vcov. = vcovHC(modelo2, type = "HC1"))
ic_sem <- data.frame(modelo = "(5)", variavel = "Sem agência",
                     coef = coef(modelo2)["sem_agencia_2019"], inf = ci_sem[1], sup = ci_sem[2])
ic <- rbind(ic_ag, ic_sem)
ic$variavel <- factor(ic$variavel, levels = c("Agências por 10 mil hab.", "Sem agência"))

g4 <- ggplot(ic, aes(modelo, coef)) +
  geom_hline(yintercept = 0, color = "grey40") +
  geom_errorbar(aes(ymin = inf, ymax = sup), width = 0.2, color = "#B2182B") +
  geom_point(size = 3, color = "#2166AC") +
  facet_wrap(~ variavel, scales = "free") +
  labs(x = "Modelo", y = "Coeficiente (IC 95%, HC1)") +
  theme_minimal()
print(g4)
ggsave("figura4.png", g4, width = 8, height = 4.5, dpi = 300)

# =============================================================================
# 3. Tabelas em LaTeX para o relatório e diagnósticos citados no texto
# =============================================================================
dir.create("tabelas", showWarnings = FALSE)
rotulos <- c("agencias\\\\_2019" = "Agências por 10 mil hab. (2019)",
             "sem\\\\_agencia\\\\_2019" = "Sem agência (2019)",
             "var\\\\_agencias" = "Var. agências 2015--2019",
             "ln\\\\_pibpc\\\\_2019" = "ln PIB per capita (2019)",
             "internet\\\\_2019" = "Banda larga por 100 hab. (2019)",
             "ln\\\\_densidade" = "ln densidade",
             "ln\\\\_pop" = "ln população",
             "pct\\\\_idosos" = "\\\\% idosos",
             "ln\\\\_pix\\\\_transacoes" = "ln transações Pix per capita (2025)",
             "pix\\\\_usuarios" = "\\\\% usuários Pix (2025)",
             "Constant" = "Constante", "Observations" = "Observações",
             "Adjusted R\\$\\^\\{2\\}\\$" = "R$^{2}$ ajustado",
             "Statistic" = "Variável", "St\\. Dev\\." = "Desvio-padrão", "Mean" = "Média",
             "\\{Min\\}" = "{Mín.}", "\\{Max\\}" = "{Máx.}")
traduz <- function(linhas) { for (k in names(rotulos)) linhas <- gsub(k, rotulos[[k]], linhas); linhas }
grava <- function(linhas, arquivo) writeLines(traduz(linhas), file.path("tabelas", arquivo), useBytes = TRUE)
notas_pt <- c("$^{*}$p$<$0,1; $^{**}$p$<$0,05; $^{***}$p$<$0,01.", "Erros-padrão robustos (HC1) entre parênteses.")

grava(capture.output(stargazer(desc, type = "latex", digits = 2, header = FALSE, table.placement = "H",
                               title = "Estatísticas descritivas", label = "tab:descritivas", font.size = "footnotesize",
                               decimal.mark = ",", digit.separator = ".")), "tab_descritivas.tex")

grava(capture.output(stargazer(m1, m2, m3, modelo, modelo2,
                               se = list(ep(m1), ep(m2), ep(m3), ep(modelo), ep(modelo2)),
                               omit = "uf", add.lines = list(c("EF de UF", "Não", "Não", "Sim", "Sim", "Sim")),
                               omit.stat = c("ser", "f"), type = "latex", digits = 4, header = FALSE, table.placement = "H",
                               title = "Determinantes do uso do Pix (MQO com erros-padrão robustos HC1)", label = "tab:principal",
                               dep.var.caption = "\\textit{Variável dependente:}", font.size = "footnotesize",
                               notes = notas_pt, notes.append = FALSE, notes.label = "Notas:",
                               decimal.mark = ",", digit.separator = ".")), "tab_principal.tex")

grava(capture.output(stargazer(modelo2, rob,
                               se = list(ep(modelo2), ep(rob)),
                               omit = "uf", add.lines = list(c("EF de UF", "Sim", "Sim")),
                               omit.stat = c("ser", "f"), type = "latex", digits = 4, header = FALSE, table.placement = "H",
                               title = "Modelo principal e robustez com a proporção de usuários do Pix", label = "tab:robustez",
                               dep.var.caption = "\\textit{Variável dependente:}", font.size = "footnotesize",
                               notes = notas_pt, notes.append = FALSE, notes.label = "Notas:",
                               decimal.mark = ",", digit.separator = ".")), "tab_robustez.tex")