# Uzbekistan school statistics: sources and confidence

Latest available year: **2025/2026** (stat.uz release of 31.03.2026). Previous year 2024/2025 is kept under `prev` for trend arrows.

| Field | Source | Reference date | Confidence |
|---|---|---|---|
| schools, privateSchools (non-state) | S1 table "Распределение числа действующих общих средних образовательных организаций по регионам" | start of 2025/2026 | High: exact counts, sums to 11,118 / 551 |
| pupils, girls, boys | S1 table "Распределение численности учащихся по регионам" (thousand, 1 dec.) | start of 2025/2026 | High: ±50 rounding, sums to 6,870.5k |
| firstGraders | S1 (excludes special-needs schools/classes) | start of 2025/2026 | High: sums to 725.3k |
| teachers (main staff, no part-timers) | S1 | start of 2025/2026 | High: sums to 577.7k |
| graduates9, graduates11 | S1 | calendar 2025 | High: sums to 506.1k / 452.5k |
| children6to17 | S3 SIAT: (women + men) x (6-7, 8-15, 16-17) | 1 Jan 2026 (prev: 1 Jan 2025) | High: exact, sums to 8,192,228 |
| prev.* | S2 (28.03.2025) + S3 | start of 2024/2025 | High; S2 text says Samarqand "1 135" schools but its table (1,335) is right |

- S1: https://stat.uz/img/news/obshchee-srednee-obrazovanie_p22745.pdf (Uzbek: https://stat.uz/img/news/umumij-urta-talim-lotin_p98371.pdf)
- S2: https://stat.uz/img/obshchee-srednee-obrazovanie_p92352.pdf
- S3: https://api.siat.stat.uz/media/uploads/sdmx/sdmx_data_{3134,3135,3136,3148,3149,3150}.json (district-level rows also available)
- Cross-checks: talimxabarlari.uz (02.04.2026, 06.05.2026) and stat.uz news 65201 repeat the same school and non-state numbers.
- Not available officially by region: IQ, subject mastery, interests, wellbeing and bullying. Those dashboard metrics stay synthetic demo data.
- Useful derived ratios: non-state share is 5.0% nationally, 28.8% in Toshkent shahri and 10.8% in Farg'ona. Pupils per school: 618 nationally, 1,118 in Toshkent shahri.
