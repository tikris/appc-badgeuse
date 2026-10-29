"""Déploie le service de signature sur Scaleway Serverless Functions (région Paris), sans dépendance.

    SCW_SECRET_KEY=… SCW_PROJECT_ID=… python3 server/deploy.py build/signature.zip

Crée l'espace de noms « badge-creche » et la fonction « signature » s'ils n'existent pas, envoie
l'archive, déploie et affiche l'adresse du service. Ne touche jamais aux variables secrètes
(certificat et clé), saisies une fois dans la console Scaleway.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.scaleway.com/functions/v1beta1/regions/fr-par"
NAMESPACE = "badge-creche"
FUNCTION = "signature"
FUNCTION_SETTINGS = {
    "runtime": "python313",
    "handler": "handler.handle",
    "privacy": "public",
    "http_option": "redirected",
    "min_scale": 0,
    "max_scale": 2,
    "memory_limit": 256,
    "timeout": "15s",
    "environment_variables": {"APP_ATTEST_ENVIRONMENT": "production"},
}


def call(method, path, body=None, query=None):
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={
        "X-Auth-Token": os.environ["SCW_SECRET_KEY"], "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        hint = ""
        if error.code in (401, 403):
            hint = (" (clé API sans ce droit : la politique IAM de l'application doit donner FunctionsFullAccess"
                    " sur le projet dont l'ID est dans SCW_PROJECT_ID ; une politique modifiée met une à deux"
                    " minutes à s'appliquer)")
        sys.exit(f"::error::Scaleway {method} {path} : {error.code} "
                 f"{error.read().decode(errors='replace')[:500]}{hint}")


def wait(path, key, ready=("ready",), failed=("error",)):
    for _ in range(90):
        resource = call("GET", path)
        status = resource.get("status")
        if status in ready:
            return resource
        if status in failed:
            sys.exit(f"::error::{key} en erreur : {resource.get('error_message') or status}")
        time.sleep(10)
    sys.exit(f"::error::{key} toujours en cours après 15 minutes")


def diagnose(project):
    """Ce que la clé voit, sans secret : début des ID de projet seulement (8 caractères)."""
    looks_like_id = len(project) == 36 and project.count("-") == 4
    print(f"SCW_PROJECT_ID : {project[:8]}… ({'format UUID' if looks_like_id else 'format inattendu : UUID attendu'})")
    visible = call("GET", "/namespaces", query={"page_size": 100})["namespaces"]
    if not visible:
        print("La clé ne voit aucun espace de noms Serverless Functions, dans aucun projet.")
    for namespace in visible:
        print(f"Visible : espace « {namespace['name']} » (projet {namespace['project_id'][:8]}…, "
              f"{namespace.get('region', '?')}, {namespace.get('status')})")
    elsewhere = [n for n in visible if n["name"] == NAMESPACE and n["project_id"] != project]
    if elsewhere:
        sys.exit(f"::error::L'espace « {NAMESPACE} » existe dans le projet {elsewhere[0]['project_id'][:8]}…, "
                 f"pas dans celui de SCW_PROJECT_ID ({project[:8]}…) : corrigez le secret SCW_PROJECT_ID.")


def main(archive):
    project = os.environ["SCW_PROJECT_ID"].strip()
    namespaces = call("GET", "/namespaces", query={"project_id": project, "name": NAMESPACE})["namespaces"]
    namespace = next((n for n in namespaces if n["name"] == NAMESPACE), None)
    if namespace is None:
        diagnose(project)
        namespace = call("POST", "/namespaces", {"name": NAMESPACE, "project_id": project,
                                                 "description": "Badge Crèche (APPC) : signature des badges Wallet"})
    namespace = wait(f"/namespaces/{namespace['id']}", "Espace de noms")

    functions = call("GET", "/functions", query={"namespace_id": namespace["id"], "name": FUNCTION})["functions"]
    function = next((f for f in functions if f["name"] == FUNCTION), None)
    if function is None:
        function = call("POST", "/functions", {"name": FUNCTION, "namespace_id": namespace["id"],
                                               **FUNCTION_SETTINGS})
        print("Fonction créée : ajoutez PASS_CERTIFICATE_PEM et PASS_PRIVATE_KEY_PEM dans ses variables secrètes.")

    size = os.path.getsize(archive)
    upload = call("GET", f"/functions/{function['id']}/upload-url", query={"content_length": size})
    with open(archive, "rb") as file:
        request = urllib.request.Request(upload["url"], data=file.read(), method="PUT", headers={
            "Content-Type": "application/octet-stream", "Content-Length": str(size)})
        urllib.request.urlopen(request, timeout=120).close()
    call("POST", f"/functions/{function['id']}/deploy", {})
    function = wait(f"/functions/{function['id']}", "Fonction")
    print(f"Service de signature : https://{function['domain_name']}")


if __name__ == "__main__":
    main(sys.argv[1])
