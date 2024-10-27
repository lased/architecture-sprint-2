# Шардирование и репликация

## Проектирование

Проблема: сервис не справляется с нагрузками и выяснилось, что один из микросервисов — API, который работает с базой данных, — не справился с нагрузкой и повлиял на работу всего приложения - как итог: потеря многих заказов и прибыли.

Изначальная схема:

```mermaid
flowchart LR
    db[(MongoDB)]
    api[pymongo-api]

    api --> db
```

Изменения начнем с БД и настроим репликацию для `MongoDB`:

```mermaid
flowchart LR
    dbPrimary[("MongoDB<br/>(Primary)")]
    dbReplica1[("MongoDB<br/>(Replica 1)")]
    dbReplica2[("MongoDB<br/>(Replica 2)")]
    dbReplica3[("MongoDB<br/>(Replica 3)")]
    api[pymongo-api]

    subgraph MongoDB
        dbPrimary --> dbReplica1
        dbPrimary --> dbReplica2
        dbPrimary --> dbReplica3
    end

    api --> dbPrimary
```

Так как сервис `pymongo-api` работает с БД, которая в свою очередь не справлялась с нагрузкой, то на схеме выше мы немного распределили нагрузку на несколько хостов: первичный (он же мастер) - на чтение и запись и 3 реплики - на чтение.

Но так как заказов будет много и хотелось бы хранить их историю, нам еще потребуется шардировать БД:

```mermaid
flowchart TD
    api[pymongo-api]

    api --> MongoDB

    subgraph MongoDB
        dbConfig1[("MongoDB<br/>(Config)")]
        dbRouter1[("MongoDB<br/>(Router)")]

        subgraph Shard1
            dbPrimary1[("MongoDB<br/>(Primary)")]
            dbReplica11[("MongoDB<br/>(Replica 1)")]
            dbReplica12[("MongoDB<br/>(Replica 2)")]
            dbReplica13[("MongoDB<br/>(Replica 3)")]

            dbPrimary1 --> dbReplica11
            dbPrimary1 --> dbReplica12
            dbPrimary1 --> dbReplica13
        end

        subgraph Shard2
            dbPrimary2[("MongoDB<br/>(Primary)")]
            dbReplica21[("MongoDB<br/>(Replica 1)")]
            dbReplica22[("MongoDB<br/>(Replica 2)")]
            dbReplica23[("MongoDB<br/>(Replica 3)")]

            dbPrimary2 --> dbReplica21
            dbPrimary2 --> dbReplica22
            dbPrimary2 --> dbReplica23
        end

        dbRouter1 --> Shard1
        dbRouter1 --> Shard2
        dbRouter1 --> dbConfig1
        Shard1 --> dbConfig1
        Shard2 --> dbConfig1
    end
```

На схеме выше мы разбили БД на шарды, что позволит нам разделить данные, для маршрутизации между шардами используем 1 инстанс роутера и 1 инстанс сервера конфигурации (в дальнейшем, если возникнет потребность повысить отказоустойчивость роутера и сервера конфигурации, можно будет добавить дополнительные инстансы).

Далее добавим приложению возможность кэширования, для большей доступности - изменим код приложения, чтобы мы могли - читать/писать в мастер хост и читать с 2 реплик:

```mermaid
flowchart TD
    api[pymongo-api]

    subgraph MongoDB
        dbConfig1[("MongoDB<br/>(Config)")]
        dbRouter1[("MongoDB<br/>(Router)")]

        subgraph Shard1
            dbPrimary1[("MongoDB<br/>(Primary)")]
            dbReplica11[("MongoDB<br/>(Replica 1)")]
            dbReplica12[("MongoDB<br/>(Replica 2)")]
            dbReplica13[("MongoDB<br/>(Replica 3)")]

            dbPrimary1 --> dbReplica11
            dbPrimary1 --> dbReplica12
            dbPrimary1 --> dbReplica13
        end

        subgraph Shard2
            dbPrimary2[("MongoDB<br/>(Primary)")]
            dbReplica21[("MongoDB<br/>(Replica 1)")]
            dbReplica22[("MongoDB<br/>(Replica 2)")]
            dbReplica23[("MongoDB<br/>(Replica 3)")]

            dbPrimary2 --> dbReplica21
            dbPrimary2 --> dbReplica22
            dbPrimary2 --> dbReplica23
        end

        dbRouter1 --> Shard1
        dbRouter1 --> Shard2
        dbRouter1 --> dbConfig1
        Shard1 --> dbConfig1
        Shard2 --> dbConfig1
    end

    subgraph Redis
        redisPrimary[("Redis<br/>(Primary)")]
        redisReplica1[("Redis<br/>(Replica 1)")]
        redisReplica2[("Redis<br/>(Replica 2)")]

        redisPrimary --> redisReplica1
        redisPrimary --> redisReplica2
    end

    api --> MongoDB
    api --> Redis
```

Добавим возможность динамической поставки информации о новых инстансах сервиса, используя `API Gateway` + `Consul`:

```mermaid
flowchart TD
    subgraph MongoDB
        dbConfig1[("MongoDB<br/>(Config)")]
        dbRouter1[("MongoDB<br/>(Router)")]

        subgraph Shard1
            dbPrimary1[("MongoDB<br/>(Primary)")]
            dbReplica11[("MongoDB<br/>(Replica 1)")]
            dbReplica12[("MongoDB<br/>(Replica 2)")]
            dbReplica13[("MongoDB<br/>(Replica 3)")]

            dbPrimary1 --> dbReplica11
            dbPrimary1 --> dbReplica12
            dbPrimary1 --> dbReplica13
        end

        subgraph Shard2
            dbPrimary2[("MongoDB<br/>(Primary)")]
            dbReplica21[("MongoDB<br/>(Replica 1)")]
            dbReplica22[("MongoDB<br/>(Replica 2)")]
            dbReplica23[("MongoDB<br/>(Replica 3)")]

            dbPrimary2 --> dbReplica21
            dbPrimary2 --> dbReplica22
            dbPrimary2 --> dbReplica23
        end

        dbRouter1 --> Shard1
        dbRouter1 --> Shard2
        dbRouter1 --> dbConfig1
        Shard1 --> dbConfig1
        Shard2 --> dbConfig1
    end

    subgraph Redis
        redisPrimary[("Redis<br/>(Primary)")]
        redisReplica1[("Redis<br/>(Replica 1)")]
        redisReplica2[("Redis<br/>(Replica 2)")]

        redisPrimary --> redisReplica1
        redisPrimary --> redisReplica2
    end

    subgraph ApiGateway
        apiGateway["API Gateway"]

        apiGateway --> consul-kv
    end

    subgraph Services
        pymongo-api1["pymongo-api"]
        pymongo-api2["pymongo-api"]
    end

    entrypoint["Пользователи"] --> ApiGateway
    ApiGateway --> Services
    consul-kv --> consul

    Services --> consul
    Services --> Redis
    Services --> MongoDB
```

В результате получим балансировку нагрузки по сервисам приложения, если потребуется больше мощностей со стороны `API` приложения - достаточно будет поднять инстанс и зарегистрировать его в консуле, где уже `API Gateway` начнет распределять нагрузку между инстансами приложения.

Для оптимизации доставки контента (статических файлов) и улучшения `SEO` в разных регионах, добавим `CDN`, который позволит нам ускорить доставку статических файлов клиенту из своего кэша (если данных не будет в нем, то `CDN` пойдет за ними в `API Gateway`):

```mermaid
flowchart TB
    subgraph MongoDB
        dbConfig1[("MongoDB<br/>(Config)")]
        dbRouter1[("MongoDB<br/>(Router)")]

        subgraph Shard1
            dbPrimary1[("MongoDB<br/>(Primary)")]
            dbReplica11[("MongoDB<br/>(Replica 1)")]
            dbReplica12[("MongoDB<br/>(Replica 2)")]
            dbReplica13[("MongoDB<br/>(Replica 3)")]

            dbPrimary1 --> dbReplica11
            dbPrimary1 --> dbReplica12
            dbPrimary1 --> dbReplica13
        end

        subgraph Shard2
            dbPrimary2[("MongoDB<br/>(Primary)")]
            dbReplica21[("MongoDB<br/>(Replica 1)")]
            dbReplica22[("MongoDB<br/>(Replica 2)")]
            dbReplica23[("MongoDB<br/>(Replica 3)")]

            dbPrimary2 --> dbReplica21
            dbPrimary2 --> dbReplica22
            dbPrimary2 --> dbReplica23
        end

        dbRouter1 --> Shard1
        dbRouter1 --> Shard2
        dbRouter1 --> dbConfig1
        Shard1 --> dbConfig1
        Shard2 --> dbConfig1
    end

    subgraph Redis
        redisPrimary[("Redis<br/>(Primary)")]
        redisReplica1[("Redis<br/>(Replica 1)")]
        redisReplica2[("Redis<br/>(Replica 2)")]

        redisPrimary --> redisReplica1
        redisPrimary --> redisReplica2
    end

    subgraph ApiGateway
        apiGateway["API Gateway"]

        apiGateway --> consul-kv
    end

    subgraph Services
        pymongo-api1["pymongo-api"]
        pymongo-api2["pymongo-api"]
    end

    subgraph Region1
        CDN1["CDN"]
    end

    subgraph Region2
        CDN2["CDN"]
    end

    entrypoint1["Пользователи<br/>из Региона 1"] --> Region1
    entrypoint2["Пользователи<br/>из Региона 2"] --> Region2
    ApiGateway --> Services
    consul-kv --> consul

    Services --> consul
    Services --> Redis
    Services --> MongoDB

    Region1 --> ApiGateway
    Region2 --> ApiGateway
```
