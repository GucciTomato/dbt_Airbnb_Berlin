import click

@click.group()
def raw_data_ingestion():
    """
    A CLI tool for raw data ingestion into the database.
    If the database does not exist it will be created.
    There are two flags available:
    
    1.) existing-data

    2.) new-data
    """
    pass


my_data = {'data_26.06.26': ['listings.csv.gz', 'reviews.csv.gz'],
 'data_25.09.23': ['listings.csv.gz', 'reviews.csv.gz'],
 'data_25.12.27': ['listings.csv.gz', 'reviews.csv.gz'],
 'data_26.03.28': ['listings.csv.gz', 'reviews.csv.gz']}


@raw_data_ingestion.command()
@click.argument(
    "names",
    nargs=-1,
    required=False,
    type = str,
    help= "Specify existing local data you want to ingest into the raw table.\
            1.) Either hit ENTER for all data, or, 2.) to specify data from certian cohorts, \
                 use folder names in format data_YY.MM.DD separated by a space"
)
def existing_data(names):
    data = my_data
    if not names:
        click.echo(f"\nYou hit ENTER: Here is all the data:\n{data}")
    else:
        not_found = []
        found = []
        for element in data.keys():
            for name in names:
                if element == name:
                    click.echo(f"Found your folder: {element}")
                    found.append(name)
                else:
                    not_found.append(name)
    not_found = set(not_found) - set(found)
    if not_found:
        click.echo(f"Error: did not find: {not_found}")

if __name__ == '__main__':
    raw_data_ingestion()