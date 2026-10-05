-- 00_duckdb_compat.sql  (DuckDB ONLY)
-- Spark SQL function shims so that 02-05 can be written in Spark SQL dialect and still execute unchanged on DuckDB.
-- On Spark/Databricks these functions are built in.
CREATE OR REPLACE MACRO percentile_approx(x, p) AS quantile_cont(x, p);
-- Spark: try_to_timestamp(s, 'M/d/yyyy H:mm'). DuckDB's strptime accepts the non-padded month/day/hour of this file.
CREATE OR REPLACE MACRO try_to_timestamp(s, fmt) AS try_strptime(s, '%m/%d/%Y %H:%M');
-- Spark: datediff(end_date, start_date) -> whole days.
CREATE OR REPLACE MACRO datediff(e, s) AS date_diff('day', CAST(s AS DATE), CAST(e AS DATE));
-- Spark: regexp_like(str, pattern) (alias of RLIKE).
CREATE OR REPLACE MACRO regexp_like(s, p) AS regexp_matches(s, p);
