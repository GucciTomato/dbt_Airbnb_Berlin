import gzip
import os
import subprocess
from pathlib import Path
import psycopg2
import pytest

pytestmark = pytest.mark.integration

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = os.getenv("DBT_SCHEMA", "integration")

LISTINGS = "id,last_scraped,host_id,neighbourhood_cleansed,neighbourhood_group_cleansed,room_type,number_of_reviews,price"
REVIEWS = "listing_id,id,date,reviewer_id"
COHORTS = {
    "25.12.27": {
        "listings": ["1001,2025-12-27,1,Moabit,Mitte,Entire home/apt,1,$80.00",
                     "1002,2025-12-27,2,Moabit,Mitte,Private room,1,$40.00"],
        "reviews": ["1001,1,2025-10-05,9", "1002,2,2025-11-20,9"],
    },
    "26.03.28": {
        "listings": ["1001,2026-03-28,1,Moabit,Mitte,Entire home/apt,2,\"$1,200.00\""],
        "reviews": ["1001,1,2025-10-05,9", "1001,3,2026-01-10,9"],
    },
    "26.06.26": {
        "listings": ["1001,2026-06-26,1,Moabit,Mitte,Entire home/apt,2,$85.00",
                     "1002,2026-06-26,2,Moabit,Mitte,Private room,2,$40.00"],
        "reviews": ["1001,1,2025-10-05,9", "1002,2,2025-11-20,9", "1001,3,2026-01-10,9", "1002,4,2026-05-03,9"],
    },
}


def dbt_build() -> None:
    subprocess.run(["dbt", "build", "--exclude", "test_type:unit", "--profiles-dir", "../tests/integration"],
                   cwd=ROOT / "dbt", check=True)


@pytest.fixture(scope="module")
def db(tmp_path_factory) -> None:
    if not os.getenv("DB_NAME", "").endswith("_test"):
        pytest.skip("needs a throwaway database: DB_NAME must end with '_test'")

    from ingestion_pipeline import load_local_data
    from ingestion_pipeline.storage import LocalStorage

    conn = psycopg2.connect(load_local_data.DSN)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute(f"DROP SCHEMA IF EXISTS airbnb_raw_data, {SCHEMA} CASCADE")

    # write the cohorts as data_<cohort>/<table>.csv.gz, like the real download
    raw = tmp_path_factory.mktemp("raw")
    for cohort, tables in COHORTS.items():
        (raw / f"data_{cohort}").mkdir()
        for table, header in (("listings", LISTINGS), ("reviews", REVIEWS)):
            with gzip.open(raw / f"data_{cohort}" / f"{table}.csv.gz", "wt") as f:
                f.write("\n".join([header, *tables[table]]) + "\n")

    storage = LocalStorage(str(raw))
    load_local_data.create_raw_schema_tables()

    # two pipeline runs: initial load, then the next quarter (incremental)
    load_local_data.load_file(storage, ("data_25.12.27", "data_26.03.28"))
    dbt_build()
    load_local_data.load_file(storage, ("data_26.06.26",))
    dbt_build()

    yield cur
    conn.close()


def test_raw_tables_hold_every_cohort(db) -> None:
    db.execute("SELECT data_cohort, COUNT(*) FROM airbnb_raw_data.listings GROUP BY 1 ORDER BY 1")
    assert db.fetchall() == [("25.12.27", 2), ("26.03.28", 1), ("26.06.26", 2)]


def test_incremental_reviews_without_duplicates(db) -> None:
    db.execute(f"SELECT reviews_id, first_seen_cohort::text FROM {SCHEMA}.fct_airbnb_reviews ORDER BY 1")
    assert db.fetchall() == [(1, "2025-12-27"), (2, "2025-12-27"), (3, "2026-03-28"), (4, "2026-06-26")]


def test_snapshots_detect_reappearance_and_clean_price(db) -> None:
    db.execute(f"""
        SELECT listings_id, cohort_date::text, price, is_reappearance
        FROM {SCHEMA}.fct_airbnb_listing_snapshots ORDER BY 1, 2
    """)
    assert db.fetchall() == [
        (1001, "2025-12-27", 80, False),
        (1001, "2026-03-28", 1200, False),
        (1001, "2026-06-26", 85, False),
        (1002, "2025-12-27", 40, False),
        (1002, "2026-06-26", 40, True),
    ]