"""AWS Lambda: latest FDA label lookup for the MedInfo Agent.

Called by the Salesforce Apex action CheckFdaLabel through API Gateway:
    GET /label?drug=metformin

Queries the public openFDA drug label API and returns the label's effective
date and boxed warning. Uses only the Python standard library, so it deploys
without any packaging step.
"""

import json
import urllib.error
import urllib.parse
import urllib.request

FDA_URL = "https://api.fda.gov/drug/label.json"
MAX_WARNING_CHARS = 500
TIMEOUT_SECONDS = 5


def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    drug = (params.get("drug") or "").strip()
    if not drug:
        return respond(400, {"error": "Pass a drug name, for example ?drug=metformin"})
    if len(drug) > 100 or not all(ch.isalnum() or ch in " -" for ch in drug):
        return respond(400, {"error": "Drug name may contain only letters, numbers, spaces and hyphens"})

    try:
        label = fetch_label(drug)
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return respond(404, {"drug": drug, "error": "No FDA label found"})
        return respond(502, {"drug": drug, "error": "openFDA returned an error"})
    except (urllib.error.URLError, TimeoutError, ValueError):
        return respond(502, {"drug": drug, "error": "openFDA is unavailable"})

    if label is None:
        return respond(404, {"drug": drug, "error": "No FDA label found"})

    boxed = (label.get("boxed_warning") or [""])[0].strip()
    return respond(200, {
        "drug": drug,
        "labelEffectiveDate": label.get("effective_time", ""),
        "boxedWarning": boxed[:MAX_WARNING_CHARS] if boxed else "None",
    })


def fetch_label(drug):
    """Return the most relevant openFDA label for a generic name, or None."""
    query = urllib.parse.quote(f'openfda.generic_name:"{drug}"')
    url = f"{FDA_URL}?search={query}&limit=1"
    with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
        results = json.load(resp).get("results") or []
    return results[0] if results else None


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
