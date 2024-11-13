#!/bin/bash

echo "Проверка в шарде 1..."
docker compose exec -T shard1 mongosh --quiet --port 27019 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 2..."
docker compose exec -T shard2 mongosh --quiet --port 27020 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
