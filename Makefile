dbq:
	@duckdb my_database.duckdb -c "$(filter-out $@,$(MAKECMDGOALS))"

schema:
	@duckdb my_database.duckdb -c "describe $(filter-out $@,$(MAKECMDGOALS))"

%:
	@:
