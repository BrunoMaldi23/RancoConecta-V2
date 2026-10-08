"""Local Supabase Data API check; requires `supabase start` and local migrations."""

import base64
import hashlib
import hmac
import json
import subprocess
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


USER_ID = "00000000-0000-4000-8000-000000032199"
DB_CONTAINER = "supabase_db_ranco_conecta_2"


def sql(statement: str) -> None:
    subprocess.run(
        ["docker", "exec", DB_CONTAINER, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-q", "-c", statement],
        check=True,
        capture_output=True,
        text=True,
    )


def token(secret: str) -> str:
    def encode(value: dict) -> str:
        return base64.urlsafe_b64encode(
            json.dumps(value, separators=(",", ":")).encode()
        ).decode().rstrip("=")

    header = encode({"alg": "HS256", "typ": "JWT"})
    payload = encode({
        "sub": USER_ID,
        "role": "authenticated",
        "aud": "authenticated",
        "iss": "supabase-demo",
        "exp": int(time.time()) + 3600,
        "is_anonymous": False,
    })
    value = f"{header}.{payload}"
    signature = base64.urlsafe_b64encode(
        hmac.new(secret.encode(), value.encode(), hashlib.sha256).digest()
    ).decode().rstrip("=")
    return f"{value}.{signature}"


def request_status(url: str, key: str, jwt: str) -> tuple[int, str]:
    request = Request(
        f"{url}/rest/v1/profiles?select=id",
        headers={"apikey": key, "Authorization": f"Bearer {jwt}"},
    )
    try:
        with urlopen(request, timeout=10) as response:
            return response.status, response.read().decode()
    except HTTPError as error:
        return error.code, error.read().decode()


def rpc_status(url: str, key: str, jwt: str) -> tuple[int, str]:
    request = Request(
        f"{url}/rest/v1/rpc/notification_list",
        data=b"{}",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {jwt}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=10) as response:
            return response.status, response.read().decode()
    except HTTPError as error:
        return error.code, error.read().decode()


def main() -> None:
    result = subprocess.run(
        [".\\node_modules\\.bin\\supabase.cmd", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    config = json.loads(result.stdout)
    jwt = token(config["JWT_SECRET"])
    url = config["API_URL"]
    key = config["ANON_KEY"]
    sql(f"insert into auth.users (id, email, is_anonymous) values ('{USER_ID}', 'phase321-api@example.test', false) on conflict (id) do nothing")
    try:
        sql(f"update public.profiles set account_status = 'active' where id = '{USER_ID}'")
        active_status, active_body = request_status(url, key, jwt)
        if active_status != 200:
            raise AssertionError(f"active account returned HTTP {active_status}: {active_body[:300]}")
        sql(f"update public.profiles set account_status = 'suspended' where id = '{USER_ID}'")
        suspended_status, body = request_status(url, key, jwt)
        if suspended_status not in (401, 403) or "ACCOUNT_SUSPENDED" not in body:
            raise AssertionError(f"suspended account returned HTTP {suspended_status}")
        rpc_code, rpc_body = rpc_status(url, key, jwt)
        if rpc_code not in (401, 403) or "ACCOUNT_SUSPENDED" not in rpc_body:
            raise AssertionError(f"suspended RPC returned HTTP {rpc_code}")
        print("phase 3.21 Data API gate passed")
    finally:
        sql(f"delete from auth.users where id = '{USER_ID}'")


if __name__ == "__main__":
    main()
