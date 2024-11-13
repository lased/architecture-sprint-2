#!/bin/bash

echo "Проверка в шарде 1a..."
docker compose exec -T shard1a mongosh --quiet --port 27019 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 1b..."
docker compose exec -T shard1b mongosh --quiet --port 27019 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 1c..."
docker compose exec -T shard1c mongosh --quiet --port 27019 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 2a..."
docker compose exec -T shard2a mongosh --quiet --port 27020 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 2b..."
docker compose exec -T shard2b mongosh --quiet --port 27020 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Проверка в шарде 2c..."
docker compose exec -T shard2c mongosh --quiet --port 27020 <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
