# Data layout

| Path | What | In git |
|---|---|---|
| `raw/DataCoSupplyChainDataset.csv` | 903 raw order lines (322 orders), original 53 columns and header, verbatim text (UTF-8 copy of the cp1252 original). Rule in `scripts/make_sample.py`: every line whose `Order Id % 200 = 7`, plus every line of the orders that contain one of the 3 column-shifted customer addresses, so every cleaning rule is exercised (address repair, Spanish country names, canceled / fraud orders, the Oct-2017 regime change). | yes |
| `reference/country_es_en.csv` | Spanish → English names for all 164 `Order Country` values (hand-built lookup; every country is mapped, asserted in `sql/05`) | yes |
| `raw_full.sha256` | SHA-256 of the UTF-8 files the pipeline reads from `raw_full/` | yes |
| `raw_full/DataCoSupplyChainDataset.csv` | the full file (180,519 rows; 95,910,149 B original, 95,821,205 B as UTF-8 + LF), from `python scripts/download_full_data.py` | no (download) |
| `raw_full/DescriptionDataCoSupplyChain.csv` | column descriptions from the same Mendeley record | no (download) |
| `orig/` | untouched downloaded originals (Windows-1252, CRLF) | no |
| `clean/` | cleaned CSVs (`order_items.csv`, `orders.csv`) and `star/` from `python run_pipeline.py --source full` (~140 MB) | no — regenerate; Power BI uses the committed copies in `../powerbi/data/` |
