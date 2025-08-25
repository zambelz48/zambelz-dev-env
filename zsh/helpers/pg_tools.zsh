# --- PostgreSQL Backup Function (Corrected and Robust) ---
# This function takes a destination DIRECTORY and creates a timestamped backup file inside it.
#
# Usage: pg_backup [database_name] [destination_directory] [username] [host] [port] [password]
function pg_backup() {
    local DB_NAME="${1}"
    local DEST_DIR="${2}"
    local DB_USER="${3:-admin}"
    local DB_HOST="${4:-192.168.0.4}"
    local DB_PORT="${5:-5432}"
    local DB_PASSWORD="${6}"

    # --- Mitigation: Argument Validation ---
    if [[ -z "$DB_NAME" || -z "$DEST_DIR" || -z "$DB_PASSWORD" ]]; then
        echo "Error: Missing required arguments." >&2
        echo "Usage: pg_backup [database_name] [destination_directory] [username] [host] [port] [password]" >&2
        return 1
    fi

    # --- Create the destination directory if it doesn't exist ---
    # The 'mkdir' command will fail if a FILE with the same name exists.
    mkdir -p "${DEST_DIR}" || {
        echo "Error: Could not create destination directory '${DEST_DIR}'." >&2
        echo "Please ensure the path is valid and no file exists with that name." >&2
        return 1
    }

    # --- Construct the final backup path ---
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_FILENAME="${DB_NAME}_${TIMESTAMP}.sql"
    local FULL_BACKUP_PATH="${DEST_DIR}/${BACKUP_FILENAME}"

    # --- Mitigation: Check if a directory exists at the final file path ---
    if [ -d "${FULL_BACKUP_PATH}" ]; then
        echo "Error: A directory already exists at the intended backup file path." >&2
        echo "Path: ${FULL_BACKUP_PATH}" >&2
        return 1
    fi

    echo "Starting PostgreSQL backup for database: ${DB_NAME}..."
    PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -F p -b -v -f "${FULL_BACKUP_PATH}" "${DB_NAME}"

    if [ $? -eq 0 ]; then
        echo "Backup successful! File saved to: ${FULL_BACKUP_PATH}"
        echo "Compressing backup file..."
        gzip "${FULL_BACKUP_PATH}"
        if [ $? -eq 0 ]; then
            echo "Compression successful! File saved as: ${FULL_BACKUP_PATH}.gz"
        else
            echo "Compression failed!" >&2
        fi
    else
        echo "Backup failed!" >&2
        return 1
    fi
}

# --- PostgreSQL Restore Function (Simplified) ---
# Restores a database from a backup file. It requires only one password, assuming
# the database owner has the privilege to create databases (CREATEDB).
#
# Usage: pg_restore [db_to_restore] [backup_file] [db_owner] [host] [port] [db_owner_password]
function pg_restore() {
    local DB_NAME="${1}"
    local BACKUP_FILE="${2}"
    local DB_OWNER="${3:-admin}"
    local DB_HOST="${4:-192.168.0.4}"
    local DB_PORT="${5:-5432}"
    local DB_PASSWORD="${6}" # Password for the DB_OWNER

    # --- Argument Validation ---
    if [[ -z "$DB_NAME" || -z "$BACKUP_FILE" || -z "$DB_PASSWORD" ]]; then
        echo "Error: Missing required arguments." >&2
        echo "Usage: pg_restore [db_to_restore] [backup_file] [db_owner] [host] [port] [db_owner_password]" >&2
        echo "Example: pg_restore my_db /path/to/backup.sql.gz my_user 127.0.0.1 5432 'my_user_pass'" >&2
        return 1
    fi

    if [ ! -f "${BACKUP_FILE}" ]; then
        echo "Error: The provided backup path is not a valid file: '${BACKUP_FILE}'" >&2
        return 1
    fi

    # --- Step 1: Create the database as the specified owner ---
    echo "Attempting to create database '${DB_NAME}' as owner '${DB_OWNER}'..."
    PGPASSWORD="${DB_PASSWORD}" createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_OWNER}" "${DB_NAME}"
    if [ $? -ne 0 ]; then
        echo "Warning: Could not create database. This is okay if it already exists or if '${DB_OWNER}' lacks CREATEDB privilege."
        echo "Continuing with restore..."
    else
        echo "Database created successfully."
    fi

    # --- Step 2: Restore the data ---
    local RESTORE_FILE=""
    if [[ "${BACKUP_FILE}" == *.gz ]]; then
        echo "Decompressing backup file: ${BACKUP_FILE}..."
        RESTORE_FILE=$(mktemp)
        gunzip -c "${BACKUP_FILE}" > "${RESTORE_FILE}" || { echo "Error: Could not decompress ${BACKUP_FILE}" >&2; rm -f "${RESTORE_FILE}"; return 1;
}
    else
        RESTORE_FILE="${BACKUP_FILE}"
    fi

    echo "Starting PostgreSQL restore for database: ${DB_NAME}..."
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_OWNER}" -d "${DB_NAME}" -f "${RESTORE_FILE}"

    if [ $? -eq 0 ]; then
        echo "Restore successful! Database '${DB_NAME}' has been restored."
    else
        echo "Restore failed!" >&2
        echo "Hint: Ensure the database exists and the user '${DB_OWNER}' has privileges to connect to it." >&2
        if [[ "${BACKUP_FILE}" == *.gz ]]; then rm -f "${RESTORE_FILE}"; fi
        return 1
    fi

    if [[ "${BACKUP_FILE}" == *.gz ]]; then
        rm -f "${RESTORE_FILE}"
        echo "Cleaned up temporary decompressed file."
    fi
}

# --- PostgreSQL Force Drop Database Function (with Connection Termination) ---
# WARNING: This will forcefully disconnect all users from the target database before dropping it.
# Usage: pg_force_drop_db [database_name] [postgres_password]
function pg_force_drop_db() {
    local DB_NAME_TO_DROP="${1:-zcrup_company_site_dev}"
    local POSTGRES_SUPERUSER="${2:-postgres}"
    local POSTGRES_HOST="${3:-192.168.0.4}"
    local POSTGRES_PORT="${4:-5432}"
    local POSTGRES_PASSWORD="${5:-your_postgres_password}" # Password for the 'postgres' user

    printf "WARNING: This will forcefully disconnect all users from '%s' and permanently delete it. Are you sure? (yes/no): " "${DB_NAME_TO_DROP}"
    builtin read CONFIRMATION

    if [[ ! "$CONFIRMATION" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Database deletion cancelled."
        return 0
    fi

    echo "Step 1: Terminating all active connections to '${DB_NAME_TO_DROP}'..."
    local TERMINATE_SQL="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME_TO_DROP}';"

    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres -c "${TERMINATE_SQL}"

    if [ $? -ne 0 ]; then
        echo "Warning: Could not terminate connections. The drop might fail if connections are still active."
    else
        echo "Connections terminated successfully."
    fi

    # Give the server a moment to process terminations
    sleep 1

    echo "Step 2: Attempting to drop database '${DB_NAME_TO_DROP}'..."
    local DROP_SQL="DROP DATABASE \"${DB_NAME_TO_DROP}\";"

    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres -c "${DROP_SQL}"

    if [ $? -eq 0 ]; then
        echo "Database '${DB_NAME_TO_DROP}' dropped successfully."
    else
        echo "Failed to drop database '${DB_NAME_TO_DROP}'."
        echo "This can happen if new connections were made after the termination step."
        echo "Please ensure your application (KeystoneJS) is stopped and try again."
        return 1
    fi
}
