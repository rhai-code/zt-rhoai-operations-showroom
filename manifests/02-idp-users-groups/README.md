# IDP, Users & Groups -- Environment Setup

Provisions the identity plumbing for **Module 2: Data Stewardship, Users & Access Control**.
This setup moves to the platform automation repository over time; the manifests stay here
until then.

## What it provisions

1. **FreeIPA** in-cluster as the LDAP directory (`freeipa/`)
2. **OpenShift LDAP identity provider** against FreeIPA, with groups synced (`openshift-ldap/`)
3. **Keycloak** as an OIDC identity provider (`keycloak/`)
4. **Persona users and groups** modeling a data-stewardship organization (`freeipa/populate.sh`)
5. **MaaS governance** for the Lending model -- a modelcar published with performance and
   standard subscription tiers bound to the persona groups (`maas/`)

## RHOAI authorization model (applied in Module 2 exercises)

The platform authorization model applied during the module, also kept here as manifests:

```bash
oc apply -f rhoai-auth/auth-config.yaml     # RHOAI Auth CR (dashboard access)
oc apply -f rhoai-auth/workbench-roles.yaml # custom workbench ClusterRoles
```

## Run order

```bash
export PASSWORD=<workshop admin password>

./freeipa/install.sh      # deploy FreeIPA (5-8 min to become healthy)
./freeipa/populate.sh     # create persona users and groups in FreeIPA
./openshift-ldap/setup.sh # LDAP IdP on OpenShift + group sync
./keycloak/setup.sh       # OIDC IdP on OpenShift (optional second provider)
```

## Provisioned personas

| User      | Persona        | Group(s)                                    | Line of Business |
|-----------|----------------|---------------------------------------------|------------------|
| own-alice | Data Owner     | lending-data-owners, rhods-users            | Lending          |
| ste-carol | Data Steward   | lending-data-stewards, rhods-users          | Lending          |
| sci-eve   | Data Scientist | lending-data-scientists, rhods-users        | Lending          |
| own-bob   | Data Owner     | insurance-data-owners, rhods-users          | Insurance        |
| ste-dave  | Data Steward   | insurance-data-stewards, rhods-users        | Insurance        |
| sci-frank | Data Scientist | insurance-data-scientists, rhods-users      | Insurance        |
| mle-gina  | ML Engineer    | ml-engineers, rhods-users                   | Platform         |
| ops-admin | Platform Admin | rhods-admins, rhods-users                   | Platform         |

## Environment variables

| Variable             | Default                          | Used by            |
|----------------------|----------------------------------|--------------------|
| `PASSWORD`           | (required)                       | all scripts        |
| `INGRESS_DOMAIN`     | `apps.cluster.example.com`       | freeipa/install.sh |
| `KEYCLOAK_URL`       | `https://keycloak.apps.cluster.example.com` | keycloak/setup.sh |
| `OAUTH_INGRESS_DOMAIN` | `oauth-openshift.apps.cluster.example.com` | keycloak/setup.sh |

Scripts are idempotent except `freeipa/populate.sh` and the Keycloak client creation
(both fail if the users/groups/client already exist).
