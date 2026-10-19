# Configures OpenShift to authenticate against FreeIPA via LDAP and syncs groups.
set -euo pipefail

: "${PASSWORD:?export PASSWORD=<workshop admin password>}"
DIR="$(cd "$(dirname "$0")" && pwd)"

FREEIPA_POD=$(oc get pods -n freeipa -l app.kubernetes.io/name=freeipa-server -o jsonpath='{.items[0].metadata.name}')

# 1. Trust the FreeIPA CA
oc exec -n freeipa "$FREEIPA_POD" -- cat /etc/ipa/ca.crt > /tmp/freeipa-ca.crt
oc create configmap freeipa-ca \
  --from-file=ca.crt=/tmp/freeipa-ca.crt \
  -n openshift-config --dry-run=client -o yaml | oc apply -f -

# 2. Bind password secret
oc create secret generic freeipa-ldap-secret \
  --from-literal=bindPassword="${PASSWORD}" \
  -n openshift-config --dry-run=client -o yaml | oc apply -f -

# 3. Add the LDAP identity provider
oc patch oauth cluster --type=merge -p "$(cat "$DIR/oauth-ldap-patch.json")"

# 4. Wait for the OAuth server to roll
oc rollout status deployment/oauth-openshift -n openshift-authentication --timeout=180s

# 5. Sync FreeIPA groups into OpenShift
echo -n "${PASSWORD}" > /tmp/bind-password
oc adm groups sync --sync-config="$DIR/ldap-sync.yaml" --confirm
rm -f /tmp/bind-password

oc get groups
