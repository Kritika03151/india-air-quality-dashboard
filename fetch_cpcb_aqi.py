from __future__ import annotations

import os
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import tabula

DATA_DIR = Path(__file__).resolve().parent / "data"
BASE_URL = "https://cpcb.nic.in/upload/Downloads/AQI_Bulletin_{date}.pdf"


def fetch_one(day: date) -> bool:
    ymd = day.strftime("%Y%m%d")
    url = BASE_URL.format(date=ymd)
    output = DATA_DIR / f"{day.isoformat()}.csv"
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Fetching {day}: {url}")
    try:
        tabula.convert_into(url, str(output), lattice=True, output_format="csv", pages="all")
    except Exception as exc:
        print(f"SKIP {day}: {exc}")
        output.unlink(missing_ok=True)
        return False

    try:
        raw = pd.read_csv(output, dtype=str)
        if raw.shape[1] < 5:
            raise ValueError(f"Unexpected table with {raw.shape[1]} columns")
        first_col = str(raw.columns[0]).strip().lower().replace(".", "")
        if first_col in {"sno", "serialno", "serialnumber"} or first_col.startswith("sno"):
            raw = raw.iloc[:, 1:]
        if raw.shape[1] < 5:
            raise ValueError(f"Unexpected table after S.No removal: {raw.shape[1]} columns")
        raw = raw.iloc[:, :5].copy()
        raw.columns = ["city", "level", "index", "pollutant", "stations"]

        raw["city"] = raw["city"].astype(str).str.replace(r"\r|_", " ", regex=True).str.strip().str.title()
        raw["index"] = pd.to_numeric(raw["index"], errors="coerce")
        raw = raw.dropna(subset=["city", "index"])

        def clean_pollutant(value: object) -> str:
            text = "" if pd.isna(value) else str(value)
            parts = []
            if "3" in text or "Z" in text:
                parts.append("O3")
            if "CO" in text:
                parts.append("CO")
            if "NO" in text:
                parts.append("NO2")
            if "SO" in text:
                parts.append("SO2")
            if "10" in text:
                parts.append("PM10")
            if "2.5" in text:
                parts.append("PM2.5")
            return ", ".join(dict.fromkeys(parts))

        raw["pollutant"] = raw["pollutant"].map(clean_pollutant)
        raw["stations"] = raw["stations"].astype(str).str.replace(" #", "", regex=False).str.split("/").str[0]
        raw["date"] = day.isoformat()
        raw = raw[["city", "level", "index", "pollutant", "stations", "date"]]
        raw.to_csv(output, index=False)
        print(f"OK {day}: {len(raw)} rows")
        return True
    except Exception as exc:
        print(f"CLEANING FAILED {day}: {exc}")
        output.unlink(missing_ok=True)
        return False


def main() -> None:
    start = os.getenv("START_DATE", "").strip()
    end = os.getenv("END_DATE", "").strip()
    if start:
        start_day = date.fromisoformat(start)
        end_day = date.fromisoformat(end) if end else start_day
    else:
        start_day = date.today()
        end_day = start_day
    if end_day < start_day:
        raise SystemExit("END_DATE must be on or after START_DATE")

    day = start_day
    while day <= end_day:
        fetch_one(day)
        day += timedelta(days=1)


if __name__ == "__main__":
    main()
