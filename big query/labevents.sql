WITH labevents AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    stay_id,
    intime,
    outtime,
    l.itemid,
    label,
    charttime,
    storetime,
    valuenum,
    valueuom
  FROM `physionet-data.mimiciv_hosp.labevents` AS l
  LEFT JOIN `physionet-data.mimiciv_icu.icustays` AS icu
  ON l.hadm_id = icu.hadm_id
  AND l.subject_id = icu.subject_id
  JOIN `physionet-data.mimiciv_hosp.d_labitems` AS d
  ON l.itemid = d.itemid
  WHERE icu.hadm_id IS NOT NULL
  AND valuenum IS NOT NULL
  --One hadm_id can have multiple stay_ids, however, labevents are based on hadm_id only
  --and they have charttime, so the measures of each stay are determined by the time admitted to icu,
  --lab charttime and the time discharged from icu
  AND intime <= charttime
  AND outtime >= charttime
),
lab_percentile_99 AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    label,
    valuenum,
    PERCENTILE_CONT(valuenum, 0.99) OVER(PARTITION BY subject_id, hadm_id, stay_id, label) AS percentile_99,
    valueuom
  FROM labevents
  ORDER BY subject_id, hadm_id, stay_id
),
lab_value AS (
  SELECT
    subject_id,
    hadm_id,
    stay_id,
    label,
    ROUND(AVG(valuenum), 1) AS value,
    valueuom
  FROM lab_percentile_99
  --After drawing histogram, it is noticed that there are some significantly extreme and negative values
  --investigations were made, and the reason is that some values were falsely recorded
  --Using = to avoid when only one value was recorded, then take that value
  WHERE valuenum <= percentile_99  AND valuenum > 0
  GROUP BY subject_id, hadm_id, stay_id, label, valueuom
  ORDER BY subject_id, hadm_id, stay_id
),
--Caculate mean values before calculating null values
--because some items will be more available after the CT scan
null_percentages AS (
  SELECT
    DISTINCT(label) AS label,
    (1 - COUNT(label) / (SELECT COUNT(DISTINCT(stay_id)) FROM `physionet-data.mimiciv_icu.icustays`)) * 100 AS null_percent
  FROM lab_value
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
      'lab_',
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
          '__', '_'
        )
      )
     ) AS label,
    value
  FROM lab_value
  WHERE label IN (SELECT label FROM chosen_items)
)

--Pivot
SELECT *
FROM final_table
PIVOT(
  --Pivot needs an aggregate function
  --However, the value is already averaged, so one more average will not affect
  AVG(value) FOR label IN ('lab_anion_gap', 'lab_bicarbonate', 'lab_calcium_total', 'lab_calculated_total_co2', 'lab_chloride', 'lab_creatinine', 'lab_glucose', 'lab_hematocrit', 'lab_hemoglobin', 'lab_inr_pt', 'lab_lactate', 'lab_magnesium', 'lab_mch', 'lab_mchc', 'lab_mcv', 'lab_pco2', 'lab_ph', 'lab_phosphate', 'lab_platelet_count', 'lab_po2', 'lab_potassium', 'lab_pt', 'lab_ptt', 'lab_rdw', 'lab_red_blood_cells', 'lab_sodium', 'lab_urea_nitrogen', 'lab_white_blood_cells')
  --After IN must be a constant list, can not be dynamic
  --so the list of distinct label is queried and copied then pasted
)
ORDER BY subject_id, hadm_id
