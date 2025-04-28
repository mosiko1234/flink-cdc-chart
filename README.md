# Flink CDC Connector Helm Chart - README

## 📄 Overview

This Helm chart deploys an **Apache Flink** cluster with full **CDC (Change Data Capture)** capabilities, integrated with **MSSQL**, **Kafka**, and **MinIO/S3** storage. It is optimized for **air-gapped OpenShift environments**.

It includes:

- Flink JobManager & TaskManagers.
- SQL Gateway for dynamic SQL job submission.
- CDC Gateway for easy pipeline management.
- Persistent storage for state handling (with MinIO/S3).
- Secure access to MSSQL/Kafka/S3 via Kubernetes Secrets.

---

## 🏢 Architecture Diagram

```text
[MSSQL CDC]  -->  [Flink CDC Connector]  -->  [Kafka Topics]  -->  [Consumers]
                                      \
                                       -> [State Savepoints/Checkpoints in MinIO]
```

Components deployed:

- **Flink JobManager** - Central control and UI.
- **Flink TaskManagers** - Execute CDC processing tasks.
- **SQL Gateway** (optional) - Accepts dynamic SQL jobs.
- **CDC Gateway** - Simplified CDC pipelines manager.
- **Bootstrap Job** - Auto-load pipelines on startup.
- **Persistent Volumes** - For Flink state and logs.

---

## 🌐 Main Components Explained

### 📊 Flink

Apache Flink is responsible for processing CDC events in real-time.

- Configured to use **RocksDB** state backend.
- State is stored externally on **MinIO/S3** for resilience.

### 👤 SQL Gateway vs CDC Gateway

| Feature  | SQL Gateway                          | CDC Gateway                             |
| -------- | ------------------------------------ | --------------------------------------- |
| Purpose  | Accept general SQL jobs via REST/CLI | Simplify CDC pipelines management       |
| Use Case | Dynamic jobs, ad-hoc queries         | Standard CDC ingestion (MSSQL to Kafka) |
| Input    | SQL DDL/DML                          | JSON pipelines                          |
| Best For | Developers                           | Integrators/Operators                   |

**In this project**, you should primarily use **CDC Gateway**.

### 🏢 MSSQL

Your MSSQL database has CDC enabled on selected tables. Flink CDC Source connectors listen to transaction logs and stream changes.

**Important MSSQL details:**

- Connection secured via Kubernetes Secret.
- SSL Trust: Enabled with `trustServerCertificate: true`.
- Table selection is configured per pipeline.

### 🌐 Kafka

Kafka is the messaging backbone.

- Every table change captured from MSSQL is published to a Kafka topic.
- Topics are named like `cdc.<table-name>`, e.g., `cdc.orders`.
- Secure Kafka connection via username/password secrets.

### ⛳️ MinIO (S3 Compatible Storage)

Flink uses MinIO for:

- Checkpoints (fault-tolerance snapshots).
- Savepoints (manual state save operations).

MinIO is accessed internally over HTTP, with path-style access enabled.

### 💼 Secrets Management

All sensitive credentials (MSSQL, Kafka, MinIO) are stored securely in Kubernetes Secrets and injected at runtime.

---

## 🔧 Deployment Instructions

### 1. Customize `values.yaml`

- Set `global.imageRegistry`, `namespace`, and relevant resource limits.
- Configure your MSSQL/Kafka/MinIO credentials under `existingSecrets`.
- Define your CDC pipelines under `pipelines` section.

### 2. Install the Chart

```bash
helm install flink-cdc-connector ./flink-cdc-connector -n flink-cdc --create-namespace
```

### 3. Monitor Deployments

- JobManager Web UI: `http://<route-to-jobmanager>`
- CDC Gateway API: `http://flink-cdc-cdcgateway:8084`

You can access Flink's native UI to monitor jobs, tasks, and health.

---

## 🛡️ Security Considerations

- Images are pulled from your internal air-gapped registry.
- No external Internet access is required.
- All ServiceAccounts are restricted (`restricted-v2` OpenShift SCC).
- Secrets are injected safely without hardcoding passwords.
- TLS is recommended for Kafka if supported internally.

---

## 🚀 Usage Examples

### 📅 View Existing Pipelines

```bash
curl http://flink-cdc-cdcgateway:8084/api/v1/pipelines
```

### ➕ Add New CDC Pipeline Dynamically

```bash
curl -X POST http://flink-cdc-cdcgateway:8084/api/v1/pipelines/import \
     -H "Content-Type: application/json" \
     -d @pipeline-definition.json
```

`pipeline-definition.json` Example:

```json
{
  "pipelines": [
    {
      "name": "orders-cdc",
      "source": {
        "type": "sqlserver-cdc",
        "config": {
          "hostname": "mssql.example.com",
          "port": 1433,
          "username": "myuser",
          "password": "mypassword",
          "database-name": "your_database",
          "table-name": "sales.orders",
          "scan.startup.mode": "initial"
        }
      },
      "sink": {
        "type": "kafka",
        "config": {
          "bootstrapServers": "kafka-broker-1.example.com:9092",
          "topic": "cdc.orders",
          "format": "json"
        }
      }
    }
  ]
}
```

---

## 🌟 Best Practices

- Always define clear resource limits per component.
- Monitor TaskManagers' CPU and memory usage closely.
- Backup state regularly from MinIO.
- Regularly validate CDC health by comparing MSSQL vs Kafka topics.
- Use Kubernetes `PodDisruptionBudget` if HA is enabled.
- Leverage Prometheus + Grafana for monitoring Flink cluster if possible.

---

## 🎉 You're Ready!

With this chart and environment:

- MSSQL changes flow automatically to Kafka.
- State is fully durable in MinIO.
- Pipelines can be added, modified, or monitored dynamically.

**Welcome to Production-Grade CDC on OpenShift! ✨**

---

# 📌 References

- [Apache Flink Documentation](https://nightlies.apache.org/flink/flink-docs-release-1.17/)
- [Debezium CDC Connectors](https://debezium.io/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [MinIO S3 Gateway](https://min.io/)
- [Helm Documentation](https://helm.sh/docs/)

# Flink CDC Connector Helm Chart - README

## 📄 Overview

This Helm chart deploys an **Apache Flink** cluster with full **CDC (Change Data Capture)** capabilities, integrated with **MSSQL**, **Kafka**, and **MinIO/S3** storage. It is optimized for **air-gapped OpenShift environments**.

It includes:
- Flink JobManager & TaskManagers.
- SQL Gateway for dynamic SQL job submission.
- CDC Gateway for easy pipeline management.
- Persistent storage for state handling (with MinIO/S3).
- Secure access to MSSQL/Kafka/S3 via Kubernetes Secrets.

---

# 🚀 Quickstart Guide

## 1. Prerequisites
- Kubernetes or OpenShift cluster
- Internal Docker Registry
- Helm 3.x installed
- MSSQL Server with CDC enabled on required tables
- Kafka Cluster
- MinIO/S3 Compatible Storage

## 2. Clone and Customize
Clone the chart and edit `values.yaml`:
- Set your image registry, namespace, resource limits.
- Define connections to MSSQL, Kafka, and MinIO via Secrets.
- List your CDC pipelines (source tables and sink topics).

```bash
git clone mosiko1234/flink-cdc-chart.git
cd flink-cdc-connector
vim values.yaml
```

## 3. Deploy to OpenShift
```bash
helm install flink-cdc-connector ./flink-cdc-connector -n flink-cdc --create-namespace
```

## 4. Verify
Access Flink UI and CDC Gateway:
- Flink UI: `http://<route-to-jobmanager>`
- CDC Gateway API: `http://flink-cdc-cdcgateway:8084`

Check running pipelines:
```bash
curl http://flink-cdc-cdcgateway:8084/api/v1/pipelines
```

## 5. Load New Pipelines (optional)
Create `pipeline-definition.json` and import:
```bash
curl -X POST http://flink-cdc-cdcgateway:8084/api/v1/pipelines/import \
     -H "Content-Type: application/json" \
     -d @pipeline-definition.json
```

## 6. Monitor and Manage
- Use Flink WebUI to monitor Jobs and TaskManagers.
- Use CDC Gateway API to manage CDC pipelines.
- Savepoints and checkpoints are automatically stored on MinIO.

## 7. Backup and Restore
- Backup Flink state by copying MinIO checkpoint/savepoint buckets.
- In case of failure, recover using savepoints.

---

# 📄 Detailed Documentation

See below for architecture, component explanations, security notes, and best practices.

(Continue reading for full component explanations and advanced topics)

---

## 🏢 Architecture Diagram

```text
[MSSQL CDC]  -->  [Flink CDC Connector]  -->  [Kafka Topics]  -->  [Consumers]
                                      \
                                       -> [State Savepoints/Checkpoints in MinIO]
``` 

(remaining content unchanged)

