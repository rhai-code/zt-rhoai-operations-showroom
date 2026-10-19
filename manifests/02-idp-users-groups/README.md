# Module 2 Exercise Manifests

Manifests applied **by learners** during Module 2 exercises. The underlying
infra (in-cluster LDAP directory federated into the existing Keycloak) is
GitOps-managed in `zt-rhoai-operations-automation` — nothing here needs manual
setup.

## Exercise files

- **RHOAI authorization model** (`rhoai-auth/`) — applied in Exercises 2 and 4:

  ```bash
  oc apply -f rhoai-auth/auth-config.yaml      # RHOAI Auth CR (dashboard access)
  oc apply -f rhoai-auth/workbench-roles.yaml  # custom workbench ClusterRoles
  ```

- **MaaS governance** (`maas/`) — applied in Exercise 6, for the Lending model.
  Subscriptions MUST be in `models-as-a-service` ns; `tokenMetadata` placeholders
  required (RHCL CEL strictness); auth policy `subjects.groups` must match
  subscription `owner.groups` — see `maas/README.md`.

## Persona model

| User      | Persona        | Group(s)                  | Line of Business |
|-----------|----------------|---------------------------|------------------|
| own-alice | Data Owner     | lending-data-owners       | Lending          |
| ste-carol | Data Steward   | lending-data-stewards     | Lending          |
| sci-eve   | Data Scientist | lending-data-scientists   | Lending          |
| own-bob   | Data Owner     | insurance-data-owners     | Insurance        |
| ste-dave  | Data Steward   | insurance-data-stewards   | Insurance        |
| sci-frank | Data Scientist | insurance-data-scientists | Insurance        |
| mle-gina  | ML Engineer    | ml-engineers              | Platform         |
| ops-admin | Platform Admin | rhods-admins              | Platform         |

All users are also members of `rhods-users`. Groups arrive from FreeIPA via the
Keycloak LDAP federation and the OCP OAuth groups claim — see
`zt-rhoai-operations-automation/cluster/START_HERE.md`.
