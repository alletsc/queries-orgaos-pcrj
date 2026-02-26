-- Queries para validação dos dados de frequencia e frequencia_acumulada
 -- Verificar frequências negativas nos modelos de frequência                
                                                                              
  -- 1. Verificar faltas negativas ou número de aulas negativas no modelo base
  WITH faltas_negativas AS (                                
    SELECT
      'vw_alunos_aulas' AS tabela,
      id_aluno,
      id_matricula_turma,
      id_disciplina_turma,
      data_aula,
      falta,
      numeroAulas,
      CASE
        WHEN falta < 0 THEN 'Faltas negativas'
        WHEN numeroAulas < 0 THEN 'Número de aulas negativas'
        WHEN falta > numeroAulas THEN 'Faltas maior que número de aulas'
      END AS tipo_problema
    FROM `rj-sme.educacao_basica_frequencia.vw_alunos_aulas`
    WHERE falta < 0
       OR numeroAulas < 0
       OR falta > numeroAulas
  ),

  -- 2. Verificar valores negativos no modelo de frequência acumulada
  frequencia_acumulada_negativa AS (
    SELECT
      'frequencia_acumulada' AS tabela,
      id_aluno,
      numero_faltas,
      numero_aulas,
      frequencia_percentual,
      CASE
        WHEN numero_faltas < 0 THEN 'Número de faltas negativo'
        WHEN numero_aulas < 0 THEN 'Número de aulas negativo'
        WHEN frequencia_percentual < 0 THEN 'Frequência percentual negativa'
        WHEN frequencia_percentual > 100 THEN 'Frequência percentual maior que 100%'
        WHEN numero_faltas > numero_aulas THEN 'Faltas maior que aulas'
      END AS tipo_problema
    FROM `rj-sme.educacao_basica_frequencia.frequencia_acumulada`
    WHERE numero_faltas < 0
       OR numero_aulas < 0
       OR frequencia_percentual < 0
       OR frequencia_percentual > 100
       OR numero_faltas > numero_aulas
  ),

  -- 3. Verificar valores negativos no modelo frq_frequencia
  frequencia_dia_negativa AS (
    SELECT
      'frequencia' AS tabela,
      id_aluno,
      id_matricula_turma,
      id_disciplina_turma,
      data_aula,
      faltas_disciplina_dia,
      numero_aula,
      CASE
        WHEN faltas_disciplina_dia < 0 THEN 'Faltas negativas'
        WHEN numero_aula < 0 THEN 'Número de aulas negativas'
        WHEN faltas_disciplina_dia > numero_aula THEN 'Faltas maior que número de aulas'
      END AS tipo_problema
    FROM `rj-sme.educacao_basica_frequencia.frequencia`
    WHERE faltas_disciplina_dia < 0
       OR numero_aula < 0
       OR faltas_disciplina_dia > numero_aula
  )

  -- Combinar todos os resultados
  SELECT * FROM faltas_negativas
  UNION ALL
  SELECT
    tabela,
    id_aluno,
    NULL AS id_matricula_turma,
    NULL AS id_disciplina_turma,
    NULL AS data_aula,
    numero_faltas AS falta,
    numero_aulas AS numeroAulas,
    tipo_problema
  FROM frequencia_acumulada_negativa
  UNION ALL
  SELECT * FROM frequencia_dia_negativa
  ORDER BY tabela, id_aluno, data_aula;

-- Resumo de problemas encontrados por tabela
  SELECT
    'vw_alunos_aulas - Faltas negativas' AS verificacao,
    COUNT(*) AS total_registros
  FROM `rj-sme.educacao_basica_frequencia.vw_alunos_aulas`
  WHERE falta < 0

  UNION ALL

  SELECT
    'vw_alunos_aulas - NumeroAulas negativo',
    COUNT(*)
  FROM `rj-sme.educacao_basica_frequencia.vw_alunos_aulas`
  WHERE numeroAulas < 0

  UNION ALL

  SELECT
    'frequencia_acumulada - Faltas negativas',
    COUNT(*)
  FROM `rj-sme.educacao_basica_frequencia.frequencia_acumulada`
  WHERE numero_faltas < 0

  UNION ALL

  SELECT
    'frequencia_acumulada - Aulas negativas',
    COUNT(*)
  FROM `rj-sme.educacao_basica_frequencia.frequencia_acumulada`
  WHERE numero_aulas < 0

  UNION ALL

  SELECT
    'frequencia_acumulada - Frequência percentual negativa',
    COUNT(*)
  FROM `rj-sme.educacao_basica_frequencia.frequencia_acumulada`
  WHERE frequencia_percentual < 0

  ORDER BY verificacao;

 -- Identificar casos de alunos com faltas > número de aulas na tabela frequencia                                                                          
  SELECT                                                                              
    id_aluno,                                                                         
    id_matricula_turma,                                                               
    id_matricula_disciplina,                                                          
    id_disciplina_turma,                                                              
    data_aula,                                                                        
    faltas_disciplina_dia,
    numero_aula,
    (faltas_disciplina_dia - numero_aula) AS diferenca,
    coordenacao_regional,
    id_turma,
    id_escola,
    nome_disciplina,
    ano_calendario
  FROM `rj-sme.educacao_basica_frequencia.frequencia`
  WHERE faltas_disciplina_dia > numero_aula
  ORDER BY id_aluno, data_aula;


-- Resumo por aluno dos casos
  SELECT
    id_aluno,
    COUNT(*) AS qtd_ocorrencias,
    COUNT(DISTINCT id_matricula_turma) AS qtd_matriculas,
    COUNT(DISTINCT id_disciplina_turma) AS qtd_disciplinas,
    MIN(data_aula) AS primeira_ocorrencia,
    MAX(data_aula) AS ultima_ocorrencia,
    SUM(faltas_disciplina_dia - numero_aula) AS total_diferenca,
    MAX(faltas_disciplina_dia - numero_aula) AS maior_diferenca
  FROM `rj-sme.educacao_basica_frequencia.frequencia`
  WHERE faltas_disciplina_dia > numero_aula
  GROUP BY id_aluno
  ORDER BY qtd_ocorrencias DESC;


-- Lista única dos IDs de alunos afetados
  SELECT DISTINCT id_aluno
  FROM `rj-sme.educacao_basica_frequencia.frequencia`
  WHERE faltas_disciplina_dia > numero_aula
  ORDER BY id_aluno;

 -- Identificar alunos com problemas e sua etapa de ensino
  SELECT
    f.id_aluno,
    f.id_matricula_turma,
    f.id_turma,
    f.data_aula,
    f.faltas_disciplina_dia,
    f.numero_aula,
    (f.faltas_disciplina_dia - f.numero_aula) AS diferenca,
    cur.descricao_periodo,
    CASE
      WHEN UPPER(cur.descricao_periodo) LIKE '%FUNDAMENTAL I%' OR UPPER(cur.descricao_periodo) LIKE '%1º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%2º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%3º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%4º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%5º ANO%'
  THEN 'Fundamental I'
      WHEN UPPER(cur.descricao_periodo) LIKE '%FUNDAMENTAL II%' OR UPPER(cur.descricao_periodo) LIKE '%6º  ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%7º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%8º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%9º ANO%' THEN 'Fundamental II'
      WHEN UPPER(cur.descricao_periodo) LIKE '%FUNDAMENTAL%' THEN 'Fundamental (verificar)'
      ELSE 'Outra etapa'
    END AS etapa_ensino
  FROM `rj-sme.educacao_basica_frequencia.frequencia` AS f
  INNER JOIN `rj-sme.brutos_gestao_escolar.tur_turma` AS tur
    ON f.id_turma = CAST(tur.tur_id AS STRING)
  INNER JOIN `rj-sme.brutos_gestao_escolar.turma_curriculo` AS tcr
    ON tur.tur_id = tcr.id_turma
    AND tcr.id_situacao = '1'
  INNER JOIN `rj-sme.brutos_gestao_escolar.curriculo_periodo` AS cur
    ON tcr.id_curso = cur.id_curso
  WHERE f.faltas_disciplina_dia > f.numero_aula
  ORDER BY etapa_ensino, f.id_aluno, f.data_aula;

 -- Ver a etapa de ensino dos casos com faltas > número de aulas
  SELECT
    f.id_aluno,
    f.id_matricula_turma,
    f.id_turma,
    f.data_aula,
    f.faltas_disciplina_dia,
    f.numero_aula,
    (f.faltas_disciplina_dia - f.numero_aula) AS diferenca,
    cur.descricao_periodo,
    CASE
      WHEN UPPER(cur.descricao_periodo) LIKE '%FUNDAMENTAL I%' OR UPPER(cur.descricao_periodo) LIKE '%1º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%2º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%3º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%4º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%5º ANO%' THEN 'Fundamental I'
      WHEN UPPER(cur.descricao_periodo) LIKE '%FUNDAMENTAL II%' OR UPPER(cur.descricao_periodo) LIKE '%6º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%7º ANO%' OR UPPER(cur.descricao_periodo) LIKE '%8º ANO%'
           OR UPPER(cur.descricao_periodo) LIKE '%9º ANO%' THEN 'Fundamental II'
      ELSE 'Outra etapa'
    END AS etapa_ensino
  FROM `rj-sme.educacao_basica_frequencia.frequencia` AS f
  INNER JOIN `rj-sme.brutos_gestao_escolar.tur_turma` AS tur
    ON f.id_turma = CAST(tur.tur_id AS STRING)
  INNER JOIN `rj-sme.brutos_gestao_escolar.turma_curriculo` AS tcr
    ON tur.tur_id = tcr.id_turma
    AND tcr.id_situacao = '1'
  INNER JOIN `rj-sme.brutos_gestao_escolar.curriculo_periodo` AS cur
    ON tcr.id_curso = cur.id_curso
  WHERE f.faltas_disciplina_dia > f.numero_aula
  ORDER BY etapa_ensino, f.id_aluno, f.data_aula;

 -- Query para análise por Grupamento e Situação
  WITH frequencia_por_aluno AS (                                                                  
    SELECT                                                  
      f.id_aluno,
      a.cpf,
      a.Grupamento,
      a.Situacao,
      SUM(f.numero_faltas) AS numero_faltas_total,
      SUM(f.numero_aulas) AS numero_aulas_total,
      SAFE_DIVIDE(SUM(f.numero_faltas), SUM(f.numero_aulas)) AS proporcao_faltas,
      1 - SAFE_DIVIDE(SUM(f.numero_faltas), SUM(f.numero_aulas)) AS frequencia_acumulada
    FROM rj-sme.educacao_basica_frequencia.frequencia_acumulada_dias_letivos f
    INNER JOIN rj-sme.brutos_gestao_escolar.vw_bi_aluno a
      ON f.id_aluno = CAST(a.alu_id AS STRING)
    GROUP BY f.id_aluno, a.cpf, a.Grupamento, a.Situacao
  )

  SELECT
    Grupamento,
    Situacao,
    COUNT(DISTINCT id_aluno) AS qtd_alunos,
    ROUND(AVG(frequencia_acumulada) * 100, 2) AS frequencia_media_percentual,
    COUNT(CASE WHEN frequencia_acumulada < 0.75 THEN 1 END) AS alunos_abaixo_75,
    COUNT(CASE WHEN frequencia_acumulada < 0 THEN 1 END) AS alunos_frequencia_negativa,
    COUNT(CASE WHEN proporcao_faltas > 1 THEN 1 END) AS alunos_faltas_maior_aulas
  FROM frequencia_por_aluno
  GROUP BY Grupamento, Situacao
  ORDER BY frequencia_media_percentual;


  -- Top 20 alunos com menor frequência
  WITH frequencia_por_aluno AS (
    SELECT
      f.id_aluno,
      a.cpf,
      a.Grupamento,
      a.Situacao,
      SUM(f.numero_faltas) AS numero_faltas_total,
      SUM(f.numero_aulas) AS numero_aulas_total,
      1 - SAFE_DIVIDE(SUM(f.numero_faltas), SUM(f.numero_aulas)) AS frequencia_acumulada
    FROM rj-sme.educacao_basica_frequencia.frequencia_acumulada_dias_letivos f
    INNER JOIN rj-sme.brutos_gestao_escolar.vw_bi_aluno a
      ON f.id_aluno = CAST(a.alu_id AS STRING)
    GROUP BY f.id_aluno, a.cpf, a.Grupamento, a.Situacao
  )

  SELECT *
  FROM frequencia_por_aluno
  WHERE Situacao = 'Ativo'
  ORDER BY frequencia_acumulada ASC
  LIMIT 20;
