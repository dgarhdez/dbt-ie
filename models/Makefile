DB := ../my_database.duckdb

.PHONY: dbq stg-categories

# Usage:
#   make dbq              → list all tables
#   make dbq q="SELECT …" → run a single query
#   make dbq t=my_table   → preview first 50 rows of a table
stg-categories:
	duckdb $(DB) "SELECT * FROM stg_categories;"

dbq:
ifdef t
	duckdb $(DB) "SELECT * FROM $(t) LIMIT 50;"
else ifdef q
	duckdb $(DB) "$(q)"
else
	duckdb $(DB) ".tables"
endif
