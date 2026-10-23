# Imports
import csv, gzip 
import io
from pathlib import Path
from urllib.request import urlopen, urlretrieve 
import boto3
from load_local_data import require_env


class LocalStorage:
    def __init__(self, root: str):
        self.root = Path(root).expanduser().resolve()

    def find_existing_data(self) -> dict:
        candidates = {}
        for directory in self.root.iterdir():
            if directory.is_dir() and directory.name.startswith("data_"):
                candidates[directory.name] = [
                    f.name for f in directory.iterdir()
                    if f.name.startswith(("listings", "reviews")) and f.name.endswith(".csv.gz")
                ]
        return candidates

    def store_file(self, cohort: str, file_name: str, url: str) -> None:
        target = self.root / cohort
        target.mkdir(parents=True, exist_ok=True)
        urlretrieve(url, target / file_name)

    def read_header(self, cohort: str, file_name: str) -> list[str]:
        with gzip.open(self.root / cohort / file_name, "rt", encoding="utf-8", newline="") as f:
            return next(csv.reader(f))

    def copy_into_tmp(self, cur, cohort: str, file_name: str) -> None:
        with gzip.open(self.root / cohort / file_name, "rt", encoding="utf-8", newline="") as f:
            cur.copy_expert("COPY tmp_load FROM STDIN WITH (FORMAT csv, HEADER true)", f)


class S3Storage:
    def __init__(self, bucket: str, region: str, prefix: str = "raw"):
        self.bucket = bucket
        self.region = region
        self.prefix = prefix
        # picks up AWS_PROFILE from the environment / .env
        self.s3 = boto3.client("s3", region_name=region)

    def _key(self, cohort: str, file_name: str) -> str:
        return f"{self.prefix}/{cohort}/{file_name}"

    def find_existing_data(self) -> dict:
        candidates = {}
        paginator = self.s3.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=self.bucket, Prefix=f"{self.prefix}/"):
            for obj in page.get("Contents", []):
                parts = obj["Key"].split("/")  # raw/<cohort>/<file>
                if (len(parts) == 3 and parts[1].startswith("data_")
                        and parts[2].startswith(("listings", "reviews"))
                        and parts[2].endswith(".csv.gz")):
                    candidates.setdefault(parts[1], []).append(parts[2])
        return candidates

    def store_file(self, cohort: str, file_name: str, url: str) -> None:
        # stream directly from the website to S3, nothing touches the disk
        with urlopen(url) as response:
            self.s3.upload_fileobj(
                response, self.bucket, self._key(cohort, file_name),
                ExtraArgs={"ContentEncoding": "gzip", "ContentType": "text/csv"},
            )

    def read_header(self, cohort: str, file_name: str) -> list[str]:
        body = self.s3.get_object(Bucket=self.bucket, Key=self._key(cohort, file_name))["Body"]
        try:
            with gzip.GzipFile(fileobj=body) as gz:
                return next(csv.reader(io.TextIOWrapper(gz, encoding="utf-8", newline="")))
        finally:
            body.close()  # only the first chunk is downloaded

    def copy_into_tmp(self, cur, cohort: str, file_name: str) -> None:
        cur.execute(
            "SELECT aws_s3.table_import_from_s3("
            "'tmp_load', '', '(FORMAT csv, HEADER true)', "
            "aws_commons.create_s3_uri(%s, %s, %s))",
            (self.bucket, self._key(cohort, file_name), self.region),
        )


def get_storage(target: str):
    if target == "local":
        return LocalStorage(require_env("RAW_DATA_PATH"))
    if target == "cloud":
        return S3Storage(require_env("S3_BUCKET"), require_env("AWS_REGION"))
    raise ValueError(f"Unknown target: {target}")