#!/bin/bash

# הגדרות התחברות
MSSQL_HOST="mssql.example.com"
MSSQL_PORT="1433"
MSSQL_USER="your_user"
MSSQL_PASSWORD="your_password"
MSSQL_DATABASE="your_database"
KAFKA_BOOTSTRAP_SERVERS="kafka-broker-1.example.com:9092,kafka-broker-2.example.com:9092"
CDC_GATEWAY_URL="http://flink-cdc-cdcgateway:8084/api/v1/pipelines/import"

# קובץ פלט זמני
OUTPUT_JSON="pipelines.json"

# שליפת שמות טבלאות מ־MSSQL
TABLES=$(sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -d $MSSQL_DATABASE -h -1 -Q "SELECT TABLE_SCHEMA + '.' + TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'")

if [ -z "$TABLES" ]; then
  echo "לא נמצאו טבלאות במסד הנתונים."
  exit 1
fi

# התחלה של JSON
echo '{"pipelines": [' > $OUTPUT_JSON

# יצירת בלוקים לכל טבלה
FIRST=true
while read -r table; do
  # לדלג על שורות ריקות
  if [ -z "$table" ]; then
    continue
  fi
  
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> $OUTPUT_JSON
  fi

  schema_name=$(echo $table | cut -d'.' -f1)
  table_name=$(echo $table | cut -d'.' -f2)
  topic_name="cdc.${table_name}"

  cat >> $OUTPUT_JSON <<EOF
{
  "name": "${table_name}-cdc",
  "source": {
    "type": "sqlserver-cdc",
    "config": {
      "hostname": "${MSSQL_HOST}",
      "port": ${MSSQL_PORT},
      "username": "${MSSQL_USER}",
      "password": "${MSSQL_PASSWORD}",
      "database-name": "${MSSQL_DATABASE}",
      "table-name": "${table}",
      "scan.startup.mode": "initial"
    }
  },
  "sink": {
    "type": "kafka",
    "config": {
      "bootstrapServers": "${KAFKA_BOOTSTRAP_SERVERS}",
      "topic": "${topic_name}",
      "format": "json"
    }
  }
}
EOF

done <<< "$TABLES"

# סגירת JSON
echo ']}' >> $OUTPUT_JSON

# הדפסת התוצאה
echo "✅ קובץ JSON נוצר: $OUTPUT_JSON"
cat $OUTPUT_JSON | jq .

# שליחת ה־JSON ל־CDC Gateway
echo "🚀 שולח ל־CDC Gateway..."
curl -X POST "$CDC_GATEWAY_URL" \
  -H "Content-Type: application/json" \
  -d @"$OUTPUT_JSON"

echo "🎯 טעינת Pipelines הסתיימה."
