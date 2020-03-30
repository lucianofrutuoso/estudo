-- FUNCTION: dbsingular_requerimento.fn_get_dados_titular(text)

-- DROP FUNCTION dbsingular_requerimento.fn_get_dados_titular(text);


CREATE OR REPLACE FUNCTION dbsingular_requerimento.fn_select_dados_servidor_saude(
	cpf text)
    RETURNS TABLE(
		vlr_identificacao_unica character varying, 
		nom_completo_pessoa character varying, 
		num_cpf_pessoa character varying, 
		posto_graduacao character varying, 
		quadro character varying, 
		orgao character varying,
		email character varying,
		celular character varying,
		especializacao character varying,
		crm character varying) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$

--SERVIDOR
SELECT
ts.vlr_identificacao_unica,
tp.nom_completo_pessoa,
tp.num_cpf_pessoa,
tpg.sgl_posto_graduacao,
tq.sgl_quadro,
too.nom_orgao,
email.dsc_contato_pessoa,
celular.dsc_contato_pessoa,
tem.nom_especializacao_medica,
tes.crm_cro
FROM corporativo.tb_pessoa tp
-------	 DADOS DO SERVIDOR
left JOIN rh.tb_servidor ts ON ts.cod_pessoa_servidor = tp.cod_pessoa
	AND ts.cod_controle_status_servidor_tipo IN (13, 14)
	--13: ATIVO, 14: PTTC 
------- POSTO GRADUACAO
----------POSTO GRADUACAO ------------------------------------------------------------------
INNER JOIN (
			SELECT tpg.sgl_posto_graduacao AS sgl_posto_graduacao, tps.cod_pessoa_servidor AS cod_pessoa, tps.dat_promocao_servidor AS dat_promocao
			FROM rh.tb_promocao_servidor tps
			INNER JOIN rh.tb_posto_graduacao tpg ON tpg.cod_posto_graduacao = tps.cod_posto_graduacao) tpg ON tpg.cod_pessoa = ts.cod_pessoa_servidor 
				AND tpg.dat_promocao = (SELECT MAX(dat_promocao_servidor)
										FROM rh.tb_promocao_servidor 
										WHERE cod_pessoa_servidor = tpg.cod_pessoa)
------FIM DO POSTO GRADUACAO ------------------------------------------------------------------
---------- QUADRO -----------------------------------------------------------------------
INNER JOIN (
			SELECT 	tq.sgl_quadro AS sgl_quadro, tqs.cod_pessoa_servidor AS cod_pessoa, tqs.dat_ingresso_quadro AS dat_quadro, tq.cod_quadro AS cod_quadro
			FROM rh.tb_quadro_servidor tqs
			INNER JOIN rh.tb_quadro tq ON tq.cod_quadro = tqs.cod_quadro) tq ON tq.cod_pessoa = ts.cod_pessoa_servidor
				AND tq.dat_quadro = (SELECT MAX(dat_ingresso_quadro)
												FROM rh.tb_quadro_servidor
												WHERE cod_pessoa_servidor = tq.cod_pessoa)
---------- FIM DO QUADRO ----------------------------------------------------------------
----------LOTAÇÃO ATUAL --------------------------------------------------------------
LEFT JOIN rh.tb_lotacao tl ON tl.cod_pessoa_servidor = ts.cod_pessoa_servidor
LEFT JOIN rh.tb_publicacao_lotacao pl ON pl.cod_pessoa_servidor = tl.cod_pessoa_servidor
	AND pl.dat_lotacao = tl.dat_lotacao
LEFT JOIN corporativo.tb_orgao too ON too.cod_orgao = tl.cod_orgao
----------FIM DA LOTAÇÃO ATUAL --------------------------------------------------------------
----------CONTATO --------------------------------------------------------------
LEFT JOIN corporativo.tb_contato_pessoa email ON email.cod_pessoa = ts.cod_pessoa_servidor AND email.cod_tipo_contato = 4 AND email.flg_preferencial = TRUE
LEFT JOIN corporativo.tb_contato_pessoa celular ON celular.cod_pessoa = ts.cod_pessoa_servidor AND celular.cod_tipo_contato = 2 AND celular.flg_preferencial = TRUE
----------FIM DO CONTATO --------------------------------------------------------------
----------ESPECIALIZAÇÃO --------------------------------------------------------------
LEFT JOIN saude.tb_especializacaomedica_servidor tes ON tes.cod_pessoa_servidor = ts.cod_pessoa_servidor AND tes.cod_quadro = tq.cod_quadro
LEFT JOIN saude.tb_especializacao_medica tem ON tem.cod_especializacao_medica = tes.cod_especializacao_medica
----------FIM DA ESPECIALIZAÇÃO --------------------------------------------------------------
WHERE (tp.num_cpf_pessoa = $1 OR ts.vlr_identificacao_unica = $1)

$BODY$;

ALTER FUNCTION dbsingular_requerimento.fn_get_dados_titular(text)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION dbsingular_requerimento.fn_select_dados_servidor_saude TO postgres;

GRANT EXECUTE ON FUNCTION dbsingular_requerimento.fn_select_dados_servidor_saude TO user_singular;
