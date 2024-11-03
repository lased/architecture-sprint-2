#!/bin/bash

docker-compose down -v
docker-compose up -d 

echo "Инициализация сервера конфигурации..."
docker compose exec -T config_server mongosh --quiet --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "config_server:27017" }
    ]
  }
);
EOF

echo "Инициализация шарда 1..."
docker compose exec -T shard1a mongosh --quiet --port 27019 <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1a:27019" },
    { _id: 1, host: "shard1b:27019" },
    { _id: 2, host: "shard1c:27019" },
  ]
})
EOF

echo "Инициализация шарда 2..."
docker compose exec -T shard2a mongosh --quiet --port 27020 <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2a:27020" },
    { _id: 1, host: "shard2b:27020" },
    { _id: 2, host: "shard2c:27020" },
  ]
})
EOF

echo "Инициализация роутера..."
docker compose exec -T mongos_router mongosh --quiet --port 27018 <<EOF
sh.addShard("shard1/shard1a:27019,shard1b:27019,shard1c:27019")
sh.addShard("shard2/shard2a:27020,shard2b:27020,shard2c:27020")

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
EOF

echo "Вставка данных в коллекцию helloDoc..."
docker compose exec -T mongos_router mongosh --quiet --port 27018 <<EOF
use somedb
for (let index = 0; index < 2000; index++) {
  db.helloDoc.insertOne({
    name : "Keka peka " + index,
    age: Math.round(Math.random() * 100)
  })
}
EOF

echo "Готово"