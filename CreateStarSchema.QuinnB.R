# title: Create Fact Table
# subtitle: CS3200 / Final Project
# author: Brianna Quinn
# date: Summer 2 2024

# Load libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(RMySQL, RSQLite)

# Remote MySQL settings come from environment variables (see README)
db_name_fh <- Sys.getenv("DB_NAME")
db_user_fh <- Sys.getenv("DB_USER")
db_host_fh <- Sys.getenv("DB_HOST")
db_pwd_fh <- Sys.getenv("DB_PASSWORD")
db_port_fh <- as.integer(Sys.getenv("DB_PORT", "3306"))

# Connect to remote server database
mydb_fh <- dbConnect(RMySQL::MySQL(), 
                     user = db_user_fh, 
                     password = db_pwd_fh,
                     dbname = db_name_fh, 
                     host = db_host_fh, 
                     port = db_port_fh)

# Connect to SQLite database
conn_sqlite <- dbConnect(RSQLite::SQLite(), dbname = "db.sqlite")

# Drop the product_facts table if it exists
dbExecute(mydb_fh, "DROP TABLE IF EXISTS product_facts")

# Create product_facts table
dbExecute(mydb_fh, "
CREATE TABLE product_facts (
  prodName VARCHAR(255) NOT NULL,
  month INT NOT NULL,
  year INT NOT NULL,
  country VARCHAR(255) NOT NULL,
  totalAmount NUMERIC NOT NULL,
  totalUnits NUMERIC NOT NULL,
  PRIMARY KEY (prodName, month, year, country)
)")

# Get list of partitioned tables from SQLite
partitioned_tables <- dbGetQuery(conn_sqlite, "
SELECT name 
FROM sqlite_master 
WHERE type = 'table' AND name LIKE 'Sales_%'
")$name

# Prepare to aggregate data from partitioned tables
for (table_name in partitioned_tables) {
  fetch_data_query <- sprintf("
    SELECT 
      p.prodName, 
      strftime('%%m', s.date) AS month, 
      strftime('%%Y', s.date) AS year, 
      s.country, 
      SUM(s.qty * p.unitCost) AS totalAmount,
      SUM(s.qty) AS totalUnits
    FROM %s s
    JOIN Products p ON s.fk_prodID = p.prodID
    GROUP BY p.prodName, strftime('%%m', s.date), strftime('%%Y', s.date), s.country
  ", table_name)
  
  # Fetch data from partitioned table
  sales_data <- dbGetQuery(conn_sqlite, fetch_data_query)
  
  # Insert data into MySQL
  dbWriteTable(mydb_fh, "product_facts", sales_data, append = TRUE, row.names = FALSE)
}

# Function to query data from MySQL
query_mydb <- function(query) {
  dbGetQuery(mydb_fh, query)
}

# Analytical Queries
# a) Total amount sold in each month of 2022 for 'Clobromizen'
result_c <- query_mydb("
SELECT month, SUM(totalAmount) AS totalAmountSold
FROM product_facts
WHERE year = 2022 AND prodName = 'Clobromizen'
GROUP BY month
ORDER BY month")
print(result_c)

# b) Units sold in Brazil in 2022 for 'Xipralofen'
result_x <- query_mydb("
SELECT SUM(totalUnits) AS totalUnitsSold
FROM product_facts
WHERE year = 2022 AND country = 'Brazil' AND prodName = 'Xipralofen'
")
print(result_x)

# Close connections
if (dbIsValid(conn_sqlite)) {
  dbDisconnect(conn_sqlite)
}

if (dbIsValid(mydb_fh)) {
  dbDisconnect(mydb_fh)
}