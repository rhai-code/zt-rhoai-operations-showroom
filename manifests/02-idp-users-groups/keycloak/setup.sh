# Adds Keycloak as an OIDC identity provider on OpenShift.
# One-shot: the "openshift" client in Keycloak fails if it already exists.
set -euo pipefail

: "${PASSWORD:?export PASSWORD=<workshop admin password>}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps.cluster.example.com}"
OAUTH_INGRESS_DOMAIN="${OAUTH_INGRESS_DOMAIN:-oauth-openshift.apps.cluster.example.com}"
DIR="$(cd "$(dirname "$0")" && pwd)"

KEYCLOAK_POD=$(oc get pods -n keycloak -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

# 1. Create an OpenShift client in Keycloak
oc exec -n keycloak "$KEYCLOAK_POD" -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password "${PASSWORD}"

oc exec -n keycloak "$KEYCLOAK_POD" -- /opt/keycloak/bin/kcadm.sh create clients \
  -r master \
  -s clientId=openshift \
  -s enabled=true \
  -s "redirectUris=[\"https://${OAUTH_INGRESS_DOMAIN}/oauth2callback/keycloak-oidc\"]" \
  -s clientAuthenticatorType=client-secret \
  -s secret=openshift-client-secret \
  -s directAccessGrantsEnabled=true

# 2. OIDC client secret in OpenShift
oc create secret generic keycloak-oidc-secret \
  --from-literal=clientSecret=openshift-client-secret \
  -n openshift-config --dry-run=client -o yaml | oc apply -f -

# 3. Add the OIDC identity provider
sed "s|__KEYCLOAK_URL__|${KEYCLOAK_URL}|g" "$DIR/oauth-oidc-patch.json" > /tmp/oauth-oidc-patch.json
oc patch oauth cluster --type=json -p "$(cat /tmp/oauth-oidc-patch.json)"

# 4. Wait for the OAuth server to roll
oc rollout status deployment/oauth-openshift -n openshift-authentication --timeout=180s

oc get oauth cluster -o jsonpath='{range .spec.identityProviders[*]}{.name}{"\n"}{end}'
