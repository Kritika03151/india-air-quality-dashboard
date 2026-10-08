# Deployment and September 2026 update

This project is a Streamlit dashboard. The static archive in `combined_air_quality.txt` ends on 2025-05-24. The dashboard has been updated to load that archive plus every valid daily CPCB bulletin CSV stored in `data/`.

## Backfill through 2026-09-30

1. Push this project to a GitHub repository.
2. Open **Actions** → **Fetch CPCB AQI Bulletin**.
3. Click **Run workflow**.
4. Enter:
   - `start_date`: `2025-05-25`
   - `end_date`: `2026-09-30`
5. Run the workflow and wait for it to finish.
6. The generated `data/YYYY-MM-DD.csv` files will be committed to the repository.

The app will then automatically include the backfilled daily data, without changing the original historical archive.

## Daily updates after the backfill

The scheduled workflow runs daily at 17:45 IST (12:15 UTC) and fetches the current CPCB bulletin when it is available.

## Local run

```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
streamlit run app.py
```

## Streamlit Community Cloud

Use `app.py` as the entrypoint and `requirements.txt` as the dependency file. The repository root should contain both files.
