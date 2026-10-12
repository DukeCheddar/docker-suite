# Système Docker

Cette page décrit le système Docker de développement de la suite : les conteneurs qui existent, la façon dont ils sont reliés, le trajet d'une requête, et la manière d'exploiter et d'étendre le système.

État décrit ici : 12 octobre 2026. Les noms des conteneurs, le nom d'hôte, les adresses et les ports sont les valeurs de `.env.example`; un `.env` local peut en utiliser d'autres. Version anglaise : [DOCKER.en.md](DOCKER.en.md).

## 1. Vue d'ensemble

La suite tourne dans neuf conteneurs, sur un réseau Docker privé. Un seul d'entre eux, `suite-core`, est joignable pour le trafic applicatif.

```
               navigateur  (http://suite.local/)
                    ▲
                    │ port 80 / 8080
                    ▼  
            ┌─────────────────┐
            │ suite-core(nginx) │ ───────────────────────────────────────────┐
            └────────┬────────┘                                            │
   ┌────────┬────────┴──┬───────────┬───────────┬────────────┐             │
   ▼        ▼           ▼           ▼           ▼            ▼             ▲            
suite-web  identity  organization  employee  orchestration  storage     notification
(interface) (API)    (API)        (API)       (API)        (API)       (socket)
            │          │            │           │            │             │
            └──────────┴────────────┴─────┬─────┴────────────┴─────────────┘
                                          ▼
                                   ┌───────────────┐
                                   │ suite-event-bus │  redis
                                   └───────────────┘
```

Trois règles donnent sa forme au système :

- **Un service par conteneur.** Chaque conteneur de service contient son code Node.js et sa propre base de données PostgreSQL.
- **Une seule porte d'entrée.** Le navigateur ne parle qu'à `suite-core`, qui aiguille vers l'interface, les API et le service de socket.
- **Le bus d'événements est le seul lien entre les services.** Aucun service n'appelle l'API d'un autre, et aucun service ne peut joindre la base de données d'un autre.

## 2. Les conteneurs

| Conteneur | Service Compose | Rôle | Contenu |
| --- | --- | --- | --- |
| `suite-core` | `core` | Porte d'entrée. Aiguille chaque requête vers le bon conteneur. | nginx (image `nginx:stable` d'origine) |
| `suite-web` | `web` | Interface utilisateur. | Node.js |
| `suite-identity` | `identity` | Service d'identité : comptes et connexion. API. | Node.js, PostgreSQL |
| `suite-organization` | `organization` | Service des organisations. API. | Node.js, PostgreSQL |
| `suite-employee` | `employee` | Service des employés. API. | Node.js, PostgreSQL |
| `suite-notification` | `notification` | Service de notifications : livre les événements aux utilisateurs par une connexion socket. | Node.js, PostgreSQL |
| `suite-orchestration` | `orchestration` | Conteneur en attente, sans rôle attribué pour l'instant (voir la section 9). | Node.js, PostgreSQL |
| `suite-storage` | `storage` | Suite Storage, conteneur système : adhésions, paiements et organisations des clients qui utilisent la suite. API. | Node.js, PostgreSQL |
| `suite-event-bus` | `event-bus` | Suite Event Bus, conteneur système : transporte les événements de tous les services, Suite Storage compris. | Redis 7 |

Les bibliothèques applicatives (Fastify, socket.io, le client Redis) ne font pas partie des images. Chaque service les installe par son propre `package.json`, dans son espace de travail.

Aucune application ne démarre toute seule. Un conteneur de service démarre PostgreSQL et le serveur SSH; le développeur lance l'application Node.js à partir d'une session SSH.

## 3. Réseau, adresses et ports

Réseau : `suite-network`, sous-réseau `172.146.0.0/16`. Chaque conteneur a une adresse fixe.

| Conteneur | Adresse | Port sur l'hôte | Port interne |
| --- | --- | --- | --- |
| `suite-core` | 172.146.0.10 | **80** (HTTP) | 80 |
| `suite-web` | 172.146.0.16 | 55337 (SSH) | 4200 (interface), 22 (SSH) |
| `suite-identity` | 172.146.0.21 | 55331 (SSH) | 3000 (API), 22 (SSH) |
| `suite-notification` | 172.146.0.22 | 55332 (SSH) | 3000 (socket), 22 (SSH) |
| `suite-organization` | 172.146.0.23 | 55333 (SSH) | 3000 (API), 22 (SSH) |
| `suite-employee` | 172.146.0.24 | 55334 (SSH) | 3000 (API), 22 (SSH) |
| `suite-orchestration` | 172.146.0.25 | 55336 (SSH) | 3000 (API), 22 (SSH) |
| `suite-storage` | 172.146.0.31 | 55335 (SSH) | 3000 (API), 22 (SSH) |
| `suite-event-bus` | 172.146.0.63 | aucun | 6379 (Redis) |

- **Le port 80 de `suite-core` est le seul port applicatif publié sur l'hôte.** Les ports des API, de l'interface, du socket, de PostgreSQL et de Redis sont internes.
- **Les ports SSH ne servent qu'au développement.** Ils permettent à un développeur d'ouvrir une session dans chaque conteneur. La connexion se fait par clé seulement; la connexion par mot de passe est désactivée.
- **`suite-core` n'a pas de SSH.** Utiliser `docker exec -it suite-core bash` à partir de l'hôte.

### Nom d'hôte

nginx répond au nom `suite.local`. Sur chaque machine qui sert à naviguer, ajouter cette ligne au fichier hosts (remplacer `<docker-host-ip>` par l'adresse de l'hôte Docker) :

```
<docker-host-ip>  suite.local
```

## 4. Aiguillage des requêtes

`suite-core` choisit la destination d'après le début de l'URL.

| URL | Destination | Chemin reçu par la destination |
| --- | --- | --- |
| `/api/identity/…` | `suite-identity`, port 3000 | `/…` (préfixe retiré) |
| `/api/organization/…` | `suite-organization`, port 3000 | `/…` (préfixe retiré) |
| `/api/employee/…` | `suite-employee`, port 3000 | `/…` (préfixe retiré) |
| `/api/orchestration/…` | `suite-orchestration`, port 3000 | `/…` (préfixe retiré) |
| `/api/suite/…` | `suite-storage`, port 3000 | `/…` (préfixe retiré) |
| `/socket.io/…` | `suite-notification`, port 3000 | inchangé, WebSocket pris en charge |
| `/healthz` | nginx répond lui-même : `200 ok` | — |
| tout le reste | `suite-web`, port 4200 | inchangé |

Exemple : la création d'une organisation.

1. L'interface envoie `POST http://suite.local/api/organization/create`.
2. `suite-core` transmet la requête à `suite-organization` sous la forme `POST /create`.
3. Le service des organisations valide, écrit dans sa propre base de données et publie un événement sur le bus.
4. Le service répond à cette même requête HTTP (créée, ou une erreur). `suite-core` renvoie cette réponse à l'interface.

Le service de notifications ne sert pas à répondre à l'appelant. Il livre ce qu'une réponse HTTP ne peut pas porter : les événements destinés aux autres utilisateurs, les résultats qui arrivent plus tard et les traitements longs.

À savoir :

- **Un service qui n'écoute pas renvoie 502**, pour ses propres routes seulement. Les autres routes continuent de fonctionner.
- **L'application doit écouter sur `0.0.0.0`**, et non sur `localhost`, sans quoi `suite-core` ne peut pas la joindre.
- **Un serveur de développement d'interface peut refuser un nom d'hôte inconnu.** Ajouter `suite.local` à ses hôtes autorisés.

Le fichier d'aiguillage est `configs/nginx/templates/default.conf.template`. Les valeurs écrites `${NOM}` viennent de `compose.yml`; toute autre `$variable` appartient à nginx. Après une modification, lancer `docker compose restart core`.

## 5. L'intérieur d'un conteneur de service

Les six conteneurs de service (`identity`, `notification`, `organization`, `employee`, `orchestration`, `storage`) partagent une seule image, `suite-service`, construite à partir de `dockerfiles/service/Dockerfile`.

| Élément | Valeur |
| --- | --- |
| Base | Ubuntu 22.04 |
| Node.js | 24.21.0, installé avec nvm; `node`, `npm` et `npx` sont disponibles dans toutes les sessions |
| PostgreSQL | 16, une instance par conteneur |
| Outils | `psql`, `redis-cli`, git, curl, vim |
| Utilisateur | `dev_user`, avec l'UID et le GID de l'utilisateur local, membre de `sudo` |

### Démarrage

Le script de démarrage (`dockerfiles/service/entrypoint.sh`) fait ceci à chaque démarrage :

1. Il écrit les paramètres du service là où les sessions SSH peuvent les lire (`/etc/environment`).
2. Il crée la grappe PostgreSQL si le dossier de données est vide.
3. Il démarre PostgreSQL, à l'écoute sur `127.0.0.1` seulement.
4. Il crée le rôle et la base de données du service s'ils n'existent pas.
5. Il démarre le serveur SSH.

À l'arrêt, il arrête PostgreSQL proprement.

### La base de données

Chaque service possède une base de données, dans son propre conteneur. Elle n'écoute que sur `127.0.0.1:5432` : aucun autre conteneur ne peut s'y connecter. C'est ce qui fait respecter la règle « une base de données par service ».

| Service | Base de données | Rôle |
| --- | --- | --- |
| identity | `identity_db` | `identity_user` |
| notification | `notification_db` | `notification_user` |
| organization | `organization_db` | `organization_user` |
| employee | `employee_db` | `employee_user` |
| orchestration | `orchestration_db` | `orchestration_user` |
| storage | `suite_db` | `suite_user` |

### Variables d'environnement

Disponibles avec `docker exec` et dans les sessions SSH.

| Variable | Signification |
| --- | --- |
| `SERVICE_NAME` | Nom du service : `identity`, `organization`, … |
| `API_PORT` | Port sur lequel l'API doit écouter (`SOCKET_PORT` pour notification) |
| `DB_HOST`, `DB_PORT` | `127.0.0.1`, `5432` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD` | La base de données, le rôle et le mot de passe du service |
| `EVENT_BUS_HOST`, `EVENT_BUS_PORT` | `event-bus`, `6379` |
| `EVENT_BUS_PASSWORD` | Mot de passe du bus d'événements |

Vérifications rapides, à l'intérieur d'un conteneur de service :

```bash
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME
REDISCLI_AUTH=$EVENT_BUS_PASSWORD redis-cli -h $EVENT_BUS_HOST -p $EVENT_BUS_PORT ping
```

## 6. Les autres conteneurs

### `suite-web`

Construit à partir de `dockerfiles/web/Dockerfile` : la même base qu'un conteneur de service, sans PostgreSQL et sans script de démarrage. L'interface doit écouter sur `0.0.0.0:4200`. Le port 4200 n'est pas publié; on atteint l'interface par `suite-core`, à `http://suite.local/`.

### `suite-event-bus`

Redis 7, protégé par un mot de passe, avec la persistance en ajout seul (append-only) pour que ses données survivent à un redémarrage. Il n'a aucun port sur l'hôte : seuls les conteneurs de `suite-network` peuvent le joindre, sous le nom `event-bus`.

### `suite-core`

L'image `nginx:stable` d'origine. Sa configuration est générée au démarrage à partir du gabarit monté depuis l'hôte (section 4).

## 7. Fichiers

```
docker-suite/
├── compose.yml                     les conteneurs et leurs liens
├── .env.example                    gabarit de .env, sans mots de passe
├── .env                            tous les paramètres et tous les mots de passe (hors git)
├── configs/nginx/templates/
│   └── default.conf.template       règles d'aiguillage de suite-core
├── dockerfiles/
│   ├── service/                    image des six conteneurs de service
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── configs/etc/ssh/        sshd_config, authorized_keys (hors git) et son gabarit
│   └── web/                        image de suite-web
│       ├── Dockerfile
│       └── configs/etc/ssh/        sshd_config, authorized_keys (hors git) et son gabarit
├── documentations/                 cette documentation
└── volumes/                        données conservées hors des conteneurs
    ├── documentations/             documentation partagée, dépôt distinct (hors de celui-ci), monté dans chaque conteneur de développement
    ├── <service>/workspaces/       code source du service
    ├── <service>/postgres/         données PostgreSQL du service
    ├── web/workspaces/             code source de l'interface
    └── event-bus/data/             données Redis
```

Dans un conteneur de développement, les dossiers montés apparaissent ainsi :

| Dossier sur l'hôte | Chemin dans le conteneur |
| --- | --- |
| `volumes/documentations` | `/home/dev_user/documentations` |
| `volumes/<service>/workspaces` | `/home/dev_user/workspaces` |
| `volumes/<service>/postgres` | `/var/lib/postgresql/data` |

Les secrets ne sont pas dans le dépôt. Les mots de passe ne se trouvent que dans `.env`, et les clés publiques SSH que dans les deux fichiers `authorized_keys`; git ignore ces trois fichiers. Le dépôt contient leurs gabarits : `.env.example` et `authorized_keys.example`. Git ignore aussi les données des conteneurs, la documentation partagée et le contenu des espaces de travail : la documentation et le code de chaque service vivent dans leurs propres dépôts, placés dans `volumes/`.

## 8. Exploitation

Lancer ces commandes à partir de la racine de ce dépôt.

### Première installation

Après avoir cloné le dépôt, il faut créer les fichiers secrets à partir de leurs gabarits.

1. Copier `.env.example` vers `.env`.
2. Dans `.env`, remplacer chaque `change-me` par un mot de passe distinct (`openssl rand -hex 16` en fournit un).
3. Dans `.env`, donner à `DEV_UID` et à `DEV_GID` les valeurs de votre utilisateur local (`id -u`, `id -g`). L'utilisateur `dev_user` du conteneur possède alors les fichiers de `volumes/` exactement comme vous sur l'hôte, ce qui évite les problèmes de permissions.
4. Dans `dockerfiles/service/configs/etc/ssh/` et dans `dockerfiles/web/configs/etc/ssh/`, copier `authorized_keys.example` vers `authorized_keys` et y ajouter vos clés publiques SSH.
5. Cloner le dépôt de la documentation partagée dans `volumes/documentations` (ou créer le dossier si vous ne l'avez pas encore). Le faire avant le premier démarrage, sinon Docker crée le dossier au nom de root.
6. Lancer `docker compose up -d --build`.

### Commandes courantes

| But | Commande |
| --- | --- |
| Tout démarrer | `docker compose up -d` |
| Tout arrêter en gardant les données | `docker compose down` |
| Voir l'état | `docker compose ps` |
| Suivre les journaux d'un conteneur | `docker logs -f suite-identity` |
| Redémarrer un conteneur | `docker compose restart identity` |
| Appliquer une modification de l'aiguillage | `docker compose restart core` |
| Appliquer une modification de `.env` ou de `compose.yml` | `docker compose up -d` |
| Reconstruire l'image des services | `docker compose build identity`, puis `docker compose up -d` |
| Reconstruire l'image web | `docker compose build web`, puis `docker compose up -d` |
| Ouvrir une session à partir de l'hôte | `docker exec -it -u dev_user suite-identity bash` |
| Ouvrir une session à partir d'une autre machine | `ssh -p 55331 dev_user@<docker-host-ip>` |
| Vérifier la porte d'entrée | `curl http://suite.local/healthz` |

Les six conteneurs de service partagent une seule image : il suffit de la construire une fois, par n'importe lequel d'entre eux.

### Ajouter une clé SSH

Ajouter la clé publique dans `dockerfiles/service/configs/etc/ssh/authorized_keys` et dans `dockerfiles/web/configs/etc/ssh/authorized_keys`, puis reconstruire les deux images.

### Ajouter un service

1. `.env` : ajouter une section pour le service (nom, hôte, adresse, port SSH, port de l'API, nom de la base de données, rôle, mot de passe). Choisir une adresse libre et un port SSH libre.
2. `compose.yml` : copier le bloc d'un service existant et remplacer son nom. Ajouter sa ligne `<NOM>_UPSTREAM` dans la section `environment` de `core`.
3. `configs/nginx/templates/default.conf.template` : ajouter un bloc `location /api/<nom>/`.
4. Créer `volumes/<nom>/workspaces` et `volumes/<nom>/postgres`.
5. Lancer `docker compose up -d`.

## 9. Points ouverts

- **`suite-orchestration` n'a pas encore de rôle.** Les services coopèrent en publiant des événements et en y réagissant, ce qui ne demande aucun service central. Ce conteneur est conservé au cas où un long processus qui traverse plusieurs services aurait besoin d'un coordonnateur. On peut le retirer d'ici là.
- **Ce dossier n'est pas visible de l'intérieur des conteneurs.** Les conteneurs montent `volumes/documentations`, et non `documentations`.
- **Développement seulement.** Pas de HTTPS, ports SSH de développement ouverts sur toutes les interfaces, aucun démarrage automatique des applications.
