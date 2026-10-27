# Airbnb Berlin data project

This project presents an automated pipeline which scrapes the Airbnb Berlin listings and review data from the insideairbnb.com website every three months (when new data gets published), stores it either locally or in the cloud, transforms it with dbt and finally trains a ML-model on the aggregated data by month to predict review activity for the following months. The project uses Python, dbt, Docker, Airflow and Terraform to achieve this. What makes the dataset an intriguing choice to work with is that it represents real world data with common problems associated with it: inconsistent metadata, schema drift and missingness, which pose an interesting challenge during the necessary cleansing and preparation. 

## Ingestion pipeline

### Scrape process + download scripts

### Airflow 
This hybrid set-up is chosen under the assumption that regular database-querying of the mart data during day to day operations e.g. by the analytics team is a necessity. If the setup is only used for model retraining like described in the Airflow DAG then propably a cloud native only solution would be cheaper and would have less overhead. In this case, a Step Functions script with a ECS Fargate Task (which stops itself after completion) could replace Airflow.

For a completely cloud native set up one could replace Airflow with Step Functions script with ECS Fargate Task. But for the mean time the cloud task seems to be cheaper and have less overhead.

 I have outsourced the retry logic of the DAG after failure from Airflow to a Shell script which is able to shut down Airflow after success. This has three reasons: data security: airflow and VPN only up for a few hours, the rest of the time PC is isolated from AWS, zero ressource consumption and robustness...

 one of the trade offs was that I thought about automatic stopping of the airflow after dag completion as airflow shutting itself down can be fragile. I first tried to use docker.io with socket so external services could talk to the docker deamon without root rights, but this means de facto root access on the host which is a security concern so I kept everything in one startup shell script at the price of one script having to run until the dag completes which could take weeks in case of missing data. Here a more elegant solution has to be found in the future but for the mean time it was a tradeoff between realisism and complexity.

 ### AWS?

 nstance Connect Endpoint? Max time up for tunnel 1h... SSM Session Manager

## dbt

In this setup I have chosen a separate database instead of dbt seeds is because of the massive volume of the Airbnb Berlin datasets. Even though official metadata exists it is incomplete and therefore to be treated with care.

In dbt I use three layers to mark the process from complete raw data cohorts (with PII removed) in staging to transformed data in intermediate up to the mart layer with aggregated cleaned data for business level analysis and machine learning.

To get an overview of the complete model sequence and dependencies, please use:
```
dbt docs generate
dbt docs serve --port 8081
```

## ML

follows the principle of a forward walking evaluation: the newest cohort is scored once as test, before it is used for tuning or training. On the next run it shifts to validation and later into the training set, so no cohort is evaluated twice.

I used review activity as the target as it might represent a practical proxy for non available booking data [source???]. The data contains availability features but they are a poor choice, first because they are an aggregated statistic only published once for every cohort and secondly can contain blocked time windows by the host or might be unavailable because of minimum night constraints.

certain data does not change over cohorts, but certain data does so a complete data-leakage free ml tuning is a real challenge here.

    • Problem: geblockt kann gebucht heißen oder vom Anbieter selber geblockt. Zwar haben Anbieter ökonomisch betrachtet durchaus einen Anreiz ihr Apartement als verfügbar zu markieren, wenn es auch frei ist, um Geld zu verdienen, aber davon kann in letzter Instanz nicht ausgegangen werden. Diese Ungewissheit verschlechtert die Vorhersagegüte.
    • Zielvariable: Reviewaktivität (sagt nichts über unterschiedliche Reviewer aus; Authentizität und Bewertung) -> Proxy für Beliebtheit oder Auslastung?

    Was bewusst draußen bleibt (Leakage): reviews_per_month, last_review, days_since_last_review und die estimated_*-Spalten. Alle werden gemeinsam mit der Reviewanzahl fortgeschrieben und würden das Ziel teilweise enthalten.

    Ansatz ist Gradient Boosting (LightGBM oder XGBoost) auf der flachen Monatstabelle, da sehr stark auf Tabellen und latente Features lernen können, mit dem Monat als Feature und Lag-Variablen für die Vorgeschichte. Das ist bei Panel-Daten mit vielen Einheiten und kurzen Reihen (später mit mehr zeitlichen Daten könnte man Zeitreihenmodelle machen, Prophet z.B.)

Finetuning is done manually after email alert


## How to set everything up

To set up a cron job to automate the workflow every three months, with Linux/macOS use 
```
crontab -e 
```

in Windows the Task Scheduler can be used, and type:
```
0 0 1 */3 * /path/to/local/project/run_pipeline.sh
```

give scripts execution rights:
chmod +x start_pipeline.sh stop_pipeline.sh


cd terraform/
Install Terraform 



for docker Gid:
echo "DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)" >> .env


cd ../docker
docker build
docker compose up --env-file ../.env



für RDS muss einmalig:

CREATE EXTENSION IF NOT EXISTS aws_s3 CASCADE; 

damit der ZUgriff auf RDS klappt


set a dbt profile in profiles.yml in: ~/.dbt/profiles.yml

## Future steps

* finetune ML with more hyperparameter and adaptive search algorithm
* put ML training into the cloud (e.g. with airflow.providers.amazon.aws.operators.sagemaker)
* implement agentic sytem with LangGraph for automated handling of Airflow failures e.g. ascertain problem type (software problem, database problem...) and proposing changes (e.g. updating old web url) code changes via Pull requests that will be reviewed by humans

hypothetically, if data would be really queried by analytics team:
* implement e.g. Tailscale as a zero-config peer-to-peer VPN solution, because even though it has more initial setup overhead afterwards it is more comfortable because one does not need to start an ssm session every time before sql querying
* 