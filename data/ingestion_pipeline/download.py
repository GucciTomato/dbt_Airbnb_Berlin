# Imports
import asyncio
import logging
import re
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlretrieve

from bs4 import BeautifulSoup
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

from load_local_data import require_env, find_existing_data


# Enable logging
logging.basicConfig(
    format="{asctime} - {levelname} - {message}",
    style="{",
    datefmt="%Y-%m-%d %H:%M",
    filename="logs_ingestion_pipeline.log",
    level=logging.INFO,
    force = True
)

url = "https://insideairbnb.com/en/get-the-data/"

async def get_existing_online_data():
    logging.info("Lade Seite %s", url)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        try:
            await page.goto(url, wait_until="networkidle")
            number_of_h4_elements_before_click = await page.locator("h4").count()
            logging.debug("h4-elements before clicking: %d", number_of_h4_elements_before_click)

            await page.locator("a.showArchivedData[data-city='Berlin']").click()
            await page.locator("h4").nth(number_of_h4_elements_before_click).wait_for()
            logging.debug("h4-elements after clicking: %d", await page.locator("h4").count())
        except PlaywrightTimeoutError:
            logging.exception("Timeout when loading website or archive data")
            raise
        finally:
            soup = BeautifulSoup(await page.content(), "html.parser")
            await browser.close()

    logging.info("Website loading successful")
    return soup


def extract_city_files(soup):
    start = soup.find(lambda t: t.name == "h3" and t.get_text(strip=True).startswith("Berlin,"))
    if start is None:
        logging.error("No h3-Header found for Berlin – has website structure changed?")
        raise ValueError("Berlin section not found")

    files = []
    for element in start.find_all_next(["h3", "a"]):
        if element.name == "h3":
            break
        if "data.insideairbnb.com" in element.get("href", ""):
            files.append({"file": element.get_text(strip=True), "url": element["href"], "date": element["href"].split("/")[-3]})

    logging.info("%d Files for Berlin found online: ", len(files))
    return files



def candidates_for_download(soup):
    berlin_files = extract_city_files(soup)

    remaining = {}
    raw_candidates = [file for file in berlin_files if file['file'].endswith("listings.csv.gz") or file['file'].endswith("reviews.csv.gz")]
    online_data = {"data_" + re.sub(r'/data/.*', '', file['url'].removeprefix("https://data.insideairbnb.com/germany/be/berlin/20").replace("-", ".")): {} for file in raw_candidates}

    for file in raw_candidates:
        file_cohort = file['url'].removeprefix("https://data.insideairbnb.com/germany/be/berlin/20").replace("-", ".")
        file_cohort = "data_" + re.sub(r'/data/.*', '', file_cohort)
        online_data[file_cohort][file['file']] = file['url']

    local_data = find_existing_data()
    logging.debug("Online-cohorts: %s", sorted(online_data))
    logging.debug("Local cohorts: %s", sorted(local_data))

    # cohort wise comparison
    diff_cohorts = [element for element in online_data.keys() if element not in local_data.keys()]
    for cohort in diff_cohorts:
        logging.info("New cohort: %s", cohort)
        remaining[cohort] = online_data[cohort]

    # table wise comparison
    for cohort in local_data:
        if cohort in online_data.keys():
            diff = [table for table in online_data[cohort].keys() if table not in local_data[cohort]]
            if diff:
                logging.info("Cohort %s incomplete! Missing: %s", cohort, diff)
                remaining[cohort] = {table: online_data[cohort][table] for table in diff}

    if not remaining:
        logging.info("Everything up to date - nothing to be downloaded")

    return remaining


def download_files(soup):
    to_be_downloaded = candidates_for_download(soup)

    data_directory = Path(require_env("RAW_DATA_PATH"))

    for cohort in to_be_downloaded:
        cohort_directory = data_directory / cohort
        cohort_directory.mkdir(parents=True, exist_ok=True)
        
        for file_name, url in to_be_downloaded[cohort].items():
            logging.info("Download %s/%s", cohort, file_name)
            try:
                urlretrieve(url, cohort_directory / file_name)
            except URLError:
                logging.exception("Download failed: %s", url)


if __name__ == "__main__":
    soup = asyncio.run(get_existing_online_data())
    download_files(soup)