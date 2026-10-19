from airflow import DAG
from airflow.operators.python import PythonOperator

def check_existing_data():
    pass
    # implement flag in cli click program to overwrite all existing data
    # und am Ende: check all

def start_ingestion_pipeline():
    pass


with DAG(
    dag_id = "airbnb_berlin_data_ingestion_pipeline",
    start_date = datetime(2026, 10, 19),
    schedule = "@quarterly",
    catchup = False,
) as dag:
    
    check_existing_data_task = PythonOperator(task_id="check_existing_data", python_callable=check_existing_data)

    start_ingestion_pipeline = PythonOperator(task_id="start_ingestion_pipeline", python_callable=start_ingestion_pipeline)

    check_existing_data >> start_ingestion_pipeline