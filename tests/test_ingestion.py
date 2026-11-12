import pytest
from pathlib import Path
from bs4 import BeautifulSoup
from unittest.mock import Mock
from bs4 import BeautifulSoup
from ingestion_pipeline import download, load_local_data

fixture_path = Path(__file__).parent / "fixtures/inside_airbnb_sample_data.html"


@pytest.fixture
def soup():
    html = fixture_path.read_text(encoding="utf-8")
    return BeautifulSoup(html, "html.parser")


def test_extract_city_files(soup):
    files = download.extract_city_files(soup)

    assert len(files) == 28
    assert all("/berlin/" in file["url"] for file in files)


def test_candidates_for_download(soup):
    storage = Mock()
    storage.find_existing_data.return_value = {}

    candidates = download.candidates_for_download(soup, storage)

    assert candidates

    for files in candidates.values():
        assert set(files).issubset({"listings.csv.gz", "reviews.csv.gz"})

    storage.find_existing_data.return_value = { cohort: list(files) for cohort, files in candidates.items()}

    assert download.candidates_for_download(soup, storage) == {}


def test_check_contract(monkeypatch):
    # simulated 
    monkeypatch.setattr(load_local_data, "read_data_contract", lambda: [{"listings": ["id", "name"]}])

    # CSV contains addition unknown columns
    monkeypatch.setattr(
        load_local_data, "read_header", lambda storage, folders: {
            "data_26.06.26": {"listings.csv.gz": ["id", "name", "unexpected_column"]}
        }
    )

    with pytest.raises(ValueError, match="Unknown columns"):
        load_local_data.check_contract(storage=None, folders_specified=("data_26.06.26",))


def test_download_files_failure(monkeypatch):
    storage = Mock()

    monkeypatch.setattr(download, "candidates_for_download", lambda soup, storage: {
            "data_26.06.26": {"listings.csv.gz": "https://example.com/listings.csv.gz","reviews.csv.gz": "https://example.com/reviews.csv.gz"}
    })

    storage.store_file.side_effect = [OSError("Simulierter Download-Fehler"), None]

    with pytest.raises(RuntimeError, match="listings.csv.gz"):
        download.download_files(None, storage)

    assert storage.store_file.call_count == 2