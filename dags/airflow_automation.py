# Imports
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator
from datetime import datetime, timedelta
import os
from airflow.providers.smtp.notifications.smtp import SmtpNotifier

ALERT_EMAIL = os.environ["ALERT_EMAIL"]
DBT = "/opt/airflow/dbt-venv/bin/dbt"
DBT_DIR = "/opt/airflow/project/dbt"
ML_DIR = "/opt/airflow/project/ml"

with DAG(
    dag_id="airbnb_berlin_data_ingestion_pipeline",
    start_date=datetime(2026, 10, 1),
    schedule=None,
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=30)},
) as dag:
    
    ingestion_pipeline_task = BashOperator(
        task_id="ingestion_pipeline",
        bash_command="/opt/airflow/app-venv/bin/python ingestion_pipeline.py",
        cwd="/opt/airflow/project/data/ingestion_pipeline",
        retries=2,
        retry_delay=timedelta(seconds=30), # for debugging e.g. seconds=30
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT} build",
        cwd=DBT_DIR,
        retries=0,
        on_failure_callback=SmtpNotifier(
            to=ALERT_EMAIL,
            subject="Airflow: {{ ti.dag_id }} / {{ ti.task_id }} failed",
        ),
    )

    train_model = BashOperator(
        task_id="train_model",
        bash_command=f"/opt/airflow/app-venv/bin/python {ML_DIR}/training.py",
        cwd=ML_DIR,
        retries=0,
        on_failure_callback=SmtpNotifier(
            to=ALERT_EMAIL,
            subject="Airflow: {{ ti.dag_id }} / {{ ti.task_id }} failed",
        ),
    )

    ingestion_pipeline_task >> dbt_build >> train_model