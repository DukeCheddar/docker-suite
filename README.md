# Docker development environment

[English](#english) · [Français](#français)

## English

Docker Compose configuration for a multi-service development environment: the containers, their network and the routing between them.

| Part | Role |
| --- | --- |
| nginx entry point | The only public port. Dispatches to the UI, the APIs and the socket service. |
| Web container | Node.js, serves the user interface. |
| Service containers | One service per container, each with Node.js and its own PostgreSQL database. |
| Event bus | Redis, the only link between the services. |

Quick start:

1. Copy `.env.example` to `.env` and replace every `change-me`.
2. Set `DEV_UID` and `DEV_GID` in `.env` to your local user (`id -u`, `id -g`).
3. In each `dockerfiles/*/configs/etc/ssh/` folder, copy `authorized_keys.example` to `authorized_keys` and add your SSH public keys.
4. Run `docker compose up -d --build`.

Full documentation: [documentations/DOCKER.en.md](documentations/DOCKER.en.md).

Licence: [MIT](LICENSE).

## Français

Configuration Docker Compose d'un environnement de développement à plusieurs services : les conteneurs, leur réseau et l'aiguillage entre eux.

| Partie | Rôle |
| --- | --- |
| Porte d'entrée nginx | Le seul port public. Aiguille vers l'interface, les API et le service de socket. |
| Conteneur web | Node.js, sert l'interface utilisateur. |
| Conteneurs de service | Un service par conteneur, chacun avec Node.js et sa propre base de données PostgreSQL. |
| Bus d'événements | Redis, le seul lien entre les services. |

Démarrage rapide :

1. Copier `.env.example` vers `.env` et remplacer chaque `change-me`.
2. Dans `.env`, donner à `DEV_UID` et à `DEV_GID` les valeurs de votre utilisateur local (`id -u`, `id -g`).
3. Dans chaque dossier `dockerfiles/*/configs/etc/ssh/`, copier `authorized_keys.example` vers `authorized_keys` et y ajouter vos clés publiques SSH.
4. Lancer `docker compose up -d --build`.

Documentation complète : [documentations/DOCKER.fr.md](documentations/DOCKER.fr.md).

Licence : [MIT](LICENSE).
