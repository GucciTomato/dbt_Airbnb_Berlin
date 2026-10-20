import asyncio
import click
import download
import load_local_data

@click.command()
@click.argument("folders", nargs=-1)
@click.option("--all", "load_all", is_flag=True, help="(Re-)load all local cohorts.")
def ingestion_pipeline(folders, load_all):
    """Download new data from Inside Airbnb and load them into raw tables.

    \b
    (without specification) only cohorts which are not in the database yet (standard).
    --all                   all local cohorts
    FOLDERS                 only specific cohorts, e.g. data_26.09.19 data_26.06.26
    """
    if load_all and folders:
        raise click.UsageError("Please choose: all OR specific folders, not both.")

    soup = asyncio.run(download.get_existing_online_data())
    download.download_files(soup)

    load_local_data.create_raw_schema_tables()
    local = set(load_local_data.find_existing_data())

    if folders:
        unknown = set(folders) - local
        if unknown:
            raise click.BadParameter(f"Unknown folder/cohort: {', '.join(sorted(unknown))}")
    elif load_all:
        folders = sorted(local)
    else:
        folders = sorted(local - load_local_data.find_loaded_cohorts())

    if not folders:
        click.echo("Nothing new to load.")
        return

    load_local_data.load_file(tuple(folders))
    click.echo(f"Ingestion successful: {', '.join(folders)}")

if __name__ == "__main__":
    ingestion_pipeline()