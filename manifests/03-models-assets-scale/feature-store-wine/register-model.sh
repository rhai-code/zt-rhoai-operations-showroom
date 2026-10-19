# Registers the trained wine classifier in the RHOAI model registry.
set -euo pipefail

MODEL_REGISTRY_URL="${MODEL_REGISTRY_URL:-https://model-registry.apps.cluster.example.com}"
API="${MODEL_REGISTRY_URL}/api/model_registry/v1alpha3"

# 1. Create a registered model
curl -sk -X POST "${API}/registered_models" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "wine-quality-classifier",
    "description": "Random Forest classifier for wine quality prediction. Trained on the UCI Wine dataset with 13 chemical property features. Achieves >95% accuracy on the test set.",
    "customProperties": {
      "framework": {"string_value": "scikit-learn"},
      "task": {"string_value": "classification"},
      "owner": {"string_value": "lending-data-scientists"}
    }
  }'

# 2. Create a model version
REGISTERED_MODEL_ID=$(curl -sk "${API}/registered_models?name=wine-quality-classifier" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['id'])")
echo "Registered Model ID: ${REGISTERED_MODEL_ID}"

curl -sk -X POST "${API}/model_versions" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"v1.0.0\",
    \"registeredModelId\": \"${REGISTERED_MODEL_ID}\",
    \"description\": \"Initial training run. RandomForest with 100 estimators, random_state=42.\",
    \"customProperties\": {
      \"accuracy\": {\"string_value\": \"0.97\"},
      \"n_estimators\": {\"int_value\": \"100\"},
      \"training_data\": {\"string_value\": \"UCI Wine dataset\"},
      \"serving_runtime\": {\"string_value\": \"kserve-sklearnserver\"}
    }
  }"

# 3. Create a model artifact
MODEL_VERSION_ID=$(curl -sk "${API}/model_versions?name=v1.0.0" \
  | python3 -c "import sys,json; items=json.load(sys.stdin)['items']; print(items[0]['id'])")
echo "Model Version ID: ${MODEL_VERSION_ID}"

curl -sk -X POST "${API}/model_versions/${MODEL_VERSION_ID}/artifacts" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "wine-classifier-sklearn",
    "artifactType": "model-artifact",
    "uri": "pvc://wine-model-pvc/wine-classifier.joblib",
    "modelFormatName": "sklearn",
    "modelFormatVersion": "1.3",
    "description": "Serialized RandomForest model in joblib format"
  }'

# 4. Verify
curl -sk "${API}/registered_models" | python3 -m json.tool
