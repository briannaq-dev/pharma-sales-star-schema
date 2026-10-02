# title: Create Analytics Database
# subtitle: CS3200 / Final Project
# author: Brianna Quinn
# date: Summer 2 2024



# Load libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(DBI, RSQLite, readr, dplyr, lubridate)

# Connect to SQLite db
conn <- dbConnect(RSQLite::SQLite(), dbname = "db.sqlite")

# Define the folder path
csv_folder <- "csv-data"

# List all CSV files
csv_files <- list.files(path = csv_folder, pattern = "\\.csv$", full.names = TRUE)

# Drop tables if they exist
drop_table_if_exists <- function(table_name) {
  dbExecute(conn, sprintf("DROP TABLE IF EXISTS %s", table_name))
}

# Function to create tables
create_table_if_not_exists <- function(query) {
  tryCatch({
    dbExecute(conn, query)
  }, error = function(e) {
    message("Error creating table: ", e$message)
  })
}

# Define table creation queries
table_queries <- list(
  Products = "
    CREATE TABLE Products (
      prodID INTEGER NOT NULL PRIMARY KEY,
      prodName TEXT NOT NULL UNIQUE,
      unitCost NUMERIC NOT NULL)",
  Sales = "
    CREATE TABLE Sales (
      txnID INTEGER NOT NULL PRIMARY KEY,
      date DATE NOT NULL,
      fk_prodID INTEGER NOT NULL,
      fk_custID INTEGER NOT NULL,
      qty NUMERIC NOT NULL CHECK(qty >= 0),
      country TEXT NOT NULL,
      FOREIGN KEY(fk_prodID) REFERENCES Products(prodID),
      FOREIGN KEY(fk_custID) REFERENCES Customers(custID))",
  Reps = "
    CREATE TABLE Reps (
      repID INTEGER NOT NULL PRIMARY KEY,
      repFN TEXT NOT NULL,
      repLN TEXT NOT NULL,
      repTR TEXT NOT NULL,
      repPh TEXT NOT NULL,
      repCm NUMERIC NOT NULL,
      repHireDate DATE NOT NULL)",
  Customers = "
    CREATE TABLE Customers (
      custID INTEGER NOT NULL PRIMARY KEY,
      custName TEXT NOT NULL UNIQUE)"
)

# Drop and create tables
for (table in names(table_queries)) {
  drop_table_if_exists(table)
  create_table_if_not_exists(table_queries[[table]])
}

# Initialize a counter for txnID
global_txnID_counter <- 1001

# Function to convert dates to YYYY-MM-DD format for sales data
convert_date_sales <- function(date_str) {
  tryCatch({
    as.character(format(mdy(date_str), "%Y-%m-%d"))
  }, error = function(e) {
    NA  # Return NA for any conversion issues
  })
}

# Handle different types of CSV files
load_and_insert_data <- function(file_path) {
  data <- read_csv(file_path)
  
  if (grepl("pharmaReps", file_path)) {
    data$repHireDate <- sapply(data$repHireDate, function(x) as.character(format(mdy(x), "%Y-%m-%d")))
    dbWriteTable(conn, "Reps", data, append = TRUE, row.names = FALSE)
    
  } else if (grepl("pharmaSalesTxn", file_path)) {
    data$date <- sapply(data$date, convert_date_sales)
    customers <- unique(data$cust)
    products <- unique(data$prod)
    
    # Insert new customers
    new_customers <- setdiff(customers, dbGetQuery(conn, "SELECT custName FROM Customers")$custName)
    if (length(new_customers) > 0) {
      dbWriteTable(conn, "Customers", data.frame(custName = new_customers, stringsAsFactors = FALSE), append = TRUE, row.names = FALSE)
    }
    
    # Insert new products
    product_df <- data %>% select(prod, unitcost) %>% distinct() %>% rename(prodName = prod, unitCost = unitcost)
    new_products <- setdiff(product_df$prodName, dbGetQuery(conn, "SELECT prodName FROM Products")$prodName)
    if (length(new_products) > 0) {
      dbWriteTable(conn, "Products", filter(product_df, prodName %in% new_products), append = TRUE, row.names = FALSE)
    }
    
    # Map names to IDs and transform data
    cust_id_map <- dbGetQuery(conn, "SELECT custID, custName FROM Customers")
    prod_id_map <- dbGetQuery(conn, "SELECT prodID, prodName FROM Products")
    data <- data %>%
      left_join(cust_id_map, by = c("cust" = "custName")) %>%
      left_join(prod_id_map, by = c("prod" = "prodName")) %>%
      select(date, fk_prodID = prodID, fk_custID = custID, qty, country) %>%
      mutate(txnID = global_txnID_counter + row_number() - 1)
    
    # Insert transformed data into Sales table
    dbWriteTable(conn, "Sales", data, append = TRUE, row.names = FALSE)
    
    # Update global txnID counter
    global_txnID_counter <<- max(data$txnID) + 1
  }
}

# Process each CSV file
for (file in csv_files) {
  load_and_insert_data(file)
}

# Function to create tables for a specific year
create_table_for_year <- function(year) {
  table_name <- sprintf("Sales_%d", year)
  drop_table_if_exists(table_name)
  query <- sprintf("
    CREATE TABLE %s (
      txnID INTEGER PRIMARY KEY,
      date DATE,
      fk_prodID INTEGER,
      fk_custID INTEGER,
      qty NUMERIC CHECK(qty >= 0),
      country TEXT,
      FOREIGN KEY(fk_prodID) REFERENCES Products(prodID),
      FOREIGN KEY(fk_custID) REFERENCES Customers(custID))", table_name)
  create_table_if_not_exists(query)
}

# Retrieve unique years from the Sales table
unique_years <- dbGetQuery(conn, "SELECT DISTINCT strftime('%Y', date) AS year FROM Sales")

# Create tables for each unique year
for (year in unique_years$year) {
  create_table_for_year(as.integer(year))
}

# Function to transfer data to the appropriate yearly table
transfer_data_to_yearly_tables <- function() {
  # Get unique years
  unique_years <- dbGetQuery(conn, "SELECT DISTINCT strftime('%Y', date) AS year FROM Sales")
  
  for (year in unique_years$year) {
    year <- as.integer(year)
    table_name <- sprintf("Sales_%d", year)
    query <- sprintf("
      INSERT INTO %s (txnID, date, fk_prodID, fk_custID, qty, country)
      SELECT txnID, date, fk_prodID, fk_custID, qty, country
      FROM Sales
      WHERE strftime('%%Y', date) = '%d'", table_name, year)
    dbExecute(conn, query)
  }
}

# Transfer data and drop original Sales table
transfer_data_to_yearly_tables()
dbExecute(conn, "DROP TABLE IF EXISTS Sales")

# Close connection
if (dbIsValid(conn)) {
  dbDisconnect(conn)
}