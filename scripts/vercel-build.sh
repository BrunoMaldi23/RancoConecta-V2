#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.44.0"
FLUTTER_CACHE="${FLUTTER_CACHE_DIR:-${HOME}/.cache/ranco-conecta/flutter-${FLUTTER_VERSION}}"

install_flutter() {
  local archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  local archive_path="${TMPDIR:-/tmp}/flutter-${FLUTTER_VERSION}-linux.tar.xz"
  mkdir -p "$(dirname "$FLUTTER_CACHE")"
  if [[ ! -x "${FLUTTER_CACHE}/bin/flutter" ]]; then
    echo "Installing Flutter ${FLUTTER_VERSION} into ${FLUTTER_CACHE}"
    curl --fail --location --retry 3 "$archive_url" --output "$archive_path"
    mkdir -p "$FLUTTER_CACHE"
    tar -xJf "$archive_path" --strip-components=1 -C "$FLUTTER_CACHE"
    rm -f "$archive_path"
  fi
  export PATH="${FLUTTER_CACHE}/bin:${PATH}"
  git config --global --add safe.directory "$FLUTTER_CACHE"
}

if [[ "$(uname -s)" == "Linux" ]]; then
  install_flutter
elif ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter ${FLUTTER_VERSION} is required for local builds." >&2
  exit 1
fi

ACTUAL_VERSION="$(flutter --version --machine | sed -n 's/.*"frameworkVersion":[[:space:]]*"\([^"]*\)".*/\1/p')"
if [[ "$ACTUAL_VERSION" != "$FLUTTER_VERSION" ]]; then
  echo "Expected Flutter ${FLUTTER_VERSION}; found ${ACTUAL_VERSION:-unknown}." >&2
  exit 1
fi

APP_ENVIRONMENT="${APP_ENVIRONMENT:-production}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-}}"
missing_variables=()
if [[ "$APP_ENVIRONMENT" != "production" ]]; then missing_variables+=(APP_ENVIRONMENT=production); fi
if [[ -z "$SUPABASE_URL" ]]; then missing_variables+=(SUPABASE_URL); fi
if [[ -z "$SUPABASE_PUBLISHABLE_KEY" ]]; then missing_variables+=(SUPABASE_PUBLISHABLE_KEY/SUPABASE_ANON_KEY); fi
if (( ${#missing_variables[@]} > 0 )); then
  echo "Missing or invalid public frontend build variables: ${missing_variables[*]}" >&2
  echo "Vercel environment: ${VERCEL_ENV:-local/unknown}. Configure these as project build environment variables." >&2
  exit 1
fi

flutter pub get
flutter build web --release \
  --dart-define="APP_ENVIRONMENT=${APP_ENVIRONMENT}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define="PUBLIC_SITE_URL=${PUBLIC_SITE_URL:-https://www.rancoconecta.cl}" \
  --dart-define="CHAT_ENABLED=${CHAT_ENABLED:-false}" \
  --dart-define="PAYMENTS_ENABLED=${PAYMENTS_ENABLED:-false}" \
  --dart-define="QUOTES_ENABLED=${QUOTES_ENABLED:-false}" \
  --dart-define="LODGING_ENABLED=${LODGING_ENABLED:-true}"

for required_file in index.html main.dart.js flutter_bootstrap.js; do
  if [[ ! -f "build/web/${required_file}" ]]; then
    echo "Flutter build is missing build/web/${required_file}." >&2
    exit 1
  fi
done
if [[ ! -d build/web/assets ]]; then
  echo "Flutter build is missing build/web/assets." >&2
  exit 1
fi

echo "Flutter ${FLUTTER_VERSION} production web build is ready in build/web."
