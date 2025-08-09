# Cloud Text Analyzer

A simple text analysis API built with Flask and deployed on Google Cloud Platform.

## What it does

- Analyzes text input (word count, character count)
- Runs on Cloud Run for scalability
- Uses Terraform for infrastructure management
- Automated deployment with GitHub Actions

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│   GitHub    │───▶│ GitHub       │───▶│ Artifact        │
│ Repository  │    │ Actions      │    │ Registry        │
└─────────────┘    └──────────────┘    └─────────────────┘
                           │                     │
                           ▼                     │
                  ┌──────────────┐               │
                  │  Terraform   │               │
                  │ (Deploy IaC) │               │
                  └──────────────┘               │
                           │                     │
                           ▼                     ▼
                  ┌─────────────────────────────────┐
                  │         Cloud Run               │
                  │  ┌─────────────────────────┐   │
                  │  │   Flask Application     │   │
                  │  │  (Internal Access Only) │   │
                  │  └─────────────────────────┘   │
                  └─────────────────────────────────┘
```

## Local Development

```bash
# Install dependencies
cd app
pip install -r requirements.txt

# Run locally
python main.py

# Test endpoints
curl http://localhost:8080/health
curl -X POST http://localhost:8080/analyze -H "Content-Type: application/json" -d '{"text": "test"}'
```

## Deployment Setup

1. **Create GCP Project**
   ```bash
   gcloud projects create YOUR_PROJECT_ID
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Create Service Account**
   ```bash
   gcloud iam service-accounts create github-actions \
       --display-name="GitHub Actions"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
       --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/run.admin"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
       --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/artifactregistry.admin"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
       --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/iam.serviceAccountUser"
   
   gcloud iam service-accounts keys create key.json \
       --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com
   ```

3. **GitHub Secrets**
   - `GCP_PROJECT_ID`: Your project ID
   - `GCP_SA_KEY`: Contents of key.json

4. **Deploy**
   ```bash
   git push origin main
   ```

## API Usage

**POST /analyze**
```json
{
  "text": "Hello world"
}
```

Response:
```json
{
  "original_text": "Hello world",
  "word_count": 2,
  "character_count": 11
}
```

## Security

- Cloud Run service requires authentication
- Non-root container user
- Least privilege service account
- No public internet access