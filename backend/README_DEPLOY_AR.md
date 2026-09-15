# Medicine Search API - Deployment Notes

## Local run

```bash
pip install -r requirements.txt
python app.py
```

## Docker local run

```bash
docker build -t medicine-search-api .
docker run -p 8080:8080 medicine-search-api
```

## Required files
Place these files in `data/`:
- medItems1.csv
- medItems2.csv

## CORS configuration

Set `CORS_ALLOWED_ORIGINS` to the exact web origins that are allowed to call the API.
Separate multiple origins with commas and do not use `*`.

Example for Render:

```text
CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
```

If the variable is not set, only these local development origins are allowed:

```text
http://localhost:3000,http://localhost:5173,http://localhost:8080
```

## Main endpoints
- GET `/health`
- POST `/analyze-prescription`
- POST `/analyze-manual`
