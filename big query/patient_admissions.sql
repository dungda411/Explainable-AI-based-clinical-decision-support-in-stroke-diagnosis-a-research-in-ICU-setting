WITH patients AS(
  SELECT subject_id, gender, anchor_age, anchor_year
  FROM `physionet-data.mimiciv_hosp.patients`
)
SELECT
  a.subject_id,
  hadm_id,
  gender,
  anchor_age + EXTRACT(YEAR FROM admittime) - anchor_year AS age
FROM `physionet-data.mimiciv_hosp.admissions` AS a
JOIN patients AS p
ON a.subject_id = p.subject_id
WHERE anchor_age + EXTRACT(YEAR FROM admittime) - anchor_year >= 18
ORDER BY a.subject_id;
