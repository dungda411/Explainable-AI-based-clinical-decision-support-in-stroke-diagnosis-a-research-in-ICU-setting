WITH 
vital_sign AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    storetime,
    c.itemid,
    label,
    abbreviation,
    value,
    valuenum
  FROM `physionet-data.mimiciv_icu.icustays` AS icu
  LEFT JOIN `physionet-data.mimiciv_icu.chartevents` AS c
  ON icu.subject_id = c.subject_id
  AND icu.hadm_id = c.hadm_id
  AND icu.stay_id = c.stay_id
  JOIN  `physionet-data.mimiciv_icu.d_items` AS d
  ON c.itemid = d.itemid
  --WHERE c.itemid IN (220210, 220277, 220045, 220179, 220181, 223762)
),
vital_sign_99_percentile AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    CONCAT(
      'vital_',
      REPLACE(
        abbreviation,
        ' ',
        '_'
      )
    ) AS label,
    PERCENTILE_CONT(valuenum, 0.99) OVER(PARTITION BY subject_id, hadm_id, stay_id, label) AS percentile_99,
    valuenum
  FROM vital_sign
),
vital_sign_value AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    label,
    ROUND(AVG(valuenum), 1) AS value
  FROM vital_sign_99_percentile
  --After drawing histogram, it is noticed that there are some significantly extreme and negative values
  --investigations were made, and the reason is that some values were falsely recorded
  --Using = to avoid when only one value was recorded, then take that value
  WHERE valuenum <= percentile_99 AND valuenum > 0
  GROUP BY subject_id, hadm_id, stay_id, label
)
--Pivot
SELECT *
FROM vital_sign_value
PIVOT(
  AVG(value) FOR label IN ('vital_NBPs', 'vital_NBPm', 'vital_NBPd', 'vital_Temperature_C', 'vital_Temperature_F', 'vital_RR', 'vital_HR', 'vital_SpO2')
)
ORDER BY subject_id, hadm_id, stay_id
