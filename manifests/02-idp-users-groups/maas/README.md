# MaaS Permissions -- Performance Tiers Bound to Groups

Seeds the MaaS governance for the **Lending line-of-business model**: a modelcar
(qwen2.5-0.5b) published through MaaS with two subscription tiers bound to the
data-stewardship groups from Module 2.

NOTE: the model itself (`llminferenceservice.yaml` + `maasmodelref.yaml`) is
GitOps-managed in the automation repository (`cluster/maas-model/`, Application
`maas-model`) — the copies in this directory are reference only. The
subscriptions and auth policies are applied by hand in Module 2 Exercise 6, step 2.

## Tier design

| Tier        | Subscription               | Bound groups                                     | Token limits  | Priority |
|-------------|----------------------------|--------------------------------------------------|---------------|----------|
| Performance | `lending-performance-tier` | lending-data-owners, lending-data-stewards       | 100000 / 1m   | 1        |
| Standard    | `lending-standard-tier`    | lending-data-scientists                          | 10000 / 1m    | 0        |

Both attribute usage to `costCenter: lending` — metering per line of business.

## Prerequisites (platform-level)

- MaaS enabled: DSC `modelsAsAService: Managed`, dashboard MaaS flags
- `maas-default-gateway` in `openshift-ingress` (Red Hat Connectivity Link / Kuadrant)
- PostgreSQL for MaaS, Authorino auth wired to the gateway
- The persona groups synced into OpenShift (`../freeipa/populate.sh` + `../openshift-ldap/setup.sh`)

## Run order

```bash
# 1. Deploy the model (pre-setup; first pull takes several minutes)
oc apply -f llminferenceservice.yaml
oc wait --for=condition=Ready llminferenceservice/qwen25-05b-maas -n rhoai-lending --timeout=15m

# 2. Publish the model and create the tiers
oc apply -f maasmodelref.yaml
oc apply -f subscription-performance.yaml
oc apply -f subscription-standard.yaml
oc apply -f authpolicy-performance.yaml
oc apply -f authpolicy-standard.yaml

# 3. Verify
oc get maasmodelref -n rhoai-lending
oc get maassubscription,maasauthpolicy -n models-as-a-service
```

Each manifest pins its own namespace — no `-n` flag needed.

## Minting persona API keys

API keys bind to a subscription (the tier). Mint as the persona:

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
HOST="https://maas.${CLUSTER_DOMAIN}"

# As the data scientist (standard tier)
curl -sSk -X POST "${HOST}/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -H "Content-Type: application/json" \
  -d '{"name":"sci-eve-standard","expiresIn":"1h","subscription":"lending-standard-tier"}'

# As the data owner (performance tier)
curl -sSk -X POST "${HOST}/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -H "Content-Type: application/json" \
  -d '{"name":"own-alice-performance","expiresIn":"1h","subscription":"lending-performance-tier"}'
```

Calls use body-based routing with the full catalog id
(`publishers/rhoai-lending/models/qwen25-05b`) against `${HOST}/v1/chat/completions`.

## Gotchas

- Subscriptions and auth policies MUST live in `models-as-a-service` — the only
  namespace `maas-api` reads them from; anywhere else they are silently ignored.
- `MaaSModelRef` must live in the same namespace as the `LLMInferenceService`.
- `tokenMetadata` placeholders are required: RHCL evaluates CEL label expressions
  strictly, and without them Limitador never records `authorized_hits`.
- Auth policy `subjects.groups` must match the subscription's `owner.groups`, or
  every call gets 403.
