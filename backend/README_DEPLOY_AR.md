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

## Main endpoints
- GET `/health`
- POST `/analyze-prescription`
- POST `/analyze-manual`
