# Imports
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os
import numpy as np
import logging
from pathlib import Path

logger = logging.getLogger(__name__)
LOG_FILE = Path(__file__).resolve().parent / "logs_ml_pipeline.log"

LOG_FILE = Path(__file__).resolve().parent / "logs_ml_pipeline.log"

TARGET = "new_reviews"

ID_COLS = ["month_key", "listings_id", "target_month", "feature_cohort_date"]

CATEGORICAL = [
    "room_type",
    "building_type",
    "stay_type",
    "price_source",
    "neighbourhood_group_cleansed",
    "neighbourhood_cleansed",
]


def setup_logging():
    logging.basicConfig(
        format="{asctime} - {levelname} - {name} - {message}",
        style="{",
        datefmt="%Y-%m-%d %H:%M",
        level=logging.INFO,
        handlers=[logging.StreamHandler(), logging.FileHandler(LOG_FILE)],
    )


# Check for existence of credentials, if not found, fail early
load_dotenv(override=True)

def require_env(key: str) -> str:
    val = os.getenv(key)
    if not val:
        logging.error("Environment variable {key} missing. Abort")
        raise EnvironmentError(f"Environment variable {key} is missing")
    return val


def get_engine():
    # Database credentials
    host = require_env("DB_HOST")
    dbname = require_env("DB_NAME")
    user = require_env("DB_USER")
    password = require_env("DB_PASSWORD")
    db_port = require_env("DB_PORT")

    return create_engine(f"postgresql+psycopg2://{user}:{password}@{host}:{db_port}/{dbname}", isolation_level="AUTOCOMMIT")


def load_to_sql():
    df = pd.read_sql(
        "SELECT * FROM public.ml_monthly_features ORDER BY listings_id, target_month",
        get_engine(),
        parse_dates=["target_month", "feature_cohort_date"],
        dtype_backend="numpy_nullable",  # avoid postgres -> pandas dtype problems
    )
    logger.info("loaded %d rows, %d columns", len(df), df.shape[1])
    return df


def define_feature_cols(df):
    cols = [c for c in df.columns if c not in ID_COLS + [TARGET]]

    empty = [c for c in cols if df[c].isna().all()]
    if empty:
        logger.warning("dropping columns that are empty in every row: %s", empty)
    cols = [c for c in cols if c not in empty]

    cats = [c for c in CATEGORICAL if c in cols]
    logger.info("%d features, %d of them categorical", len(cols), len(cats))
    return cols, cats


# helper function
def to_lgbm(data, feature_cols, categorical):
    """Nullable pandas dtypes -> what LightGBM accepts. NaN stays NaN."""
    out = data[feature_cols].copy()
    for c in feature_cols:
        if c in categorical:
            out[c] = out[c].astype("category")
        else:
            out[c] = pd.to_numeric(out[c], errors="coerce").astype("float64")
    return out


# Dynamic Train-Val-Test-Split
def create_dataset_split(df):
    cohorts = np.sort(df["feature_cohort_date"].unique())
    if len(cohorts) < 3:
        raise ValueError(f"need at least 3 cohorts to split, found {len(cohorts)}")

    train = df[df["feature_cohort_date"] < cohorts[-2]]
    val = df[df["feature_cohort_date"] == cohorts[-2]]
    test = df[df["feature_cohort_date"] == cohorts[-1]]

    logger.info(
        "split by cohort: train %d (< %s), val %d (%s), test %d (%s)",
        len(train), str(cohorts[-2])[:10],
        len(val), str(cohorts[-2])[:10],
        len(test), str(cohorts[-1])[:10],
    )
    return train, val, test

def prepare():
    df = load_to_sql()
    feature_cols, categorical = define_feature_cols(df)
    train, val, test = create_dataset_split(df)

    data = {}
    for name, part in [("train", train), ("val", val), ("test", test)]:
        data[name] = {
            "X": to_lgbm(part, feature_cols, categorical),
            "y": part[TARGET].astype("float64"),
            "raw": part,  # keep ids for evaluation
        }

    return data, feature_cols, categorical


if __name__ == "__main__":
    setup_logging()
    data, feature_cols, categorical = prepare()
    print({k: len(v["y"]) for k, v in data.items()})