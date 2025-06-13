apiVersion: batch/v1
kind: Job
metadata:
  name: pgvector-setup
  namespace: vllm-inference
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
          
          # Test connection first
          if ! PGPASSWORD="$DB_PASS" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
            echo "=== [$(date)] ERROR: FAILED TO CONNECT TO POSTGRESQL ==="
            echo "Please check that the RDS instance is running and accessible from the EKS cluster."
            exit 1
          fi
          
          echo "=== [$(date)] CONNECTION SUCCESSFUL ==="
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
