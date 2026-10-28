FROM apache/airflow:3.3.2-python3.12

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/airflow/ms-playwright

# Install libgomp.so.1 for local LightGBM before pip requirements.txt
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*
USER airflow

# dbt venv
RUN python -m venv /opt/airflow/dbt-venv \
    && /opt/airflow/dbt-venv/bin/pip install --no-cache-dir dbt-core==1.12.5 dbt-postgres==1.9.1

COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/airflow/app-venv \
    && /opt/airflow/app-venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && /opt/airflow/app-venv/bin/playwright install chromium \
    && mkdir -p /opt/airflow/state && chmod -R g+rwX /opt/airflow/state

# Installing system libraries for chromium requires root user again
USER root
RUN /opt/airflow/app-venv/bin/playwright install-deps chromium && rm -rf /var/lib/apt/lists/*
USER airflow

COPY --chown=airflow:root . /opt/airflow/project
WORKDIR /opt/airflow/project