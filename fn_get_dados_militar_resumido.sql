-- FUNCTION: dbsingular_requerimento.fn_get_dados_militar_resumido_siape(text)

-- DROP FUNCTION dbsingular_requerimento.fn_get_dados_militar_resumido_siape(text);

CREATE OR REPLACE FUNCTION dbsingular_requerimento.fn_get_dados_militar_resumido(
	siape text)
    RETURNS TABLE(
		cod_pessoa_servidor bigint, 
		nom_completo_pessoa character varying, 
		vlr_identificacao_unica character varying, 
		dsc_posto_graduacao character varying, 
		sgl_quadro character varying, 
		datainclusao text, 
		data_nascimento text, 
		num_cpf_pessoa character varying, 
		lotacao character varying, 
		ra_obm character varying, 
		area text,
		sgl_posto_graduacao character varying,
		sgl_lotacao character varying
	) 
    LANGUAGE 'sql'

   
AS $BODY$

SELECT DISTINCT
--------- DADOS ---------------------------------------------------------------------------
ts.cod_pessoa_servidor,
tp.nom_completo_pessoa,
ts.vlr_identificacao_unica,
tpg.dsc_posto_graduacao,
tq.sgl_quadro,
to_char(ts.dat_inclusao, 'DD/MM/YYYY') AS DATAINCLUSAO,
to_char(tp.dat_nascimento_pessoa, 'DD/MM/YYYY') AS DATA_NASCIMENTO,
tp.num_cpf_pessoa, 
--LOTACAO ATUAL
o.nom_orgao AS LOTACAO,
ttr.nom_ra_cidade AS RA_OBM,
--tloc.dsc_localidade,

CASE WHEN tt.flg_area_meio = TRUE THEN 'MEIO'
            WHEN tt.flg_area_meio = FALSE THEN 'FIM'
       END AS AREA,
tpg.sgl_posto_graduacao,
o.sgl_orgao 

--------- FIM DOS DADOS ---------------------------------------------------------------------
--------- JOINS -----------------------------------------------------------------------------
FROM corporativo.tb_pessoa tp

INNER JOIN rh.tb_servidor ts ON ts.cod_pessoa_servidor = tp.cod_pessoa
LEFT JOIN rh.tb_controle_status_servidor tcss ON tcss.cod_pessoa_servidor = ts.cod_pessoa_servidor 
INNER JOIN rh.tb_controle_status_servidor_tipo tcsst ON tcsst.cod_controle_status_servidor_tipo = tcss.cod_controle_status_servidor_tipo

LEFT JOIN corporativo.tb_sexo tsexo ON tsexo.cod_sexo = tp.cod_sexo
LEFT JOIN rh.tb_lotacao tl ON tl.cod_pessoa_servidor = ts.cod_pessoa_servidor
----------LOTAÇÃO ATUAL --------------------------------------------------------------
LEFT JOIN rh.tb_publicacao_lotacao pl ON pl.cod_pessoa_servidor = tl.cod_pessoa_servidor
	AND pl.dat_lotacao = tl.dat_lotacao
LEFT JOIN corporativo.tb_orgao o ON o.cod_orgao = tl.cod_orgao
----------FIM DA LOTAÇÃO ATUAL -------------------------------------------------------
LEFT JOIN corporativo.tb_tipo_documento td ON td.cod_tipo_documento = pl.cod_tipo_documento
LEFT JOIN dados.tt_orgao tt ON tt.cod_orgao = tl.cod_orgao
LEFT JOIN dados.tt_ra ttr ON ttr.cod_ra_cidade = tt.cod_ra_cidade
----------POSTO GRADUACAO ------------------------------------------------------------------
INNER JOIN rh.tb_promocao_servidor tps ON tps.cod_pessoa_servidor = ts.cod_pessoa_servidor
INNER JOIN rh.tb_posto_graduacao tpg ON tpg.cod_posto_graduacao = tps.cod_posto_graduacao
----------FIM DO POSTO GRADUACAO ------------------------------------------------------------------
----------RACA COR ETNIA ------------------------------------------------------------------
LEFT JOIN corporativo.tb_raca_cor_etnia trce ON trce.cod_raca_cor_etnia = tp.cod_raca_cor_etnia
----------FIM RACA COR ETNIA --------------------------------------------------------------
---------- QUADRO -----------------------------------------------------------------------
INNER JOIN rh.tb_quadro_servidor tqs ON tqs.cod_pessoa_servidor = ts.cod_pessoa_servidor
INNER JOIN rh.tb_quadro tq ON tq.cod_quadro = tqs.cod_quadro
---------- FIM DO QUADRO ----------------------------------------------------------------
--------- FIM DOS JOINS -------------------------------------------------------------------

--------- CONDICOES ---------------------------------------------------------------------

WHERE ts.cod_pessoa_servidor IN
(
SELECT cod_pessoa_servidor FROM rh.tb_controle_status_servidor tcss2
	WHERE cod_controle_status_servidor_tipo != 10
	AND dat_status = 
	(
		SELECT MAX(dat_status) FROM rh.tb_controle_status_servidor
	 	WHERE cod_pessoa_servidor = tcss2.cod_pessoa_servidor
	)
)

AND tcss.dat_status =
	(SELECT max(dat_status) FROM rh.tb_controle_status_servidor tcss2
		WHERE cod_controle_status_servidor_tipo != 10
		and	cod_pessoa_servidor = tcss.cod_pessoa_servidor
	)

AND tps.dat_promocao_servidor = (	
	select max(dat_promocao_servidor) 
	from rh.tb_promocao_servidor 
	where cod_pessoa_servidor = ts.cod_pessoa_servidor	
	)
	
AND pl.dat_documento = (
	select max(dat_documento) from rh.tb_publicacao_lotacao
	where cod_pessoa_servidor = ts.cod_pessoa_servidor
	)

AND tqs.dat_ingresso_quadro = (
		SELECT MAX(dat_ingresso_quadro) FROM rh.tb_quadro_servidor
		WHERE cod_pessoa_servidor = ts.cod_pessoa_servidor
	)	
AND (ts.vlr_identificacao_unica = $1 OR tp.num_cpf_pessoa = $1)
--------- FIM DAS CONDICOES ---------------------------------------------------------------					  
GROUP BY ts.cod_pessoa_servidor, tp.nom_completo_pessoa, ts.vlr_identificacao_unica, tp.num_cpf_pessoa, tq.sgl_quadro,
tsexo.dsc_sexo, tp.dat_nascimento_pessoa, o.nom_orgao,
td.sgl_tipo_documento, pl.num_documento, pl.dat_documento ,tt.flg_area_meio, tps.dat_promocao_servidor,
tpg.dsc_posto_graduacao, tpg.cod_posto_graduacao, tl.dsc_lotacao, ttr.nom_ra_cidade, tpg.sgl_posto_graduacao,
o.sgl_orgao 

$BODY$;

ALTER FUNCTION dbsingular_requerimento.fn_get_dados_militar_resumido_siape(text)
    OWNER TO postgres;


