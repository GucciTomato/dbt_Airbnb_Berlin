import asyncio
import click
import download
import load_local_data
from storage import get_storage
import logging
from pathlib import Path

LOG_FILE = Path(__file__).resolve().parent / "logs_ingestion_pipeline.log"

logging.basicConfig(
    format="{asctime} - {levelname} - {name} - {message}",
    style="{",
    datefmt="%Y-%m-%d %H:%M",
    level=logging.INFO,
    handlers=[logging.StreamHandler(), logging.FileHandler(LOG_FILE)],
)

@click.command()
@click.argument("folders", nargs=-1)
@click.option("--all", "load_all", is_flag=True, help="(Re-)load all cohorts.")
@click.option("--target", type=click.Choice(["local", "cloud"]), envvar="PIPELINE_TARGET", default="local", show_envvar=True, show_default=True)
def ingestion_pipeline(folders, load_all, target):
    """Download new data from Inside Airbnb and load them into raw tables.

    \b
    Options:

    Which target?
    --target                specify target: cloud or local

    Which files?
    (without specification) only cohorts which are not in the database yet (standard).
    --all                   all cohorts
    FOLDERS                 only specific cohorts, e.g. data_26.09.19 data_26.06.26
    """
    storage = get_storage(target)

    soup = asyncio.run(download.get_existing_online_data())
    download.download_files(soup, storage)

    load_local_data.create_raw_schema_tables()
    existing = set(storage.find_existing_data())

    if folders:
        unknown = set(folders) - existing
        if unknown:
            raise click.BadParameter(f"Unknown folder/cohort: {', '.join(sorted(unknown))}")
    elif load_all:
        folders = sorted(existing)
    else:
        folders = sorted(existing - load_local_data.find_loaded_cohorts())

    if not folders:
        click.echo("Nothing new to load.")
        return

    load_local_data.load_file(storage, tuple(folders))
    click.echo(f"Ingestion successful: {', '.join(folders)}")

if __name__ == "__main__":
    ingestion_pipeline()