# Imports
import preprocessing
import logging
import json
import numpy as np
from sklearn.metrics import mean_absolute_error, mean_poisson_deviance
import lightgbm as lgb
from scipy.stats import spearmanr
from preprocessing import prepare, setup_logging
from pathlib import Path

logger = logging.getLogger(__name__)

PARAMS_FILE = Path(__file__).resolve().parent / "best_params.json"
MODEL_FILE = Path(__file__).resolve().parent / "model_new_reviews.txt"
METRICS_FILE = Path(__file__).resolve().parent / "metrics.json"

# used when tuning has not produced anything yet
DEFAULT_PARAMS = {
"learning_rate":0.0138537723,
"num_leaves":217,
"min_data_in_leaf":483,
"feature_fraction":0.7839133831,
"bagging_fraction":0.730748003,
"lambda_l2":8.6229609066
}

FIXED_PARAMS = {
    "objective": "poisson",
    "metric": "poisson",
    "verbosity": -1,
}

def load_params():
    if PARAMS_FILE.exists():
        params = json.loads(PARAMS_FILE.read_text())
        logger.info("using tuned parameters from %s", PARAMS_FILE.name)
    else:
        params = dict(DEFAULT_PARAMS)
        logger.warning("no %s found, fall back to defaults", PARAMS_FILE.name)
    return {**params, **FIXED_PARAMS}


def score(y_true, pred):
    pred = np.clip(np.asarray(pred, dtype=float), 0.05, None)
    return {
        "MAE": round(mean_absolute_error(y_true, pred), 4),
        "PoissonDeviance": round(mean_poisson_deviance(y_true, pred), 4),
        "Spearman": round(spearmanr(y_true, pred).correlation, 4),
    }


def main():
    setup_logging()
    data, feature_cols, categorical = prepare()
    params = load_params()

    dtrain = lgb.Dataset(
        data["train"]["X"], data["train"]["y"],
        categorical_feature=categorical,
        params={"feature_pre_filter": False},
        free_raw_data=False,
    )
    dval = lgb.Dataset(
        data["val"]["X"], data["val"]["y"],
        reference=dtrain,
        free_raw_data=False,
    )

    model = lgb.train(
        params, dtrain,
        num_boost_round=2000,
        valid_sets=[dval],
        callbacks=[lgb.early_stopping(100), lgb.log_evaluation(200)],
    )
    logger.info("trained %d rounds (best iteration)", model.best_iteration)

    X_test, y_test = data["test"]["X"], data["test"]["y"]
    pred = model.predict(X_test, num_iteration=model.best_iteration)

    model_score = score(y_test, pred)
    baseline_score = score(y_test, data["test"]["raw"]["new_reviews_lag_1"].fillna(0))

    logger.info("model %s", model_score)
    logger.info("baseline %s", baseline_score)

    # Heuristic: a model that cannot beat Poisson Deviance from previous run is not worth deploying
    if model_score["PoissonDeviance"] >= baseline_score["PoissonDeviance"]:
        raise RuntimeError(f"model did not beat the baseline ({model_score['PoissonDeviance']} vs {baseline_score['PoissonDeviance']}), keeping the previous model")

    model.save_model(str(MODEL_FILE), num_iteration=model.best_iteration)
    METRICS_FILE.write_text(json.dumps(
        {"model": model_score, "baseline": baseline_score}, indent=2
    ))
    logger.info("saved model to %s", MODEL_FILE.name)


if __name__ == "__main__":
    main()