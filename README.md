# Pharma Sales Star Schema (R, SQLite, MySQL)
### Project for CS3200: Introduction to Databases SEC 02 S2 2024
Takes raw pharmaceutical sales data, loads it into a normalized relational database, builds a star-schema fact table, and answers business questions with SQL.

## Pipeline

| Step | File | What it does |
|------|------|--------------|
| 1 | `LoadXML2DB.QuinnB.R` | Creates a normalized SQLite schema (Products, Customers, Reps, Sales Transactions with keys and constraints) and loads the CSV batches into it |
| 2 | `CreateStarSchema.QuinnB.R` | Builds a `product_facts` fact table in a remote MySQL database, aggregated by product, time period and region, from the SQLite data |
| 3 | `DataAnalytics.QuinnB.Rmd` | R Notebook that runs analytical SQL against the fact table (e.g. monthly sales of a product, sales by region and quarter) and renders tables/charts |


## Running it

Requires R with `DBI`, `RSQLite`, `RMySQL`, `dplyr`, `readr`, `lubridate`, `kableExtra` (installed by `pacman` in the scripts).

1. Put the source CSVs in `csv-data/` (not included; they were provided by the course).
2. Run `LoadXML2DB.QuinnB.R` to create `db.sqlite`.
3. Set the MySQL connection as environment variables, then run the other two:
   ```
   DB_HOST=... DB_NAME=... DB_USER=... DB_PASSWORD=... DB_PORT=3306
   ```

## Skills shown
Relational schema design, normalization, ETL in R, dimensional modeling (star schema), SQL aggregation, reproducible reporting with R Markdown.
