# Docker system

This page describes the development Docker system of the suite: which containers exist, how they are connected, how a request travels, and how to operate and extend the system.

State described here: 2026-10-12. Container names, host name, addresses and ports are the values of `.env.example`; a local `.env` may use others. French version: [DOCKER.fr.md](DOCKER.fr.md).

## 1. Overview

The suite runs as nine containers on one private Docker network. Only one of them, `suite-core`, is reachable for application traffic.

```
                 browser  (http://suite.local/)
                    │
                    ▼  port 80
              ┌───────────┐
              │ suite-core  │  nginx
              └─────┬─────┘
   ┌────────┬───────┼──────────┬──────────────┬──────────────┐
   ▼        ▼       ▼          ▼              ▼              ▼
suite-web  identity  organization  employee  orchestration  storage     notification
 (UI)     (API)      (API)        (API)       (API)        (API)       (socket)
            │          │            │           │            │              │
            └──────────┴────────────┴─────┬─────┴────────────┴──────────────┘
                                          ▼
                                   ┌───────────────┐
                                   │ suite-event-bus │  redis
                                   └───────────────┘
```

Three rules shape the system:

- **One service per container.** Each service container holds its Node.js code and its own PostgreSQL database.
- **One entry point.** The browser talks only to `suite-core`, which dispatches to the UI, the APIs and the socket service.
- **The event bus is the only link between services.** No service calls another service's API, and no service can reach another service's database.

## 2. The containers

| Container | Compose service | Role | Contents |
| --- | --- | --- | --- |
| `suite-core` | `core` | Entry point. Dispatches each request to the right container. | nginx (stock `nginx:stable` image) |
| `suite-web` | `web` | User interface. | Node.js |
| `suite-identity` | `identity` | Identity service: accounts and sign-in. API. | Node.js, PostgreSQL |
| `suite-organization` | `organization` | Organization service. API. | Node.js, PostgreSQL |
| `suite-employee` | `employee` | Employee service. API. | Node.js, PostgreSQL |
| `suite-notification` | `notification` | Notification service: delivers events to users over a socket connection. | Node.js, PostgreSQL |
| `suite-orchestration` | `orchestration` | Placeholder, no role assigned yet (see section 9). | Node.js, PostgreSQL |
| `suite-storage` | `storage` | Suite Storage, system container: memberships, payments and organizations of the clients using the suite. API. | Node.js, PostgreSQL |
| `suite-event-bus` | `event-bus` | Suite Event Bus, system container: carries the events of every service, Suite Storage included. | Redis 7 |

Application frameworks (Fastify, socket.io, the Redis client) are not part of the images. Each service installs them through its own `package.json` in its workspace.

No application starts by itself. A service container starts PostgreSQL and the SSH server; the developer starts the Node.js application from an SSH session.

## 3. Network, addresses and ports

Network: `suite-network`, subnet `172.146.0.0/16`. Every container has a fixed address.

| Container | Address | Host port | Internal port |
| --- | --- | --- | --- |
| `suite-core` | 172.146.0.10 | **80** (HTTP) | 80 |
| `suite-web` | 172.146.0.16 | 2201 (SSH) | 4200 (UI), 22 (SSH) |
| `suite-identity` | 172.146.0.21 | 2202 (SSH) | 3000 (API), 22 (SSH) |
| `suite-notification` | 172.146.0.22 | 2203 (SSH) | 3000 (socket), 22 (SSH) |
| `suite-organization` | 172.146.0.23 | 2204 (SSH) | 3000 (API), 22 (SSH) |
| `suite-employee` | 172.146.0.24 | 2205 (SSH) | 3000 (API), 22 (SSH) |
| `suite-orchestration` | 172.146.0.25 | 2206 (SSH) | 3000 (API), 22 (SSH) |
| `suite-storage` | 172.146.0.31 | 2207 (SSH) | 3000 (API), 22 (SSH) |
| `suite-event-bus` | 172.146.0.63 | none | 6379 (Redis) |

- **Port 80 on `suite-core` is the only application port published on the host.** API, UI, socket, PostgreSQL and Redis ports are internal.
- **SSH ports are development access only.** They exist so that a developer can open a session in each container. Sign-in is by key only; password sign-in is disabled.
- **`suite-core` has no SSH.** Use `docker exec -it suite-core bash` from the host.

### Host name

nginx answers to `suite.local`. On each machine used to browse, add this line to the hosts file (replace `<docker-host-ip>` with the address of the Docker host):

```
<docker-host-ip>  suite.local
```

## 4. Request routing

`suite-core` chooses the destination from the start of the URL.

| URL | Destination | Path received by the destination |
| --- | --- | --- |
| `/api/identity/…` | `suite-identity`, port 3000 | `/…` (prefix removed) |
| `/api/organization/…` | `suite-organization`, port 3000 | `/…` (prefix removed) |
| `/api/employee/…` | `suite-employee`, port 3000 | `/…` (prefix removed) |
| `/api/orchestration/…` | `suite-orchestration`, port 3000 | `/…` (prefix removed) |
| `/api/suite/…` | `suite-storage`, port 3000 | `/…` (prefix removed) |
| `/socket.io/…` | `suite-notification`, port 3000 | unchanged, WebSocket supported |
| `/healthz` | answered by nginx itself: `200 ok` | — |
| anything else | `suite-web`, port 4200 | unchanged |

Example: creating an organization.

1. The UI sends `POST http://suite.local/api/organization/create`.
2. `suite-core` forwards it to `suite-organization` as `POST /create`.
3. The organization service validates, writes to its own database and publishes an event on the event bus.
4. The service answers the same HTTP request (created, or an error). `suite-core` returns that answer to the UI.

The notification service is not used to answer the caller. It delivers what an HTTP answer cannot carry: events for other users, results that arrive later, and long-running work.

Behaviour to know:

- **A service that is not listening returns 502** for its own routes only. The other routes keep working.
- **The application must listen on `0.0.0.0`**, not on `localhost`, otherwise `suite-core` cannot reach it.
- **A UI dev server may reject unknown host names.** Add `suite.local` to its allowed hosts.

The routing file is `configs/nginx/templates/default.conf.template`. Values written `${NAME}` come from `compose.yml`; every other `$variable` belongs to nginx. After a change, run `docker compose restart core`.

## 5. Inside a service container

The six service containers (`identity`, `notification`, `organization`, `employee`, `orchestration`, `storage`) share one image, `suite-service`, built from `dockerfiles/service/Dockerfile`.

| Element | Value |
| --- | --- |
| Base | Ubuntu 22.04 |
| Node.js | 24.21.0, installed with nvm; `node`, `npm`, `npx` available to every session |
| PostgreSQL | 16, one instance per container |
| Tools | `psql`, `redis-cli`, git, curl, vim |
| User | `dev_user`, with the UID and GID of the local user, member of `sudo` |

### Start-up

The entrypoint (`dockerfiles/service/entrypoint.sh`) does this at every start:

1. Writes the service settings where SSH sessions can read them (`/etc/environment`).
2. Creates the PostgreSQL cluster if the data folder is empty.
3. Starts PostgreSQL, listening on `127.0.0.1` only.
4. Creates the service's role and database if they do not exist.
5. Starts the SSH server.

On shutdown it stops PostgreSQL cleanly.

### The database

Each service owns one database, inside its own container. It listens on `127.0.0.1:5432` only, so no other container can connect to it. This enforces the rule "one database per service".

| Service | Database | Role |
| --- | --- | --- |
| identity | `identity_db` | `identity_user` |
| notification | `notification_db` | `notification_user` |
| organization | `organization_db` | `organization_user` |
| employee | `employee_db` | `employee_user` |
| orchestration | `orchestration_db` | `orchestration_user` |
| storage | `suite_db` | `suite_user` |

### Environment variables

Available in `docker exec` and in SSH sessions.

| Variable | Meaning |
| --- | --- |
| `SERVICE_NAME` | Name of the service: `identity`, `organization`, … |
| `API_PORT` | Port the API must listen on (`SOCKET_PORT` for notification) |
| `DB_HOST`, `DB_PORT` | `127.0.0.1`, `5432` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD` | The service's own database, role and password |
| `EVENT_BUS_HOST`, `EVENT_BUS_PORT` | `event-bus`, `6379` |
| `EVENT_BUS_PASSWORD` | Password of the event bus |

Quick checks from inside a service container:

```bash
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME
REDISCLI_AUTH=$EVENT_BUS_PASSWORD redis-cli -h $EVENT_BUS_HOST -p $EVENT_BUS_PORT ping
```

## 6. The other containers

### `suite-web`

Built from `dockerfiles/web/Dockerfile`: the same base as a service container, without PostgreSQL and without an entrypoint. The UI must listen on `0.0.0.0:4200`. Port 4200 is not published; the UI is reached through `suite-core` at `http://suite.local/`.

### `suite-event-bus`

Redis 7, protected by a password, with append-only persistence so that its data survives a restart. It has no host port: only the containers of `suite-network` can reach it, under the name `event-bus`.

### `suite-core`

The stock `nginx:stable` image. Its configuration is generated at start-up from the template mounted from the host (section 4).

## 7. Files

```
docker-suite/
├── compose.yml                     the containers and how they are wired
├── .env.example                    template of .env, without passwords
├── .env                            every setting and every password (not in git)
├── configs/ssh/config.example      example of SSH client configuration
├── configs/nginx/templates/
│   └── default.conf.template       routing rules of suite-core
├── dockerfiles/
│   ├── service/                    image of the six service containers
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── configs/etc/ssh/        sshd_config, authorized_keys (not in git) and its template
│   └── web/                        image of suite-web
│       ├── Dockerfile
│       └── configs/etc/ssh/        sshd_config, authorized_keys (not in git) and its template
├── documentations/                 this documentation
└── volumes/                        data kept outside the containers
    ├── documentations/             shared documentation, its own repository (not in this one), mounted in every dev container
    ├── <service>/workspaces/       source code of the service
    ├── <service>/postgres/         PostgreSQL data of the service
    ├── web/workspaces/             source code of the UI
    └── event-bus/data/             Redis data
```

Inside a dev container, the mounted folders appear as:

| Host folder | Path in the container |
| --- | --- |
| `volumes/documentations` | `/home/dev_user/documentations` |
| `volumes/<service>/workspaces` | `/home/dev_user/workspaces` |
| `volumes/<service>/postgres` | `/var/lib/postgresql/data` |

Secrets are not in the repository. Passwords are only in `.env`, and SSH public keys only in the two `authorized_keys` files; git ignores all three. The repository holds their templates: `.env.example` and `authorized_keys.example`. Git also ignores the container data, the shared documentation and the content of the workspaces: the documentation and the code of each service live in their own repositories, placed inside `volumes/`.

## 8. Operating the system

Run these commands from the root of this repository.

### First-time setup

After cloning the repository, the secret files must be created from their templates.

1. Copy `.env.example` to `.env`.
2. In `.env`, replace every `change-me` with its own password (`openssl rand -hex 16` gives one).
3. In `.env`, set `DEV_UID` and `DEV_GID` to the values of your local user (`id -u`, `id -g`). The container user `dev_user` then owns the files of `volumes/` exactly as you do on the host, which avoids permission problems.
4. In `dockerfiles/service/configs/etc/ssh/` and in `dockerfiles/web/configs/etc/ssh/`, copy `authorized_keys.example` to `authorized_keys` and add your SSH public keys.
5. Clone the shared documentation repository into `volumes/documentations` (or create the folder if you do not have it yet). Do this before the first start, otherwise Docker creates the folder as root.
6. Run `docker compose up -d --build`.

### Daily commands

| Goal | Command |
| --- | --- |
| Start everything | `docker compose up -d` |
| Stop everything, keep the data | `docker compose down` |
| See the state | `docker compose ps` |
| Follow the logs of a container | `docker logs -f suite-identity` |
| Restart one container | `docker compose restart identity` |
| Apply a routing change | `docker compose restart core` |
| Apply a change of `.env` or `compose.yml` | `docker compose up -d` |
| Rebuild the service image | `docker compose build identity`, then `docker compose up -d` |
| Rebuild the web image | `docker compose build web`, then `docker compose up -d` |
| Open a session from the host | `docker exec -it -u dev_user suite-identity bash` |
| Open a session from another machine | `ssh -p 2202 dev_user@<docker-host-ip>` |
| Check the entry point | `curl http://suite.local/healthz` |

The six service containers share one image: building it once through any of them is enough.

### SSH client configuration

`configs/ssh/config.example` is a ready-made `~/.ssh/config` block for the machine you develop from: one short name per dev container, so that `ssh suite-identity` is enough. Its ports are placeholders; replace them with the `*_SSH_PORT` values of your `.env`.

### Adding an SSH key

Add the public key to both `dockerfiles/service/configs/etc/ssh/authorized_keys` and `dockerfiles/web/configs/etc/ssh/authorized_keys`, then rebuild both images.

### Adding a service

1. `.env`: add a section for the service (name, host, address, SSH port, API port, database name, role, password). Choose a free address and a free SSH port.
2. `compose.yml`: copy the block of an existing service and replace its name. Add its `<NAME>_UPSTREAM` line to the `environment` of `core`.
3. `configs/nginx/templates/default.conf.template`: add a `location /api/<name>/` block.
4. Create `volumes/<name>/workspaces` and `volumes/<name>/postgres`.
5. Run `docker compose up -d`.

## 9. Open points

- **`suite-orchestration` has no role yet.** The services cooperate by publishing and reacting to events, which needs no central service. This container is kept in case a long process spanning several services needs a coordinator. It can be removed until then.
- **This folder is not visible from inside the containers.** The containers mount `volumes/documentations`, not `documentations`.
- **Development only.** No HTTPS, development SSH ports open on every interface, no automatic start of the applications.
