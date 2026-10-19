# Deploys FreeIPA as the workshop LDAP directory.
set -euo pipefail

: "${PASSWORD:?export PASSWORD=<workshop admin password>}"
INGRESS_DOMAIN="${INGRESS_DOMAIN:-apps.cluster.example.com}"

helm repo add freeipa https://freeipa.github.io/helm-charts
helm repo update

oc get namespace freeipa 2>/dev/null || oc new-project freeipa

cat > /tmp/freeipa-values.yaml <<EOF
replicas: 1
image:
  repository: quay.io/freeipa/freeipa-server
  tag: fedora-latest
server:
  realm: EXAMPLE.COM
  domain: example.com
  adminPassword: "${PASSWORD}"
  dsPassword: "${PASSWORD}"
persistence:
  enabled: true
  size: 5Gi
service:
  type: ClusterIP
route:
  enabled: true
  host: ipa.${INGRESS_DOMAIN}
securityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 0
EOF

helm upgrade --install freeipa freeipa/freeipa-server \
  -n freeipa \
  -f /tmp/freeipa-values.yaml \
  --timeout 10m \
  --wait

echo "FreeIPA deployed. Route: $(oc get route -n freeipa freeipa -o jsonpath='{.spec.host}')"
