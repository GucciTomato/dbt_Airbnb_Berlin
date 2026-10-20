# Imports
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
import os
import logging
import yaml
import gzip, csv
from contextlib import closing
from pathlib import Path
import click


# Enable logging
logging.basicConfig(
    format="{asctime} - {levelname} - {message}",
    style="{",
    datefmt="%Y-%m-%d %H:%M",
    level=logging.INFO,
    handlers=[logging.StreamHandler(), logging.FileHandler("logs_ingestion_pipeline.log")],
)


# Check for existence of credentials to fail early
load_dotenv()

def require_env(key: str) -> str:
    val = os.getenv(key)
    if not val:
        raise EnvironmentError(f"Umgebungsvariable {key} fehlt")
    return val

# Database credentials
host = require_env("DB_HOST")
dbname = require_env("DB_NAME")
user = require_env("DB_USER")
password = require_env("DB_PASSWORD")

DSN = f"host={host} dbname={dbname} user={user} password={password}"


# Read metadata: tables and column for creating datawarehouse
def read_data_contract(file_path="data_ingestion_contract.yaml") -> list:
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            yaml_data = yaml.safe_load(f)

        if isinstance(yaml_data, dict):
            yaml_data = [yaml_data]
        elif not isinstance(yaml_data, list):
            raise ValueError("YAML content must be a list or dict")
        
        logging.info("Data contract loaded successfully: %s", file_path)
        return yaml_data
    except Exception as e:
        logging.exception("Failed to load data contract: %s", file_path)
        raise


data_contract = read_data_contract()


# Create tables and a schema for the raw data
def create_raw_schema_tables(DSN=DSN) -> None:
    try:
        with closing(psycopg2.connect(DSN)) as conn:
            with conn:
                with conn.cursor() as cur:
                    # Create schema
                    cur.execute("CREATE SCHEMA IF NOT EXISTS airbnb_raw_data AUTHORIZATION airbnb_berlin")
                    # Create tables
                    for table, columns in data_contract[0].items():
                        expected_columns = columns

                        if "data_cohort" not in expected_columns:
                            expected_columns.insert(0, "data_cohort")

                        column_def = sql.SQL(", ").join(sql.SQL("{} TEXT").format(
                            sql.Identifier(column)
                        ) for column in expected_columns)

                        query = sql.SQL("CREATE TABLE IF NOT EXISTS {} ({})"
                                        ).format(sql.Identifier("airbnb_raw_data",table), column_def)
                        cur.execute(query)

                        # Validate table existence
                        cur.execute("""
                        SELECT column_name FROM information_schema.columns
                        WHERE table_schema = %s AND table_name = %s
                        """, ("airbnb_raw_data", table))

                        actual_columns = {row[0] for row in cur.fetchall()}
                        missing = set(expected_columns) - actual_columns
                        if missing: raise ValueError(f"Table {table}: Missing columns {missing}")

                        logging.info("Validated table %s: %d columns",table,len(actual_columns))

                        actual_columns = {row[0] for row in cur.fetchall()}

            logging.info("Raw schema and table creation successful.")
    except Exception:
        logging.exception("Schema creation failed")
        raise


# List existing data for ingestion
RAW_DATA_PATH = Path(require_env("RAW_DATA_PATH")).expanduser().resolve()

def find_existing_data(filepath: Path = RAW_DATA_PATH) -> dict:
    candidates = {}
    for directory in filepath.iterdir():
        if directory.is_dir() and directory.name.startswith("data_"):
            candidates[directory.name] = [f.name for f in directory.iterdir() if f.name.startswith(("listings", "reviews")) and f.name.endswith(".csv.gz")]
    
    return candidates


# Check folder names
def check_folders(folders_specified: tuple) -> None:
        existing_folders = find_existing_data().keys()

        invalid_folders = set(folders_specified) - set(existing_folders)

        if invalid_folders: 
                raise click.ClickException(f"unknown folder(s): {', '.join(sorted(invalid_folders))}")
        

# Detect schema drift
def read_header(folders_specified: tuple) -> list[str]:
    existing_data = find_existing_data()
    headers = {}

    for folder in existing_data:
        if folder in folders_specified:

            headers[folder] = {}

            for file in existing_data[folder]:
                with gzip.open(RAW_DATA_PATH / folder / file, "rt", encoding="utf-8", newline="") as f:
                    header = next(csv.reader(f))
                    headers[folder][file] = header

    return headers

def check_contract(folders_specified: tuple) -> None:
    data_contract = read_data_contract()[0]
    headers = read_header(folders_specified)
    unknown_found = False

    for folder, files in headers.items():
        for file, real_columns in files.items():
            contract_columns = data_contract[file.removesuffix(".csv.gz")]
            unknown = [c for c in real_columns if c not in contract_columns]
            missing = [c for c in contract_columns if c not in real_columns and c != "data_cohort"]

            if unknown:
                logging.error("Schema drift %s/%s: unknown columns %s", folder, file, unknown)
                unknown_found = True
            if missing:
                logging.warning("Schema drift %s/%s: missing columns %s (become NULL)", folder, file, missing)

    if unknown_found:
        raise ValueError("Unknown columns found – update data contract (see log)")

# Ingest data from local files into the tables via temporary table
def load_file(folders_for_ingestion: tuple) -> None:
    check_contract(folders_for_ingestion)
    existing_data = find_existing_data()

    headers = read_header(folders_for_ingestion)
    for folder in folders_for_ingestion:
        data_cohort = folder.removeprefix("data_")
        for file in existing_data[folder]:
            table = file.removesuffix(".csv.gz")
            header = headers[folder][file]
            column_definitions = sql.SQL(", ").join(sql.SQL("{} text").format(sql.Identifier(c)) for c in header)
            columns = sql.SQL(", ").join(map(sql.Identifier, header))
            logging.info("Starting ingestion %s/%s",table,file)
            try:
                with closing(psycopg2.connect(DSN)) as conn:
                    with conn:
                        with conn.cursor() as cur:
                            # Temporary staging table
                            cur.execute(sql.SQL("CREATE TEMP TABLE tmp_load ({}) ON COMMIT DROP").format(column_definitions))
                            # Copy csv into staging
                            with gzip.open(RAW_DATA_PATH / folder / file, "rt", encoding="utf-8", newline="") as f:
                                cur.copy_expert("COPY tmp_load FROM STDIN WITH (FORMAT csv, HEADER true)", f)
                            # Validate row count
                            cur.execute("SELECT COUNT(*) FROM tmp_load")
                            staged_rows = cur.fetchone()[0]
                            if staged_rows == 0:
                                raise ValueError(f"No data found in {file}")
                            # Delete existing cohort
                            cur.execute(sql.SQL(
                                "DELETE FROM {} WHERE data_cohort = %s").format(sql.Identifier("airbnb_raw_data", table)), (data_cohort,)
                            )
                            # Insert new cohort into raw table
                            cur.execute(sql.SQL(
                                    "INSERT INTO airbnb_raw_data.{t} (data_cohort, {c}) SELECT %s, {c} FROM tmp_load"
                            ).format(t=sql.Identifier(table), c=columns), (data_cohort,))
                            inserted_rows = cur.rowcount
                logging.info(
                    "Ingestion successful: table=%s, cohort=%s, staged=%d, inserted=%d",
                    table, data_cohort, staged_rows, inserted_rows
                )
            except Exception:
                logging.exception("Ingestion failed: table=%s, file=%s", table, file)
                raise


def find_loaded_cohorts() -> set[str]:
    loaded = None
    with closing(psycopg2.connect(DSN)) as conn, conn.cursor() as cur:
        for table in data_contract[0]:
            cur.execute(sql.SQL("SELECT DISTINCT data_cohort FROM {}").format(sql.Identifier("airbnb_raw_data", table)))
            cohorts = {"data_" + row[0] for row in cur.fetchall()}
            loaded = cohorts if loaded is None else loaded & cohorts
    return loaded or set()


def run_pipeline_existing(data_ingestion):
    if not data_ingestion:
        data_ingestion = find_existing_data().keys()
    check_folders(data_ingestion)
    create_raw_schema_tables()
    check_contract(data_ingestion)
    load_file(data_ingestion)
    click.echo(f"\nIngestion process successful.\n")