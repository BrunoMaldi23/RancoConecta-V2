"""Read-only check that existing admin RPC signatures resolve remotely."""

import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


env = {}
for line in Path('.env.production.local').read_text(encoding='utf-8').splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        key, value = line.split('=', 1)
        env[key.strip()] = value.strip().strip('"').strip("'")

url = env['SUPABASE_URL'].rstrip('/')
key = env.get('SUPABASE_PUBLISHABLE_KEY') or env['SUPABASE_ANON_KEY']
calls = {
    'admin_search_business_reviews': {
        'p_status': None, 'p_business_type': None,
        'p_search': None, 'p_limit': 10, 'p_offset': 0,
    },
    'admin_list_business_reviews': {
        'p_status': 'pending_review', 'p_business_type': None,
        'p_search': None, 'p_limit': 10, 'p_offset': 0,
    },
    'admin_search_users': {
        'p_page': 1, 'p_page_size': 10,
        'p_search': None, 'p_role': None,
    },
    'admin_list_categories': {},
}

failed = []
for name, params in calls.items():
    request = Request(
        f'{url}/rest/v1/rpc/{name}',
        data=json.dumps(params).encode(),
        headers={
            'apikey': key,
            'Content-Type': 'application/json',
        },
    )
    try:
        with urlopen(request, timeout=15) as response:
            code = response.status
            body = response.read().decode()
    except HTTPError as error:
        code = error.code
        body = error.read().decode()
    try:
        error_code = json.loads(body).get('code')
    except (ValueError, AttributeError):
        error_code = None
    exists = error_code != 'PGRST202' and code in (200, 400, 401, 403)
    print(f'{name}: {"signature found" if exists else "unverified"} (HTTP {code}, code {error_code})')
    if not exists:
        failed.append(name)

if failed:
    raise SystemExit(1)
