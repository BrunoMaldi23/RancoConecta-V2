# Fase 3.34 — GitHub to Vercel automatic Flutter build

## Deployment model

The connected Vercel project now builds directly from Git source. A push to
the production branch (`main`) triggers Vercel. Its configured build command is
`bash scripts/vercel-build.sh`, its install command is skipped, and its output
directory is `build/web`. Flutter `3.44.0` is pinned in the script. On Linux,
the script downloads that exact stable SDK archive when it is not already
available, runs `flutter pub get`, builds release web with the public Vercel
environment variables, and checks the expected Flutter output files.

The public frontend build requires `APP_ENVIRONMENT=production`,
`SUPABASE_URL`, and `SUPABASE_PUBLISHABLE_KEY` (or the public
`SUPABASE_ANON_KEY`). No service role key is read or passed to the build.
Flutter's SPA rewrite to `/index.html` remains enabled.

Normal deployment is:

```sh
git add .
git commit -m "your message"
git push
```

No PowerShell script, manual Vercel CLI deployment, local fingerprint, or
prebuilt `vercel_output` is needed for normal production deploys.

## Validation

- `flutter analyze`: PASS.
- `flutter test`: PASS, 634 tests.
- `scripts/check_text_encoding.ps1`: PASS.
- `git diff --check`: PASS.
- Local `scripts/vercel-build.sh`: PASS with Flutter 3.44.0; verified
  `build/web/index.html`, `main.dart.js`, `flutter_bootstrap.js`, and `assets/`.
- Vercel preview `Eh4jiBMhkBNeejjJv4qqV4R5x6uk`: READY. Remote logs confirm
  the Linux script installed Flutter 3.44.0, built release web, and published
  `build/web`. The CLI preview required explicit `--build-env` values; the
  first GitHub-triggered deployment cloned `main` automatically, but failed
  because the project's existing public frontend values were stored as
  `Secret` and were absent from the build process. Re-saved the same local
  public values to Vercel Production and Preview as Config variables; a follow-
  up GitHub-triggered deployment is needed to verify injection.
- Preview browser smoke was blocked by Vercel's deployment protection login;
  production domain smoke remains pending the GitHub-triggered deployment.

## Legacy handling

`vercel_output/` is no longer a Vercel input and is excluded from future Git
and Vercel source bundles. The tracked generated files are removed from Git
after validating `build/web`. `scripts/verify-vercel-output.mjs` remains only
as a historical local utility and is not included in Vercel's uploaded source
or invoked by the build.
