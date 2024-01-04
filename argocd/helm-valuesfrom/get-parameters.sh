#!/bin/sh
set -e

yq e -o=json values.yaml | jq '{
  name: "valuesFrom",
  title: "valuesFrom",
  collectionType: "array",
  array: [leaf_paths as $path | {"key": $path | join("."), "value": getpath($path)|tostring}] | from_entries
}'
