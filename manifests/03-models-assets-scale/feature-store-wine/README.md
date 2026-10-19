# Feature Store -- Wine Quality Classifier (Module 3 seeding)

Seeding manifests for a Feast (Feature Store) driven wine quality classifier:
feature definitions, a training job, KServe model serving, and model registry
registration. Intended for use in **Module 3: Managing Models and Assets at Scale**.

## Run order

```bash
export MODEL_REGISTRY_URL=https://model-registry.apps.cluster.example.com

oc new-project wine-classifier
oc adm policy add-role-to-group edit lending-data-scientists -n wine-classifier

oc apply -f feast-config.yaml      # Feast feature repo (feature_store.yaml + feature views)
oc create configmap wine-training-script \
  --from-file=train.py=train.py -n wine-classifier
oc apply -f training-job.yaml      # Training Job + model PVC
oc wait --for=condition=complete job/wine-training -n wine-classifier --timeout=300s
oc logs job/wine-training -n wine-classifier

oc apply -f inferenceservice.yaml  # KServe RawDeployment model serving
oc wait --for=condition=Ready inferenceservice/wine-classifier -n wine-classifier --timeout=300s

./register-model.sh                # register model + version + artifact in the registry
```

## Test the inference endpoint

```bash
INFERENCE_URL=$(oc get inferenceservice wine-classifier -n wine-classifier -o jsonpath='{.status.url}')
curl -sk "${INFERENCE_URL}/v1/models/wine-classifier:predict" \
  -H "Content-Type: application/json" \
  -d '{"instances": [[13.72, 1.43, 2.50, 16.7, 108, 3.40, 3.67, 0.19, 2.04, 6.8, 0.89, 2.87, 1285]]}'
```

## Notes

- The Feast config expects a wine quality dataset at `/data/wine-quality.parquet`
  (UCI Wine dataset) mounted where the features are materialized.
- The training job installs `scikit-learn joblib pandas numpy` at runtime and saves
  `wine-classifier.joblib` to `wine-model-pvc`, which the InferenceService serves via
  `pvc://`.
- `register-model.sh` requires the model registry to be enabled on the cluster
  (RHOAI `modelregistry` component) and reachable at `MODEL_REGISTRY_URL`.
