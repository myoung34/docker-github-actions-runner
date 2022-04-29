from os import environ
import base64
import jwt
import time
import requests


def create_jwt(private_key, app_id, expiration=60):
    """
    Creates a signed JWT, valid for 60 seconds by default.
    The expiration can be extended beyond this, to a maximum of 600 seconds.

    :param expiration: int
    :return string:
    """
    now = int(time.time())
    payload = {"iat": now, "exp": now + expiration, "iss": app_id}
    encrypted = jwt.encode(payload, key=private_key, algorithm="RS256")

    if isinstance(encrypted, bytes):
        encrypted = encrypted.decode("utf-8")

    return encrypted


def get_installation(jwt_token, base_url, scope, path) -> dict:

    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Python",
    }

    response = requests.get(
        f"{base_url}/{scope}/{path}/installation",
        headers=headers,
    )

    if response.status_code != 200:
        raise Exception(f"Error getting installation: {response.status_code}")

    return response.json()


def get_access_token(jwt_token, base_url, installation_id) -> dict:

    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Python",
    }

    response = requests.post(
        f"{base_url}/app/installations/{installation_id}/access_tokens",
        headers=headers,
    )
    if response.status_code != 201:
        raise Exception(f"Error getting access token: {response.status_code}")

    return response.json()


def get_runner_token(access_token, base_url, scope, path) -> dict:

    api_version = "v3"
    headers = {
        "Authorization": f"token {access_token}",
        "Accept": f"application/vnd.github.{api_version}+json",
        "User-Agent": "Python",
        "Content-Length": "0",
    }

    response = requests.post(
        f"{base_url}/{scope}/{path}/actions/runners/registration-token",
        headers=headers,
    )
    if response.status_code != 201:
        raise Exception(f"Error getting access token: {response.status_code}")

    return response.json()


def main():
    private_key_base64 = environ.get('GITHUB_APP_PRIVATE_KEY_BASE64')
    app_id = environ.get('GITHUB_APP_ID')
    access_token = environ.get('ACCESS_TOKEN')

    if not ((private_key_base64 and app_id) or access_token):
        raise Exception('You need to set (GITHUB_APP_PRIVATE_KEY_BASE64 and GITHUB_APP_ID ) or ACCESS_TOKEN environment variables')

    runner_scope = environ.get('RUNNER_SCOPE', 'repo')
    org_name = environ.get('ORG_NAME')
    enterprise_name = environ.get('ENTERPRISE_NAME')
    repo_url = environ.get('REPO_URL')
    host = environ.get('GITHUB_HOST', 'github.com')

    if runner_scope == 'org':
        if not org_name:
            raise Exception('You need to set ORG_NAME environment variable')

        scope = 'orgs'
        path = org_name
    elif runner_scope == 'ent':
        if not enterprise_name:
            raise Exception('You need to set ENTERPRISE_NAME environment variable')

        scope = 'enterprises'
        path = enterprise_name
    else:
        if not repo_url:
            raise Exception('You need to set REPO_URL environment variable')

        scope = 'repos'
        host = repo_url.split('/')[2]
        path = "{}/{}".format(repo_url.split('/')[3], repo_url.split('/')[4])

    if host == 'github.com':
        base_url = 'https://api.github.com'
    else:
        base_url = f"https://{host}/api/v3"

    if not access_token:
        private_key = base64.b64decode(private_key_base64)

        jwt_token = create_jwt(private_key, app_id)

        installation = get_installation(jwt_token, base_url, scope, path)
        installation_access_token = get_access_token(jwt_token, base_url, installation['id'])
        access_token = installation_access_token["token"]

    runner_token = get_runner_token(access_token, base_url, scope, path)
    print(runner_token['token'])


if __name__ == '__main__':
    main()
