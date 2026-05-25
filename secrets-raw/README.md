# Raw secret input files

This directory is for local plaintext inputs used by `scripts/generate-sealed-secrets.sh`.

Real `.env` files are ignored by git:

```text
secrets-raw/dev.env
secrets-raw/stage.env
secrets-raw/ephemeral-shared.env
```

Only `.env.example` files are committed. Copy an example file, fill in real values locally, generate SealedSecrets, then commit only files under `sealed-secrets/`.

## Create local input files

```bash
cp secrets-raw/dev.env.example secrets-raw/dev.env
cp secrets-raw/stage.env.example secrets-raw/stage.env
cp secrets-raw/ephemeral-shared.env.example secrets-raw/ephemeral-shared.env
```

Never paste real passwords into this README or any `.env.example` file.
