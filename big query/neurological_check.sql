WITH neuro_check AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    storetime,
    c.itemid,
    label,
    abbreviation,
    value
  FROM `physionet-data.mimiciv_icu.icustays` AS icu
  LEFT JOIN `physionet-data.mimiciv_icu.chartevents` AS c
  ON icu.subject_id = c.subject_id
  AND icu.hadm_id = c.hadm_id
  AND icu.stay_id = c.stay_id
  JOIN  `physionet-data.mimiciv_icu.d_items` AS d
  ON c.itemid = d.itemid
  WHERE c.itemid IN (SELECT itemid FROM `physionet-data.mimiciv_icu.d_items` WHERE category = 'Neurological')
),
neuro_check_value AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    label,
    MAX(value) AS value
  FROM neuro_check
  GROUP BY subject_id, hadm_id, stay_id, label
),
null_percentages AS (
  SELECT
    DISTINCT(label) AS label,
    (1 - COUNT(label) / (SELECT COUNT(DISTINCT(stay_id)) FROM `physionet-data.mimiciv_icu.icustays`)) * 100 AS null_percent
  FROM neuro_check_value
  GROUP BY label
),
--Choose lab items with less than 50% null
chosen_items AS (
  SELECT *
  FROM null_percentages
  WHERE null_percent < 50
),
--Table before pivot
final_table AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    CONCAT(
      'neuro_',
      --Replace unsupported characters in pivot
      LOWER(
        REPLACE(
          REPLACE(
            CASE
              WHEN CONTAINS_SUBSTR(label, ',') THEN REPLACE(label, ',', '')
              WHEN CONTAINS_SUBSTR(label, '(') THEN REPLACE(REPLACE(label, '(', ' '), ')', '')
              ELSE label
            END,
            ' ', '_'
          ),
          '_-_', '_'
        )
      )
     ) AS label,
    --Item gsc eye opening has value 'None' which is translated into null in Python
    CASE
      WHEN value = 'None' THEN 'No'
      ELSE value
    END AS value
  FROM neuro_check_value
  WHERE label IN (SELECT label FROM chosen_items)
)
--Pivot
SELECT *
FROM final_table
PIVOT(
  --Pivot needs an aggregate function
  --However, the value is already maxed, so one more max will not affect
  MAX(value) FOR label IN ('neuro_commands', 'neuro_commands_response', 'neuro_cough_reflex', 'neuro_facial_droop', 'neuro_gag_reflex', 'neuro_gcs_eye_opening', 'neuro_gcs_motor_response', 'neuro_gcs_verbal_response', 'neuro_orientation', 'neuro_pupil_response_left', 'neuro_pupil_response_right', 'neuro_pupil_size_left', 'neuro_pupil_size_right', 'neuro_speech', 'neuro_strength_l_arm', 'neuro_strength_l_leg', 'neuro_strength_r_arm', 'neuro_strength_r_leg')
  --After IN must be a constant list, can not be dynamic
  --so the list of distinct label is queried and copied then pasted
)
ORDER BY subject_id, hadm_id, stay_id
