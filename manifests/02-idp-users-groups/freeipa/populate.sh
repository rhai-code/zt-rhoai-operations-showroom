# Populates FreeIPA with the data-stewardship personas and groups:
#   lending LOB:   own-alice (owner), ste-carol (steward), sci-eve (scientist)
#   insurance LOB: own-bob (owner),  ste-dave (steward),  sci-frank (scientist)
#   platform:      mle-gina (ML engineer), ops-admin (platform admin)
# One-shot: fails if the users/groups already exist.
set -euo pipefail

: "${PASSWORD:?export PASSWORD=<workshop admin password>}"

FREEIPA_POD=$(oc get pods -n freeipa -l app.kubernetes.io/name=freeipa-server -o jsonpath='{.items[0].metadata.name}')

oc exec -n freeipa "$FREEIPA_POD" -- bash -s <<REMOTE
set -e
echo '${PASSWORD}' | kinit admin

# Persona groups -- one set per line of business (LOB)
ipa group-add lending-data-owners       --desc="Data Owners, Lending LOB"
ipa group-add lending-data-stewards     --desc="Data Stewards, Lending LOB"
ipa group-add lending-data-scientists   --desc="Data Scientists, Lending LOB"
ipa group-add insurance-data-owners     --desc="Data Owners, Insurance LOB"
ipa group-add insurance-data-stewards   --desc="Data Stewards, Insurance LOB"
ipa group-add insurance-data-scientists --desc="Data Scientists, Insurance LOB"
ipa group-add ml-engineers              --desc="ML Engineers / Platform Ops"
ipa group-add rhods-admins              --desc="RHOAI Administrators"
ipa group-add rhods-users               --desc="RHOAI Users"

# Users -- <name> <first name> <groups...>
add_user() {
  local u="\$1"; local first="\$2"; shift 2
  printf '%s\n%s\n' '${PASSWORD}' '${PASSWORD}' | ipa user-add "\$u" --first="\$first" --last=Workshop --password
  local g
  for g in "\$@"; do ipa group-add-member "\$g" --users="\$u"; done
}

# Lending line of business
add_user own-alice Alice lending-data-owners rhods-users
add_user ste-carol Carol lending-data-stewards rhods-users
add_user sci-eve Eve lending-data-scientists rhods-users

# Insurance line of business
add_user own-bob Bob insurance-data-owners rhods-users
add_user ste-dave Dave insurance-data-stewards rhods-users
add_user sci-frank Frank insurance-data-scientists rhods-users

# Platform
add_user mle-gina Gina ml-engineers rhods-users
add_user ops-admin Ops rhods-admins rhods-users

echo "Users and groups created successfully"
REMOTE

echo "Next: sync these groups into OpenShift via ../openshift-ldap/setup.sh"
