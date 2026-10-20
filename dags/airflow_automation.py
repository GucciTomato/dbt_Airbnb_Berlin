# Imports
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator
from datetime import datetime, timedelta

with DAG(
    dag_id="airbnb_berlin_data_ingestion_pipeline",
    start_date=datetime(2026, 10, 1),
    schedule="@weekly",
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=30)},
) as dag:
    ingestion_pipeline_task = BashOperator(
        task_id="ingestion_pipeline",
        bash_command="/opt/airflow/app-venv/bin/python ingestion_pipeline.py",
        cwd="/opt/airflow/project/data/ingestion_pipeline",
    )

    ingestion_pipeline_task