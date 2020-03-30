/*
	V28.03.20
	- INSERT tb_parecer_cid;
	- INSERT tb_observacao_parecer;
	V30.03.20
	- INSERT cod_sessao_encerramento := cod_sessao
	- Turno vespertino = T
	- dsc_parecer é a obervação outros
	- flg_bloqueado
*/


CREATE OR REPLACE FUNCTION dbsingular_requerimento.fn_insert_dados_dispensa_medica(
	usuario_logado character varying,
	dat_hora_atendimento date,
	flg_escala_servico boolean,
	dsc_arr_finalidade character varying,
	cpf_paciente character varying,
	finalidade_inspecao character varying,
	dat_inicio_afastamento date,
	qtd_dias_afastamento integer,
	dsc_parecer character varying,
	cod_cid character varying,
	diagnostico character varying,
	obs_parecer text,
	
	/* RESTRIÇÕES */
	socorro boolean,
	expediente boolean,
	interno boolean,
	educacao_fisica boolean,
	treinamento boolean,
	mergulho boolean,
	motorista boolean,
	formaturas boolean,
	posse_arma boolean,
	outros boolean	
)
    
RETURNS integer[]
LANGUAGE 'plpgsql'

COST 100
VOLATILE 
AS $BODY$

DECLARE
	
	codd_sessao bigint;
	codd_usuario bigint;
	cod_servidor bigint;
	cod_paciente bigint;
	retorno integer[];
	codd_documento int;
	codd_finalidade integer;
	codd_parecer integer;
	flgg_apto integer;
	flgg_incapaz integer;
	flgg_nao_homologado boolean;
	flgg_nao_aplicavel boolean;
	flgg_curso boolean;
	flgg_outroparecer boolean;
	flgg_parecerpendente boolean;
	check_insert timestamp;
	flgg_turno character varying;
	codd_diagnostico integer;
		
	cont integer;
	array_restricao boolean[11];
	tipo_restricao integer;

	usuario_logado ALIAS FOR $1;
	dat_atendimento ALIAS FOR $2;
	flg_escala ALIAS FOR $3;
	dsc_finalidade ALIAS FOR $4;
	cpf_paciente ALIAS FOR $5;
	finalidade_inspecao ALIAS FOR $6;
	dat_inicio_afastamento ALIAS FOR $7;
	qtd_dias_afastamento ALIAS FOR $8;
	dscc_parecer ALIAS FOR $9;
	codd_cid ALIAS FOR $10;
	diagnostico ALIAS FOR $11;
	obss_parecer ALIAS FOR $12;
	
BEGIN
	
	flgg_nao_aplicavel := NULL;
	flgg_incapaz := 1;
	flgg_apto := 1;
	flgg_nao_homologado := NULL;
	flgg_curso := NULL;
	flgg_outroparecer := NULL;
	flgg_parecerpendente := NULL;
	
	cont := 1;
	array_restricao[1] = socorro;
	array_restricao[2] = expediente;
	array_restricao[3] = interno;
	array_restricao[4] = educacao_fisica;
	array_restricao[5] = treinamento;
	array_restricao[6] = mergulho;
	array_restricao[7] = motorista;
	array_restricao[8] = formaturas;
	array_restricao[9] = posse_arma;
	array_restricao[10] = outros;

	/* PEGA O COD PESSOA PERITO*/
	cod_servidor := (
		SELECT cod_pessoa_servidor
		FROM rh.tb_servidor
		WHERE vlr_identificacao_unica = usuario_logado
		
		UNION
		
		SELECT cod_pessoa
		FROM corporativo.tb_pessoa
		WHERE num_cpf_pessoa = usuario_logado
		
	);
	
	/* PEGA O COD PESSOA PACIENTE*/
	cod_paciente := (
		SELECT cod_pessoa_servidor
		FROM rh.tb_servidor
		WHERE vlr_identificacao_unica = cpf_paciente
		
		UNION
		
		SELECT cod_pessoa
		FROM corporativo.tb_pessoa
		WHERE num_cpf_pessoa = cpf_paciente		
	);
	
	/* PEGA O USUÁRIO DO PERITO NA TB_USUARIO */
	
	codd_usuario := (
		SELECT cod_usuario
		FROM seguranca.tb_usuario 
		WHERE cod_pessoa = cod_servidor	
	);
	
	/*PEGA A SESSÃO */
	codd_sessao := (
		SELECT cod_sessao
		FROM cpmed.tb_sessao
		WHERE CAST(dat_hora_abertura_sessao AS DATE) = CAST(now() AS DATE)
		AND (dat_hora_fechamento_sessao IS NULL OR dat_hora_fechamento_sessao = NULL)
		AND (flg_bloqueado = FALSE OR flg_bloqueado = NULL or flg_bloqueado IS NULL)
		ORDER BY cod_sessao DESC LIMIT 1
	);
	
	/* PEGA A FINALIDADE */
	CASE 
		WHEN fn_trata_acento(dsc_finalidade) ILIKE '%LTSP)' THEN
			codd_finalidade := 1;
		WHEN fn_trata_acento(dsc_finalidade) ILIKE '%VAF)' THEN
			codd_finalidade := 3;
		WHEN fn_trata_acento(dsc_finalidade) ILIKE '%LTSPF)' THEN
			codd_finalidade := 6;
		WHEN fn_trata_acento(dsc_finalidade) ILIKE '%MATERNIDADE%' THEN
			codd_finalidade := 7;
		ELSE
			codd_finalidade := 999;
	END CASE;
	
	/* PEGA O PARECER */
	IF fn_trata_acento(dscc_parecer) ILIKE 'APTO%' THEN
		
		CASE 
			WHEN fn_trata_acento(dscc_parecer) ILIKE '%RESTRICOES' THEN
				flgg_apto := 3;
				flgg_incapaz := 1;
			ELSE
				flgg_apto := 2;
				flgg_incapaz := 1;
		END CASE;
	
	ELSEIF fn_trata_acento(dscc_parecer) ILIKE 'INCAPAZ%' THEN
	
		CASE 
			WHEN fn_trata_acento(dscc_parecer) ILIKE '%TEMPORARIAMENTE%' THEN
				flgg_apto := 1;
				flgg_incapaz := 2;
			ELSE
				flgg_apto := 1;
				flgg_incapaz := 3;
		END CASE;
		
	ELSE
	
		IF fn_trata_acento(dscc_parecer) = 'NAO HOMOLOGADO' THEN
			flgg_nao_homologado := TRUE;
		ELSEIF fn_trata_acento(dscc_parecer) = 'NAO SE APLICA' THEN
			flgg_nao_aplicavel := TRUE;
		ELSEIF fn_trata_acento(dscc_parecer) = 'CURSOS' THEN
			flgg_curso := TRUE;
		ELSEIF fn_trata_acento(dscc_parecer) = 'OUTRO PARECER' THEN
			flgg_outroparecer := TRUE;
		ELSEIF fn_trata_acento(dscc_parecer) = 'PARECER PENDENTE' THEN
			flgg_parecerpendente := TRUE;
		ELSE flgg_outroparecer := TRUE;
		END IF;
		
	END IF;
	
	/* GERA O TURNO */
	CASE	
		WHEN current_time BETWEEN '00:00:00' AND '11:59:59' THEN flgg_turno := 'M';
		ELSE  flgg_turno := 'T';
	END CASE;
	
	/* GERA O CÓDIGO DO DIAGNOSTICO */
	CASE
		WHEN upper(diagnostico) = 'ETIOLOGIA' THEN 
			codd_diagnostico := 1;
		WHEN upper(diagnostico) = 'ANATÔMICO' THEN 
			codd_diagnostico := 2;
		WHEN upper(diagnostico) = 'FUNCIONAL' THEN 
			codd_diagnostico := 3;
	END CASE;

/* ********************************************** */
	
	/* GERANDO DOCUMENTO */
	INSERT INTO workflow.tb_documento
	(
		cod_tipo_documento,
		cod_estado_documento,
		nom_documento,
		dat_inclusao_documento,
		cod_usuario
	)
	VALUES
	(
		213,
		807,
		CONCAT('documento_ata_inspecao_saude_', cod_paciente,'_', codd_sessao, '_', now()),
		now(),
		codd_usuario
	) RETURNING tb_documento.cod_documento INTO codd_documento;
	
	/*INSERE DADOS PARECER MÉDICO */
	INSERT INTO cpmed.tb_parecer_medico
	(	
		cod_medico_perito,
		cod_criador_registro, 
		cod_sessao,
		cod_sessao_encerramento,
		dat_criacao,  
		dsc_parecer, 
		flg_apto, 
		flg_incapaz, 
		flg_nao_homologado,
		flg_nao_aplicavel, 
		flg_curso_apto,
		flg_outro_parecer,
		flg_parecer_pendente,
		qtd_duracao_restricao, 
		dat_inicio_restricao, 
		flg_turno, 
		flg_bloqueado
	)
	VALUES 
	( 
		cod_servidor,
		cod_servidor, 
		codd_sessao,
		codd_sessao,
		now(), 
		upper(dscc_parecer), 
		flgg_apto,-- integer
		flgg_incapaz,--integer		
		flgg_nao_homologado, 
		flgg_nao_aplicavel,			
		flgg_curso,
		flgg_outroparecer,
		flgg_parecerpendente,
		qtd_dias_afastamento::integer, 
		CAST(dat_inicio_afastamento AS date),
		flgg_turno,
		FALSE
	)RETURNING tb_parecer_medico.cod_parecer_medico INTO codd_parecer;
	
	/*GERANDO A ATA DE INSPEÇÃO*/	
	INSERT INTO cpmed.tb_ata_inspecao_saude
	(
		cod_pessoa,
		cod_sessao,
		dat_hora_atendimento,
		dat_hora_criacao,
		cod_documento,
		flg_escala_servico,
		dsc_arr_finalidade,
		cod_parecer_medico
	)
	VALUES
	(
		cod_paciente,
		codd_sessao,
		dat_atendimento,
		now(),
		codd_documento,
		flg_escala,
		dsc_finalidade,
		codd_parecer
	) RETURNING tb_ata_inspecao_saude.dat_hora_criacao INTO check_insert;


	/* INSERINDO O USUÁRIO FINALIDADE */	
	INSERT INTO cpmed.tb_usuario_atend_finalidade
	(
		cod_finalidade, 
		cod_pessoa, 
		cod_sessao, 
		dat_hora_atendimento, 
		flg_informado, 
		flg_bloqueado, 
		dat_hora_criacao
	)
	VALUES 
	(
		codd_finalidade, 
		cod_paciente, 
		codd_sessao, 
		dat_atendimento, 
		FALSE, 
		FALSE,
		check_insert
	);	

	/* INSERIDO O CID */
	INSERT INTO cpmed.tb_parecer_cid
	(
		cod_parecer_medico,
		cod_cid,
		cod_tipo_diagnostico
	)
	VALUES
	(
		codd_parecer,
		codd_cid,
		codd_diagnostico
	);
	
	/* INSERIR OBSERVAÇÃO DO PARECER */
	IF (CHAR_LENGTH(obss_parecer) > 0) THEN
	
		INSERT INTO cpmed.tb_observacoes_parecer
		(
			cod_parecer_medico,
			cod_pessoa_servidor,
			dsc_observacoes,
			flg_bloqueado
		)
		VALUES
		(
			codd_parecer,
			cod_servidor,
			obss_parecer,
			FALSE
		);
		
	END IF;

	/* RESTRIÇÕES */
	
	WHILE cont < 11 LOOP

		IF cont = 10 THEN
			tipo_restricao := 99999;
		ELSE
			tipo_restricao := cont;
		END IF;
		
		INSERT INTO cpmed.tb_parecer_tipo_restricao
		(
			cod_tipo_restricao,
			cod_parecer_medico,
			flg_decisao_restricao
		)
		VALUES
		(
			tipo_restricao,
			codd_parecer,
			array_restricao[cont]
		);
		
		cont := cont + 1;	

	END LOOP;

	retorno[1] := cod_servidor;
	retorno[2] := codd_sessao;
	retorno[3] := codd_parecer;
	
	RETURN retorno;

	
END
$BODY$;

GRANT EXECUTE ON FUNCTION dbsingular_requerimento.fn_insert_dados_dispensa_medica TO postgres;

GRANT EXECUTE ON FUNCTION dbsingular_requerimento.fn_insert_dados_dispensa_medica TO user_singular;

/*
SELECT dbsingular_requerimento.fn_insert_dados_dispensa_medica(
	'1521474', 
	'2020-03-30', 
	FALSE, 
	'LTSP)', 
	'67006949149', 
	'LTSP)', 
	'2020-03-30', 
	15, 
	'INCAPAZ TEMPORARIAMENTE para o serviço do CBMDF',
	'A009',
	'ETIOLOGIA',
	'Teste observação parecer',
	TRUE, 
	FALSE, 
	FALSE, 
	TRUE, 
	TRUE, 
	TRUE, 
	FALSE, 
	TRUE, 
	FALSE, 
	FALSE
)
*/
