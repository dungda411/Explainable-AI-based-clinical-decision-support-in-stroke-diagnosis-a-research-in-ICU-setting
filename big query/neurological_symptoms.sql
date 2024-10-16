WITH 
neuro_symptom AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    storetime,
    c.itemid,
    label,
    abbreviation,
    CONCAT(
      'symptom_',
      LOWER(value)
    ) AS value,
    ROW_NUMBER() OVER(PARTITION BY icu.subject_id, icu.hadm_id, icu.stay_id, value ORDER BY storetime) AS symptom_order
  FROM `physionet-data.mimiciv_icu.icustays` AS icu
  LEFT JOIN `physionet-data.mimiciv_icu.chartevents` AS c
  ON icu.subject_id = c.subject_id
  AND icu.hadm_id = c.hadm_id
  AND icu.stay_id = c.stay_id
  JOIN  `physionet-data.mimiciv_icu.d_items` AS d
  ON c.itemid = d.itemid
  WHERE c.itemid IN (228402, 223921) --Two code for Neurological symptoms
),
symptoms AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    REPLACE(
      REPLACE(
        value,
        ' ',
        '_'
      ),
      '/',
      '_'
    ) AS neurological_symptoms
  FROM neuro_symptom
  WHERE symptom_order = 1
)

SELECT *
FROM symptoms
PIVOT(
  COUNT(neurological_symptoms) FOR neurological_symptoms IN ('symptom_dizziness', 'symptom_double_vision', 'symptom_headache', 'symptom_nausea', 'symptom_nuchal_rigidity', 'symptom_numbness_tingling', 'symptom_nystagmus', 'symptom_photophobia', 'symptom_positional_changes', 'symptom_tremors', 'symptom_vertigo', 'symptom_vomiting')
)
