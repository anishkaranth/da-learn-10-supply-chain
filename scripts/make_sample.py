#!/usr/bin/env python3
"""Build the reproducible raw subset in data/raw/ from data/raw_full/.

Rule (deterministic, no randomness): keep every order line whose Order Id % 200 = 7, plus every line of the orders
that contain one of the 3 column-shifted customer addresses (Customer State holds a zip code), so every cleaning rule
is exercised (address repair, Spanish country names, canceled / fraud orders, the Oct-2017 regime change). Values are
copied verbatim (UTF-8 copy of the original Windows-1252 file), original 53 columns and header.
"""
import pathlib, duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = ROOT / "data/raw_full", ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
src = (FULL / "DataCoSupplyChainDataset.csv").as_posix()
con = duckdb.connect()
con.execute(f"""
COPY (
  SELECT * FROM read_csv('{src}', header = true, all_varchar = true)
  WHERE CAST("Order Id" AS BIGINT) % 200 = 7
     OR "Order Id" IN (SELECT "Order Id" FROM read_csv('{src}', header = true, all_varchar = true)
                       WHERE regexp_matches(trim("Customer State"), '^[0-9]+$'))
  ORDER BY CAST("Order Id" AS BIGINT), CAST("Order Item Id" AS BIGINT)
) TO '{(OUT / "DataCoSupplyChainDataset.csv").as_posix()}' (HEADER, DELIMITER ',')
""")
n = con.execute(f"SELECT COUNT(*), COUNT(DISTINCT \"Order Id\") FROM read_csv('{(OUT / 'DataCoSupplyChainDataset.csv').as_posix()}', all_varchar = true)").fetchone()
print("DataCoSupplyChainDataset.csv sample rows / orders:", n)
