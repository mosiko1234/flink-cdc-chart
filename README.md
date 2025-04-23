# Apache Flink CDC Helm Chart for OpenShift

This Helm chart deploys Apache Flink with CDC (Change Data Capture) capabilities in an air-gapped OpenShift environment. It's specifically designed for production workloads that require capturing data changes from MSSQL databases and streaming them to Kafka topics.

## Architecture

### Components

1. **JobManager**
   - Central coordinator for Flink applications
   - Manages task distribution and job execution
   - Exposes UI on port 8081
   - Handles checkpoints and savepoints coordination

2. **TaskManager**
   - Executes assigned tasks from JobManager
   - Provides processing resources (slots)
   - Manages the state for processing tasks
   - Configurable number of replicas for scalability

3. **SQL Gateway**
   - REST API interface for submitting SQL queries
   - Available on port 8083
   - Supports declarative job submission
   - Enables managing Flink SQL operations via REST calls

4. **Bootstrap Job**
   - Initializes CDC tasks from SQL definitions
   - Automatically runs during deployment when enabled
   - Can restore from previous savepoints

5. **Storage Integration**
   - MinIO/S3-compatible storage for checkpoints and savepoints
   - Preserves state for fault tolerance and recovery

6. **CDC Connectors**
   - SQL Server CDC connector for capturing database changes
   - Kafka connector for streaming captured changes to topics
   - JSON format handling for serialization/deserialization

### Data Flow

1. The MSSQL CDC connector monitors database log changes
2. Changes are captured by Flink TaskManagers
3. State is maintained in RocksDB with checkpoints in S3/MinIO
4. Processed changes are streamed to Kafka topics
5. All operations are coordinated by the JobManager

## Prerequisites

- OpenShift cluster (on-premise, air-gapped)
- Access to internal container registry
- Pre-created secrets for:
  - MSSQL credentials
  - S3/MinIO credentials
- Storage class available for persistent volume claims
- Kafka cluster accessible from OpenShift

## Installation

### 1. Prepare the required files

Place the required connector JARs in the `files/libs/` directory:
- `flink-sql-connector-sqlserver-cdc-x.y.z.jar`
- `flink-sql-connector-kafka-x.y.z.jar`
- `flink-format-json-x.y.z.jar`

Create your SQL job definition in `files/sql/job.sql`.

### 2. Customize values.yaml

Create a custom values file with your environment-specific configuration:

```yaml
global:
  imageRegistry: "registry.example.com"  # Your internal registry

image:
  repository: registry.example.com/flink
  tag: 1.17.1

# Configure resources according to your workload
jobmanager:
  resources:
    limits:
      cpu: 2
      memory: 4Gi
    requests:
      cpu: 1
      memory: 2Gi

taskmanager:
  replicas: 3  # Scale based on workload requirements
  resources:
    limits:
      cpu: 4
      memory: 8Gi
    requests:
      cpu: 2
      memory: 4Gi
  slots: 2

# Flink configuration settings
flinkConfiguration:
  "state.backend": "rocksdb"
  "state.checkpoints.dir": "s3://flink-checkpoints/"
  "state.savepoints.dir": "s3://flink-savepoints/"
  "s3.endpoint": "http://minio.example.com:9000"
  
# Environment variables
env:
  - name: MSSQL_SERVER
    value: "mssql.example.com"
  - name: MSSQL_PORT
    value: "1433"
  - name: MSSQL_DATABASE
    value: "your_database"
  - name: KAFKA_BROKERS
    value: "kafka-broker:9092"

# Secret references
secrets:
  mssqlCredentials:
    name: "mssql-creds"
  s3Credentials:
    name: "s3-creds"

# Enable bootstrap to run SQL on startup
bootstrap:
  enabled: true
```

### 3. Create required secrets

```bash
# Create MSSQL credentials secret
oc create secret generic mssql-creds \
  --from-literal=username=your_username \
  --from-literal=password=your_password

# Create S3/MinIO credentials secret
oc create secret generic s3-creds \
  --from-literal=accessKey=your_access_key \
  --from-literal=secretKey=your_secret_key
```

### 4. Deploy the chart

```bash
helm install flink-cdc ./flink-cdc-chart -f custom-values.yaml -n your-namespace
```

### 5. Verify the deployment

```bash
# Check all deployments
oc get deployments

# Check pods
oc get pods

# Check services
oc get svc

# Access JobManager UI
oc port-forward svc/flink-cdc-jobmanager 8081:8081
```

Then access the UI at http://localhost:8081

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Flink image repository | `registry.example.com/flink` |
| `image.tag` | Flink image tag | `1.17.1` |
| `jobmanager.replicas` | Number of JobManager replicas | `1` |
| `taskmanager.replicas` | Number of TaskManager replicas | `1` |
| `sqlGateway.enabled` | Enable SQL Gateway | `true` |
| `bootstrap.enabled` | Enable automatic bootstrap job | `true` |
| `restoreFromSavepoint` | Path to savepoint for recovery | `""` |
| `flinkConfiguration` | Flink configuration parameters | See `values.yaml` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Size of persistent volume | `10Gi` |

### Configuring CDC Jobs

The SQL jobs are defined in `files/sql/job.sql`. You can customize this file to define:

1. Source tables (from MSSQL)
2. Target topics (in Kafka)
3. Transformations (if needed)
4. Job execution parameters

Example SQL file:

```sql
-- Create source table from MSSQL CDC
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
    'debezium.snapshot.mode' = 'initial'
);

-- Create Kafka sink table
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
    'format' = 'json'
);

-- Create and execute the CDC job
INSERT INTO kafka_catalog.default.sink_table
SELECT id, name, description, modified_at
FROM mssql_catalog.source_database.source_table;
```

## Operations

### Accessing the Flink UI

```bash
oc port-forward svc/flink-cdc-jobmanager 8081:8081
```

Access the UI at http://localhost:8081

### Accessing the SQL Gateway

```bash
oc port-forward svc/flink-cdc-sqlgateway 8083:8083
```

Example REST API call to submit a SQL query:

```bash
curl -X POST http://localhost:8083/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"sessionName":"my-session"}'

# Get the session handle from response
SESSION_HANDLE="your_session_handle"

curl -X POST "http://localhost:8083/v1/sessions/${SESSION_HANDLE}/statements" \
  -H "Content-Type: application/json" \
  -d '{"statement":"SHOW TABLES;"}'
```

### Creating a Savepoint

```bash
JOBID=$(curl -s http://localhost:8081/jobs | jq -r '.jobs[0].id')

curl -X POST "http://localhost:8081/jobs/${JOBID}/savepoints" \
  -H "Content-Type: application/json" \
  -d '{"target-directory":"s3://flink-savepoints/"}'
```

### Scaling TaskManagers

```bash
helm upgrade flink-cdc ./flink-cdc-chart \
  -f custom-values.yaml \
  --set taskmanager.replicas=5 \
  -n your-namespace
```

### Monitoring with Prometheus

The chart includes Prometheus metric configurations. If you have Prometheus Operator installed:

1. Set `monitoring.serviceMonitor.enabled=true` in values.yaml
2. Make sure your Prometheus instance has the correct label selectors

## Security Considerations

### OpenShift-Specific Security

This chart is configured to comply with OpenShift's restricted-v2 Security Context Constraints (SCC):

- Runs containers as non-root
- Sets `allowPrivilegeEscalation: false`
- Uses read-only root filesystem where possible
- Does not explicitly set `runAsUser`, `runAsGroup`, or `fsGroup` (lets OpenShift assign them)

### Network Isolation

All services use `ClusterIP` to minimize external exposure. Use OpenShift Routes or secure access methods to expose services when needed.

### Credentials Management

Sensitive information (database credentials, S3 access keys) is managed through Kubernetes secrets.

## Troubleshooting

### Common Issues

1. **Pods failing to start with permission issues**
   - Check the SCC assigned to the service account
   - Ensure no volume mounts require root permissions

2. **CDC not capturing changes**
   - Verify SQL Server has CDC enabled for the database and tables
   - Check that the MSSQL user has appropriate permissions

3. **Failed checkpoints**
   - Ensure S3/MinIO is correctly configured and accessible
   - Check storage permissions and credentials

4. **Bootstrap job failing**
   - Check the logs of the bootstrap pod
   - Verify SQL syntax in job.sql

### Viewing Logs

```bash
# JobManager logs
oc logs $(oc get pods -l app.kubernetes.io/component=jobmanager -o name)

# TaskManager logs
oc logs $(oc get pods -l app.kubernetes.io/component=taskmanager -o name)

# SQL Gateway logs
oc logs $(oc get pods -l app.kubernetes.io/component=sqlgateway -o name)

# Bootstrap job logs
oc logs $(oc get pods -l job-name=flink-cdc-bootstrap -o name)
```

## Advanced Configuration

### High Availability Setup

For high availability, you can configure:

1. Multiple JobManager replicas
2. Increased checkpoint frequency
3. ZooKeeper for HA coordination

Modify `values.yaml`:

```yaml
jobmanager:
  replicas: 2  # Enable HA mode

flinkConfiguration:
  "high-availability": "org.apache.flink.kubernetes.highavailability.KubernetesHaServicesFactory"
  "high-availability.storageDir": "s3://flink-ha"
  "execution.checkpointing.interval": "30000"  # 30 seconds
```

### Custom Connectors

To add custom connectors:

1. Place additional JAR files in the `files/libs/` directory
2. They will be automatically mounted in the `/opt/flink/lib/` directory

### Memory Tuning

For optimal performance, adjust memory settings:

```yaml
flinkConfiguration:
  "jobmanager.memory.process.size": "2048m"
  "taskmanager.memory.process.size": "4096m"
  "taskmanager.memory.managed.fraction": "0.4"
  "taskmanager.memory.network.fraction": "0.1"
```

## License

Apache License 2.0
