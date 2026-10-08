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
  because its existing environment values were absent from the build process.
  The public frontend values were re-saved from `.env.production.local` to
  Vercel Production and Preview as Config variables. A follow-up GitHub push
  triggered a successful build with those variables.
- GitHub push to `main` at commit `9af6013` automatically created production
  deployment `dpl_71nTwxfkbVJPSrdFcZV9xJiW69Hy`: **READY**. Logs show Vercel
  cloned GitHub branch `main`, installed Flutter 3.44.0, ran `flutter pub get`,
  compiled Flutter web, and published `build/web`. Vercel assigned both
  `rancoconecta.cl` and `www.rancoconecta.cl` to the deployment.
- Domain smoke: both HTTPS domains returned HTTP 200; `rancoconecta.cl`
  redirects to canonical `www.rancoconecta.cl`.
- Browser smoke on production: Home, Explore/search, Categories, business
  detail, anonymous request, table reservation, Contact, sign-in, Provider
  Join, Terms, and Privacy routes loaded. Home and Explore rendered content and
  public listings. Observed Supabase REST/Storage requests returned 200; no
  console errors or warnings were observed. No forms were submitted.

## Legacy handling

`vercel_output/` is no longer a Vercel input and is excluded from future Git
and Vercel source bundles. The tracked generated files are removed from Git
after validating `build/web`. `scripts/verify-vercel-output.mjs` remains only
as a historical local utility and is not included in Vercel's uploaded source
or invoked by the build.

The remaining build inputs are `lib/`, `web/`, `assets/`, `pubspec.yaml`,
`pubspec.lock`, `vercel.json`, and `scripts/vercel-build.sh`. `.vercelignore`
excludes `supabase/`, tests, docs, local build outputs, private environment
files, backups, and all scripts other than the build entrypoint.
