# Apache Flink CDC Gateway Helm Chart for OpenShift

This Helm chart deploys Apache Flink with CDC Gateway capabilities in an air-gapped OpenShift environment. It's specifically designed for production workloads that require capturing data changes from various database systems and streaming them to Kafka topics, creating a centralized CDC platform that multiple projects can utilize.

## Architecture

![Flink CDC Architecture](https://i.imgur.com/placeholder.png)

### Core Components

1. **JobManager**
   - Central coordinator for Flink applications
   - Manages task distribution and job execution
   - Exposes UI on port 8081
   - Handles checkpoints and savepoints coordination
   - Provides job scheduling and resource management

2. **TaskManager**
   - Executes assigned tasks from JobManager
   - Provides processing resources (slots)
   - Manages the state for processing tasks
   - Configurable number of replicas for scalability
   - Handles data processing and transformation

3. **SQL Gateway**
   - REST API interface for submitting SQL queries
   - Available on port 8083
   - Supports declarative job submission
   - Enables managing Flink SQL operations via REST calls
   - Useful for SQL-based CDC pipeline definition

4. **CDC Gateway**
   - Dedicated REST API for managing CDC connectors and tasks
   - Available on port 8084
   - Simplifies CDC pipeline creation
   - Manages data transfer from source to destination without manual SQL
   - Provides centralized management for all CDC pipelines

5. **Bootstrap Job**
   - Initializes CDC tasks from configuration
   - Runs automatically during deployment when enabled
   - Can restore from previous savepoints
   - Creates connectors and pipelines through API calls

6. **Storage Integration**
   - MinIO/S3-compatible storage for checkpoints and savepoints
   - Preserves state for fault tolerance and recovery
   - Enables job recovery and migration

7. **CDC Connectors**
   - Database-specific CDC connectors (MSSQL, MySQL, PostgreSQL, etc.)
   - Kafka connector for streaming captured changes to topics
   - JSON format handling for serialization/deserialization
   - Custom transformation support

### Data Flow

1. The source CDC connector monitors database log changes
2. Changes are captured by Flink TaskManagers
3. State is maintained in RocksDB with checkpoints in S3/MinIO
4. Processed changes are streamed to Kafka topics or other destinations
5. All operations are coordinated by the JobManager
6. CDC Gateway provides API access for monitoring and management

### Multi-Project Architecture

This Helm chart is designed to serve as a centralized CDC platform that multiple projects can use:

- Each project can define its own sources, sinks, and pipelines
- Different projects can connect to different database types
- Projects can stream to different Kafka clusters
- Isolation between projects' resources and configurations
- Centralized management through CDC Gateway API

## Prerequisites

- OpenShift cluster (on-premise, air-gapped)
- Access to internal container registry
- Pre-created secrets for:
  - Database credentials (MSSQL, MySQL, PostgreSQL, etc.)
  - S3/MinIO credentials
- Storage class available for persistent volume claims
- Kafka clusters accessible from OpenShift

## Required Container Images

The following container images need to be downloaded and pushed to your internal registry:

| Image Name | Tag | Description | Source |
|------------|-----|-------------|--------|
| `flink` | `1.17.1` | Base Apache Flink image | [Docker Hub](https://hub.docker.com/_/flink) |
| `curlimages/curl` | `latest` | Used for bootstrap job REST calls | [Docker Hub](https://hub.docker.com/r/curlimages/curl) |
| `apache/flink-cdc` | `0.7.0` | CDC Gateway image | [Docker Hub](https://hub.docker.com/r/apache/flink-cdc) |

### Instructions for Image Preparation

```bash
# Download images on a machine with internet access
docker pull flink:1.17.1
docker pull curlimages/curl:latest
docker pull apache/flink-cdc:0.7.0

# Save images as archives
docker save flink:1.17.1 | gzip > flink-1.17.1.tar.gz
docker save curlimages/curl:latest | gzip > curl-latest.tar.gz
docker save apache/flink-cdc:0.7.0 | gzip > flink-cdc-0.7.0.tar.gz

# Transfer archives to air-gapped environment

# Load images
gunzip -c flink-1.17.1.tar.gz | docker load
gunzip -c curl-latest.tar.gz | docker load
gunzip -c flink-cdc-0.7.0.tar.gz | docker load

# Tag for internal registry
docker tag flink:1.17.1 registry.example.com/flink:1.17.1
docker tag curlimages/curl:latest registry.example.com/curl:latest
docker tag apache/flink-cdc:0.7.0 registry.example.com/flink-cdc:0.7.0

# Push to internal registry
docker push registry.example.com/flink:1.17.1
docker push registry.example.com/curl:latest
docker push registry.example.com/flink-cdc:0.7.0
```

## Required JAR Files

The following JAR files need to be placed in the `files/libs/` directory:

- `flink-sql-connector-sqlserver-cdc-3.0.1.jar` - SQL Server CDC connector
- `flink-sql-connector-kafka-1.17.1.jar` - Kafka connector for Flink
- `flink-format-json-1.17.1.jar` - JSON format for Flink
- `flink-cdc-gateway-0.7.0.jar` - CDC Gateway library

Additional connectors may be required depending on your database types:
- `flink-sql-connector-mysql-cdc-3.0.1.jar` - MySQL CDC connector
- `flink-sql-connector-postgres-cdc-3.0.1.jar` - PostgreSQL CDC connector
- `flink-sql-connector-oracle-cdc-3.0.1.jar` - Oracle CDC connector
- `flink-sql-connector-mongodb-cdc-3.0.1.jar` - MongoDB CDC connector

## Installation

### 1. Prepare the Required Files

Ensure all connector JARs are placed in the `files/libs/` directory. Create your SQL job definition in `files/sql/job.sql` if using SQL Gateway.

### 2. Customize values.yaml

Create a custom values file with your environment-specific configuration:

```yaml
global:
  imageRegistry: "registry.example.com"  # Your internal registry

image:
  repository: registry.example.com/flink
  tag: 1.17.1

# CDC Gateway Configuration
cdcGateway:
  enabled: true
  image:
    repository: registry.example.com/flink-cdc
    tag: "0.7.0"
  port: 8084
  configuration:
    adminPort: 8085
    maxConnections: 100
    maxConcurrentJobs: 10

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

# Enable bootstrap to set up connectors and pipeline using CDC Gateway
bootstrap:
  enabled: true
  useCdcGateway: true
  cdcConnectors:
    - name: "project1-mssql-source"
      type: "sqlserver-cdc"
      configuration:
        hostname: "${MSSQL_SERVER}"
        port: "${MSSQL_PORT}"
        username: "${MSSQL_USERNAME}"
        password: "${MSSQL_PASSWORD}"
        database-name: "${MSSQL_DATABASE}"
        table-name: "source_table"
        database-history: "memory"
        include-schema-changes: "true"
    - name: "project1-kafka-sink"
      type: "kafka"
      configuration:
        bootstrapServers: "${KAFKA_BROKERS}"
        topic: "sink_topic"
        format: "json"
```

### 3. Create Required Secrets

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

### 4. Deploy the Chart

```bash
helm install flink-cdc ./flink-cdc-chart -f custom-values.yaml -n your-namespace
```

### 5. Verify the Deployment

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
| `cdcGateway.enabled` | Enable CDC Gateway | `true` |
| `cdcGateway.port` | CDC Gateway port | `8084` |
| `jobmanager.replicas` | Number of JobManager replicas | `1` |
| `taskmanager.replicas` | Number of TaskManager replicas | `1` |
| `sqlGateway.enabled` | Enable SQL Gateway | `true` |
| `bootstrap.enabled` | Enable automatic bootstrap job | `true` |
| `bootstrap.useCdcGateway` | Use CDC Gateway instead of SQL Gateway for bootstrapping | `true` |
| `restoreFromSavepoint` | Path to savepoint for recovery | `""` |
| `flinkConfiguration` | Flink configuration parameters | See `values.yaml` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Size of persistent volume | `10Gi` |

### Using CDC Gateway

CDC Gateway provides a REST API to manage CDC connectors and tasks. It allows you to create and manage sources, destinations, and data transfer tasks without manually writing SQL.

The API includes:

1. **Connector Management** - Create, update, and delete source and sink connectors
2. **Pipeline Management** - Connect sources to destinations with transformation options
3. **Task Management** - Start, stop, and control CDC tasks

Example of creating a source connector:

```bash
curl -X POST http://localhost:8084/api/v1/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mssql-source",
    "type": "sqlserver-cdc",
    "config": {
      "hostname": "mssql.example.com",
      "port": "1433",
      "username": "your_username",
      "password": "your_password",
      "database-name": "your_database",
      "table-name": "your_table",
      "database-history": "memory"
    }
  }'
```

Example of creating a sink connector:

```bash
curl -X POST http://localhost:8084/api/v1/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kafka-sink",
    "type": "kafka",
    "config": {
      "bootstrapServers": "kafka:9092",
      "topic": "data-topic",
      "format": "json"
    }
  }'
```

Example of creating a pipeline:

```bash
curl -X POST http://localhost:8084/api/v1/pipelines \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mssql-to-kafka",
    "source": "mssql-source",
    "sink": "kafka-sink",
    "parallelism": 2,
    "transformations": []
  }'
```

## Multi-Project Setup

To use this chart as a centralized CDC platform for multiple projects:

1. **Define project namespaces in connector names**:
   - `project1-mssql-source`
   - `project2-postgres-source`

2. **Configure separate Kafka destinations**:
   - `project1-kafka-sink` pointing to Project 1's Kafka
   - `project2-kafka-sink` pointing to Project 2's Kafka

3. **Scale resources appropriately**:
   - Increase TaskManager replicas
   - Adjust memory and CPU based on total workload

4. **Add access control**:
   - Create separate service accounts for different projects
   - Configure network policies for isolation

## GitLab Integration for CDC Pipeline Management

You can manage your CDC pipelines using GitOps principles with GitLab. This allows you to version control all CDC configurations and use CI/CD for deployment.

### Repository Structure

```
cdc-pipelines/
├── projects/
│   ├── project1/
│   │   ├── sources/
│   │   │   └── mssql-orders.json
│   │   ├── sinks/
│   │   │   └── kafka-orders.json
│   │   └── pipelines/
│   │       └── orders-sync.json
│   ├── project2/
│   │   └── ...
│   └── ...
├── templates/
│   ├── mssql-source.json.template
│   ├── postgres-source.json.template
│   └── kafka-sink.json.template
├── scripts/
│   ├── validate-cdc-configs.sh
│   ├── deploy-cdc-pipelines.sh
│   └── remove-project.sh
└── .gitlab-ci.yml
```

### Example GitLab CI/CD Pipeline

```yaml
stages:
  - validate
  - deploy
  - test

variables:
  CDC_GATEWAY_URL: "http://cdc-gateway:8084"
  CDC_AUTH_TOKEN: ${CDC_API_TOKEN}  # Set in GitLab CI/CD variables

validate-config:
  stage: validate
  image: registry.example.com/curl:latest
  script:
    - chmod +x ./scripts/validate-cdc-configs.sh
    - ./scripts/validate-cdc-configs.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

deploy-cdc-pipelines:
  stage: deploy
  image: registry.example.com/curl:latest
  script:
    - chmod +x ./scripts/deploy-cdc-pipelines.sh
    - ./scripts/deploy-cdc-pipelines.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    
test-cdc-connectivity:
  stage: test
  image: registry.example.com/curl:latest
  script:
    - chmod +x ./scripts/test-connectivity.sh
    - ./scripts/test-connectivity.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

### Deployment Script

```bash
#!/bin/bash
# deploy-cdc-pipelines.sh

# Set up curl with authentication header
CURL="curl -s -H 'Authorization: Bearer ${CDC_AUTH_TOKEN}'"

# Get list of changed configuration files
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r $CI_COMMIT_SHA | grep '.json$')

for FILE in $CHANGED_FILES; do
  if [[ $FILE == projects/*/sources/* ]]; then
    # Handle new/changed sources
    CONNECTOR_NAME=$(basename $FILE .json)
    PROJECT_NAME=$(echo $FILE | cut -d'/' -f2)
    
    echo "Deploying source connector: $CONNECTOR_NAME for project: $PROJECT_NAME"
    
    # Check if connector already exists
    CONNECTOR_EXISTS=$(eval "$CURL ${CDC_GATEWAY_URL}/api/v1/connectors/$CONNECTOR_NAME" | jq -r '.name')
    
    if [[ "$CONNECTOR_EXISTS" == "$CONNECTOR_NAME" ]]; then
      # Update existing connector
      eval "$CURL -X PUT ${CDC_GATEWAY_URL}/api/v1/connectors/$CONNECTOR_NAME -d @$FILE"
    else
      # Create new connector
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/connectors -d @$FILE"
    fi
  
  elif [[ $FILE == projects/*/sinks/* ]]; then
    # Handle new/changed sinks
    CONNECTOR_NAME=$(basename $FILE .json)
    PROJECT_NAME=$(echo $FILE | cut -d'/' -f2)
    
    echo "Deploying sink connector: $CONNECTOR_NAME for project: $PROJECT_NAME"
    
    # Check if connector already exists
    CONNECTOR_EXISTS=$(eval "$CURL ${CDC_GATEWAY_URL}/api/v1/connectors/$CONNECTOR_NAME" | jq -r '.name')
    
    if [[ "$CONNECTOR_EXISTS" == "$CONNECTOR_NAME" ]]; then
      # Update existing connector
      eval "$CURL -X PUT ${CDC_GATEWAY_URL}/api/v1/connectors/$CONNECTOR_NAME -d @$FILE"
    else
      # Create new connector
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/connectors -d @$FILE"
    fi
  
  elif [[ $FILE == projects/*/pipelines/* ]]; then
    # Handle new/changed pipelines
    PIPELINE_NAME=$(basename $FILE .json)
    PROJECT_NAME=$(echo $FILE | cut -d'/' -f2)
    
    echo "Deploying pipeline: $PIPELINE_NAME for project: $PROJECT_NAME"
    
    # Check if pipeline already exists
    PIPELINE_EXISTS=$(eval "$CURL ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME" | jq -r '.name')
    
    if [[ "$PIPELINE_EXISTS" == "$PIPELINE_NAME" ]]; then
      # Stop existing pipeline
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME/stop"
      
      # Update pipeline
      eval "$CURL -X PUT ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME -d @$FILE"
      
      # Start updated pipeline
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME/start"
    else
      # Create new pipeline
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/pipelines -d @$FILE"
      
      # Start new pipeline
      eval "$CURL -X POST ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME/start"
    fi
  fi
done
```

### Adding/Removing Projects

#### Adding a New Project

1. Create a directory in the repository:
   ```bash
   mkdir -p projects/new-project/{sources,sinks,pipelines}
   ```

2. Create configuration files for sources, sinks, and pipelines:
   ```bash
   # Example source configuration
   cat > projects/new-project/sources/postgres-source.json << EOF
   {
     "name": "new-project-postgres-source",
     "type": "postgres-cdc",
     "config": {
       "hostname": "postgres.new-project.svc",
       "port": "5432",
       "username": "${NEW_PROJECT_PG_USER}",
       "password": "${NEW_PROJECT_PG_PASSWORD}",
       "database-name": "app_db",
       "table-name": "customers",
       "schema-name": "public"
     }
   }
   EOF
   
   # Example sink configuration
   cat > projects/new-project/sinks/kafka-sink.json << EOF
   {
     "name": "new-project-kafka-sink",
     "type": "kafka",
     "config": {
       "bootstrapServers": "kafka.new-project.svc:9092",
       "topic": "customers-data",
       "format": "json"
     }
   }
   EOF
   
   # Example pipeline configuration
   cat > projects/new-project/pipelines/customers-sync.json << EOF
   {
     "name": "new-project-customers-sync",
     "version": "1.0.0",
     "source": "new-project-postgres-source",
     "sink": "new-project-kafka-sink",
     "parallelism": 2,
     "transformations": []
   }
   EOF
   ```

3. Commit, push, and create a merge request
4. After approval, the GitLab pipeline will deploy the new project's CDC pipelines

#### Removing a Project

1. Create a removal script:
   ```bash
   #!/bin/bash
   # remove-project.sh
   PROJECT_NAME=$1
   
   if [ -z "$PROJECT_NAME" ]; then
     echo "Usage: $0 <project-name>"
     exit 1
   fi
   
   # Stop and remove all pipelines for the project
   PIPELINES=$(curl -s -H "Authorization: Bearer ${CDC_AUTH_TOKEN}" "${CDC_GATEWAY_URL}/api/v1/pipelines" | \
     jq -r ".[] | select(.name | startswith(\"${PROJECT_NAME}-\")) | .name")
   
   for PIPELINE in $PIPELINES; do
     echo "Stopping pipeline: $PIPELINE"
     curl -s -H "Authorization: Bearer ${CDC_AUTH_TOKEN}" -X POST "${CDC_GATEWAY_URL}/api/v1/pipelines/${PIPELINE}/stop"
     
     echo "Removing pipeline: $PIPELINE"
     curl -s -H "Authorization: Bearer ${CDC_AUTH_TOKEN}" -X DELETE "${CDC_GATEWAY_URL}/api/v1/pipelines/${PIPELINE}"
   done
   
   # Remove all connectors for the project
   CONNECTORS=$(curl -s -H "Authorization: Bearer ${CDC_AUTH_TOKEN}" "${CDC_GATEWAY_URL}/api/v1/connectors" | \
     jq -r ".[] | select(.name | startswith(\"${PROJECT_NAME}-\")) | .name")
   
   for CONNECTOR in $CONNECTORS; do
     echo "Removing connector: $CONNECTOR"
     curl -s -H "Authorization: Bearer ${CDC_AUTH_TOKEN}" -X DELETE "${CDC_GATEWAY_URL}/api/v1/connectors/${CONNECTOR}"
   done
   
   # Remove project directory from repository
   if [ -d "projects/${PROJECT_NAME}" ]; then
     git rm -rf "projects/${PROJECT_NAME}"
     git commit -m "Remove ${PROJECT_NAME} CDC pipelines"
     git push origin main
   fi
   ```

2. Execute the script to remove a project:
   ```bash
   ./scripts/remove-project.sh project-name
   ```

### Version Control for Pipelines

To implement versioning for your CDC pipelines:

1. Add a version field to your pipeline configurations:
   ```json
   {
     "name": "project1-orders-sync",
     "version": "1.2.0",
     "source": "project1-mssql-orders",
     "sink": "project1-kafka-orders",
     "parallelism": 2
   }
   ```

2. Modify the deployment script to check versions:
   ```bash
   # Get current version from CDC Gateway
   CURRENT_VERSION=$(eval "$CURL ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME" | jq -r '.version')
   
   # Get new version from file
   NEW_VERSION=$(jq -r '.version' $FILE)
   
   # Compare versions (using semver comparison)
   if [[ $(echo "$CURRENT_VERSION $NEW_VERSION" | tr ' ' '\n' | sort -V | tail -n 1) == "$NEW_VERSION" ]]; then
     # New version is higher, proceed with update
     eval "$CURL -X PUT ${CDC_GATEWAY_URL}/api/v1/pipelines/$PIPELINE_NAME -d @$FILE"
   else
     echo "Error: New version ($NEW_VERSION) is not higher than current version ($CURRENT_VERSION)"
     exit 1
   fi
   ```

## Operations

### Accessing the JobManager UI

```bash
oc port-forward svc/flink-cdc-jobmanager 8081:8081
```

Access the UI at http://localhost:8081

### Accessing the CDC Gateway

```bash
oc port-forward svc/flink-cdc-cdcgateway 8084:8084
```

Then you can use curl or any API client to interact with the CDC Gateway:

```bash
curl http://localhost:8084/api/v1/connectors
curl http://localhost:8084/api/v1/pipelines
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
   - Verify that CDC is enabled for the database and tables
   - Check that the database user has appropriate permissions

3. **Failed checkpoints**
   - Ensure S3/MinIO is correctly configured and accessible
   - Check storage permissions and credentials

4. **Bootstrap job failing**
   - Check the logs of the bootstrap pod
   - Verify JSON or SQL syntax

### Viewing Logs

```bash
# JobManager logs
oc logs $(oc get pods -l app.kubernetes.io/component=jobmanager -o name)

# TaskManager logs
oc logs $(oc get pods -l app.kubernetes.io/component=taskmanager -o name)

# CDC Gateway logs
oc logs $(oc get pods -l app.kubernetes.io/component=cdcgateway -o name)

# Bootstrap job logs
oc logs $(oc get pods -l job-name=flink-cdc-bootstrap -o name)
```

## Advanced Configuration

### High Availability Setup

For high availability, configure:

1. Multiple JobManager replicas
2. Increased checkpoint frequency
3. Kubernetes HA services

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
