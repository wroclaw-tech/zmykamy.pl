#!/bin/sh
# Single-node local setup: assigns the layout, imports a fixed key and creates the bucket. Safe to rerun.
set -eu

apk add --no-cache --quiet curl jq

admin() {
  curl -fsS -H "Authorization: Bearer $GARAGE_ADMIN_TOKEN" -H "Content-Type: application/json" "$@"
}

until admin "$GARAGE_ADMIN_URL/v2/GetClusterHealth" > /dev/null 2>&1; do sleep 1; done

layout=$(admin "$GARAGE_ADMIN_URL/v2/GetClusterLayout")
if [ "$(echo "$layout" | jq '.roles | length')" = "0" ]; then
  node_id=$(admin "$GARAGE_ADMIN_URL/v2/GetClusterStatus" | jq -r '.nodes[0].id')
  admin -X POST "$GARAGE_ADMIN_URL/v2/UpdateClusterLayout" \
    -d "{\"roles\":[{\"id\":\"$node_id\",\"zone\":\"local\",\"capacity\":1000000000,\"tags\":[]}]}" > /dev/null
  version=$(echo "$layout" | jq '.version + 1')
  admin -X POST "$GARAGE_ADMIN_URL/v2/ApplyClusterLayout" -d "{\"version\":$version}" > /dev/null
fi

if ! admin "$GARAGE_ADMIN_URL/v2/GetKeyInfo?id=$S3_ACCESS_KEY_ID" > /dev/null 2>&1; then
  admin -X POST "$GARAGE_ADMIN_URL/v2/ImportKey" \
    -d "{\"name\":\"backend\",\"accessKeyId\":\"$S3_ACCESS_KEY_ID\",\"secretAccessKey\":\"$S3_SECRET_ACCESS_KEY\"}" > /dev/null
fi

bucket=$(admin "$GARAGE_ADMIN_URL/v2/GetBucketInfo?globalAlias=$S3_BUCKET" 2> /dev/null || true)
if [ -z "$bucket" ]; then
  bucket=$(admin -X POST "$GARAGE_ADMIN_URL/v2/CreateBucket" -d "{\"globalAlias\":\"$S3_BUCKET\"}")
fi
bucket_id=$(echo "$bucket" | jq -r '.id')

admin -X POST "$GARAGE_ADMIN_URL/v2/AllowBucketKey" \
  -d "{\"bucketId\":\"$bucket_id\",\"accessKeyId\":\"$S3_ACCESS_KEY_ID\",\"permissions\":{\"read\":true,\"write\":true,\"owner\":true}}" > /dev/null

echo "Garage ready: bucket $S3_BUCKET"
