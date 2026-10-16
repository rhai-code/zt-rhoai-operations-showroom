# RHOAI Ops Patterns -- Dev vs Prod DSC Configuration

A small, runnable example of the app-of-apps pattern composing Helm,
Kustomize, raw YAML, and ACM policies to show changing `DataScienceCluster`
(DSC) configuration between dev and prod environments.

```
manifests/01-ops-patterns/
├── bootstrap/app-of-apps.yaml      # root Application -> applications/
├── applications/                   # child Applications, one per environment
│   ├── dev.yaml                    #   -> envs/dev
│   └── prod.yaml                   #   -> envs/prod
├── base/                           # Kustomize base: DSCI, DSC core, OdhDashboardConfig (raw YAML)
├── envs/
│   ├── dev/                        # base + DSC patch + Helm chart (beta channel, no pin)
│   └── prod/                       # base + DSC patch + Helm chart (stable-3.5, pinned)
├── policy/policy-generator.yaml    # ACM PolicyGenerator wrapping both environments
└── kustomization.yaml              # policy generation root
```

Render locally (the same command the ArgoCD plugin runs):

```bash
cd manifests/01-ops-patterns

# Helm -- operator install per environment
helm template rhoai-operators envs/dev/charts/rhoai-operators
helm template rhoai-operators envs/prod/charts/rhoai-operators

# Kustomize -- full environment: base + DSC patch + inflated Helm chart
kustomize build --enable-alpha-plugins --enable-helm envs/dev
kustomize build --enable-alpha-plugins --enable-helm envs/prod

# Side-by-side diff: dev left, prod right
diff -y --suppress-common-lines \
    <(kustomize build --enable-alpha-plugins --enable-helm envs/dev) \
    <(kustomize build --enable-alpha-plugins --enable-helm envs/prod)

# Validate without applying anything (client-side dry run)
kustomize build --enable-alpha-plugins --enable-helm envs/prod | oc apply --dry-run=client -f -

# ACM policies (requires the policy-generator-plugin on PATH)
kustomize build --enable-alpha-plugins --enable-helm .
```

Apply the app-of-apps root once, and ArgoCD creates the child Applications:

```bash
oc apply -f bootstrap/app-of-apps.yaml
```
