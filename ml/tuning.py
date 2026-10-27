import json
import logging
from pathlib import Path
import lightgbm as lgb
import numpy as np
import optuna
from sklearn.metrics import mean_poisson_deviance
from preprocessing import prepare, setup_logging

logger = logging.getLogger(__name__)

PARAMS_FILE = Path(__file__).resolve().parent / "best_params.json"
STORAGE = f"sqlite:///{Path(__file__).resolve().parent / 'optuna_reviews.db'}"

TRIALS = 500


def main():
    setup_logging()
    optuna.logging.set_verbosity(optuna.logging.WARNING)

    data, feature_cols, categorical = prepare()

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
    X_val, y_val = data["val"]["X"], data["val"]["y"]

    def objective(trial):
        params = dict(
            objective="poisson",
            metric="poisson",
            learning_rate=trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
            num_leaves=trial.suggest_int("num_leaves", 15, 255, log=True),
            min_data_in_leaf=trial.suggest_int("min_data_in_leaf", 20, 500, log=True),
            feature_fraction=trial.suggest_float("feature_fraction", 0.5, 1.0),
            bagging_fraction=trial.suggest_float("bagging_fraction", 0.5, 1.0),
            bagging_freq=1,  # required, otherwise bagging_fraction is ignored
            lambda_l2=trial.suggest_float("lambda_l2", 1e-3, 10.0, log=True),
            verbosity=-1,
        )

        model = lgb.train(
            params, dtrain,
            num_boost_round=2000,
            valid_sets=[dval],
            callbacks=[lgb.early_stopping(100, verbose=False)],
        )

        pred = model.predict(X_val, num_iteration=model.best_iteration)
        return mean_poisson_deviance(y_val, np.clip(pred, 0.05, None))

    study = optuna.create_study(
        study_name="new_reviews_poisson",
        storage=STORAGE,
        direction="minimize",
        load_if_exists=True,
        sampler=optuna.samplers.TPESampler(seed=42),
    )
    study.optimize(objective, n_trials=TRIALS, show_progress_bar=True)

    logger.info("%d trials total, best deviance %.4f", len(study.trials), study.best_value)
    logger.info("best params: %s", study.best_params)

    params = {**study.best_params, "bagging_freq": 1}
    PARAMS_FILE.write_text(json.dumps(params, indent=2))
    logger.info("wrote %s", PARAMS_FILE.name)


if __name__ == "__main__":
    main()