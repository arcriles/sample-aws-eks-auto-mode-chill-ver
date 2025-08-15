apiVersion: batch/v1
kind: Job
metadata:
  name: pgvector-setup
  namespace: ${namespace}
spec:
  ttlSecondsAfterFinished: 100
  template:
    spec:
      containers:
      - name: pgvector-setup
        image: postgres:15
        env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: openwebui-db-credentials
              key: url
        command:
        - /bin/bash
        - -c
        - |
          set -e  # Exit immediately if a command exits with a non-zero status
          
          echo "=== [$(date)] STARTING PGVECTOR SETUP ==="
          echo "Waiting for PostgreSQL to be ready..."
          sleep 10
          
          # Parse the connection string to get components
          DB_HOST=$(echo $DB_URL | sed -n 's/.*@\([^:]*\).*/\1/p')
          DB_PORT=$(echo $DB_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
          DB_NAME=$(echo $DB_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
          DB_USER=$(echo $DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
          DB_PASS=$(echo $DB_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\).*/\1/p')
          
          echo "=== [$(date)] CONNECTING TO POSTGRESQL ==="
          echo "Host: $DB_HOST"
          echo "Port: $DB_PORT"
          echo "Database: $DB_NAME"
          
          # Test connection to default postgres database first
          if ! PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT 1" > /dev/null 2>&1; then
            echo "=== [$(date)] ERROR: FAILED TO CONNECT TO POSTGRESQL ==="
            echo "Please check that the RDS instance is running and accessible from the EKS cluster."
            exit 1
          fi
          
          echo "=== [$(date)] CONNECTION TO POSTGRESQL SUCCESSFUL ==="
          
          echo "=== [$(date)] CREATING DATABASE IF NOT EXISTS ==="
          # Create the database if it doesn't exist
          if PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
            echo "=== [$(date)] DATABASE $DB_NAME ALREADY EXISTS ==="
          else
            echo "=== [$(date)] CREATING DATABASE $DB_NAME ==="
            if PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"; then
              echo "=== [$(date)] DATABASE $DB_NAME CREATED SUCCESSFULLY ==="
            else
              echo "=== [$(date)] ERROR: FAILED TO CREATE DATABASE $DB_NAME ==="
              exit 1
            fi
          fi
          
          echo "=== [$(date)] CONNECTING TO TARGET DATABASE ==="
          # Now test connection to the target database
          if ! PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
            echo "=== [$(date)] ERROR: FAILED TO CONNECT TO TARGET DATABASE $DB_NAME ==="
            exit 1
          fi
          
          echo "=== [$(date)] CONNECTION TO TARGET DATABASE SUCCESSFUL ==="
          echo "Creating pgvector extension..."
          
          # Create the extension
          if PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;"; then
            echo "=== [$(date)] PGVECTOR EXTENSION CREATED SUCCESSFULLY ==="
          else
            echo "=== [$(date)] ERROR: FAILED TO CREATE PGVECTOR EXTENSION ==="
            exit 1
          fi
          
          # Verify the extension
          echo "=== [$(date)] VERIFYING PGVECTOR EXTENSION ==="
          if PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"; then
            echo "=== [$(date)] VERIFICATION SUCCESSFUL ==="
            echo "=== [$(date)] PGVECTOR SETUP COMPLETED SUCCESSFULLY ==="
          else
            echo "=== [$(date)] ERROR: VERIFICATION FAILED ==="
            exit 1
          fi
      restartPolicy: Never
  backoffLimit: 4
