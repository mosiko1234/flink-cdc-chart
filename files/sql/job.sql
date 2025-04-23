# Example files/sql/job.sql content
---
# This is a placeholder for the actual SQL content
# Create CDC source table for MSSQL
CREATE TABLE mssql_catalog.source_database.source_table (
    id INT,
    name STRING,
    description STRING,
    modified_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'sqlserver-cdc',
    'hostname' = '${MSSQL_SERVER}',
    'port' = '${MSSQL_PORT}',
    'username' = '${MSSQL_USERNAME}',
    'password' = '${MSSQL_PASSWORD}',
    'database-name' = '${MSSQL_DATABASE}',
    'table-name' = 'source_table',
    'debezium.snapshot.mode' = 'initial',
    'debezium.snapshot.isolation.mode' = 'snapshot'
);

# Create Kafka sink table
CREATE TABLE kafka_catalog.default.sink_table (
    id INT,
    name STRING,
    description STRING,
    modified_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'sink_topic',
    'properties.bootstrap.servers' = '${KAFKA_BROKERS}',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true',
    'sink.partitioner' = 'round-robin'
);

# Create and execute the CDC job
INSERT INTO kafka_catalog.default.sink_table
SELECT id, name, description, modified_at
FROM mssql_catalog.source_database.source_table;