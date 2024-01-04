#!/bin/sh
set -e

VALUES_STRING=""

# Should do caching of this
kubectl config set-cluster in-cluster --server="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt &> /dev/null
kubectl config set-credentials in-cluster --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" &> /dev/null
kubectl config set-context in-cluster --cluster=in-cluster --user=in-cluster &> /dev/null
kubectl config use-context in-cluster &> /dev/null

# Determines name and namespace of argo application
# See https://argo-cd.readthedocs.io/en/stable/operator-manual/app-any-namespace/
if echo "${ARGOCD_APP_NAME}" | grep -q '/'; then
  APP_NAME=$(echo "${ARGOCD_APP_NAME}" | awk -F'/' '{print $2}')
  APP_NAMESPACE=$(echo "${ARGOCD_APP_NAME}" | awk -F'/' '{print $1}')
else
  APP_NAME="${ARGOCD_APP_NAME}"
  APP_NAMESPACE=$(kubectl get application ${ARGOCD_APP_NAME} -o json | jq '.metadata.namespace')
fi

# Builds ValuesFrom
for valuesFromRef in $(echo "${ARGOCD_APP_PARAMETERS}" | jq -r 'fromjson | .[] | @base64'); do
     _jq() {
       echo ${valuesFromRef} | base64 -d | jq -r ${1}
      }

      fullRef=$(_jq ".")
      valuesFromRefKind=$(_jq ".kind")
      valuesFromRefName=$(_jq ".name")
      valuesFromRefValuesKey=$(_jq ".valuesKey")

      if [[ -z "${valuesFromRefKind}" ]] || [[ "${valuesFromRefKind}" != "secret" &&  "${valuesFromRefKind}" != "configmap" ]]; then
        echo "${fullRef} has invalid 'kind' value: '${valuesFromRefKind}', must be one of ['secret', 'configmap']" >&2
        exit 1
      fi
      if [[ -z "${valuesFromRefName}" ]]; then
        echo "${fullRef} has invalid 'name' value: '${valuesFromRefName}', you must specify the name of the ${valuesFromRefKind}" >&2
        exit 1
      fi
      if [[ -z "${valuesFromRefValuesKey}" ]]; then
        echo "no 'valuesKey' for ${valuesFromRefKind}:${valuesFromRefName}, defaulting to 'values.yaml'" >&2
        valuesFromRefValuesKey="values.yaml"
      fi

      valuesFileName="/tmp/${valuesFromRefKind}-${valuesFromRefName}-${valuesFromRefValuesKey}.yaml"
      # Fetch valueFrom kubectl
      if [[ "${valuesFromRefKind}" == "secret" ]]; then
        kubectl get secret -n "${APP_NAMESPACE}" "${valuesFromRefName}" -o json | jq --arg valuesKey "${valuesFromRefValuesKey}" '.data[$valuesKey] | @base64d' > ${valuesFileName}
      else
        kubectl get configmap -n "${APP_NAMESPACE}" "${valuesFromRefName}" -o json | jq --arg valuesKey "${valuesFromRefValuesKey}" '. | $valuesKey' > ${valuesFileName}
      fi

      VALUES_STRING+="--values ${valuesFileName} "
done

echo ". $VALUES_STRING" | xargs helm -n ${ARGOCD_APP_NAMESPACE} template
