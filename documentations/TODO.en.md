# To do — Docker system

Open work on the Docker system. Tick an item when it is done; remove it once nobody needs the reminder.

French version: [TODO.fr.md](TODO.fr.md).

## To decide

- [ ] **Orchestration container.** It has no role yet. Keep it as a placeholder, or remove it until a process spanning several services needs a coordinator.
- [ ] **Host port.** The overview diagram says "80 / 8080"; the template and the port table say 80. Settle which one the documentation should show.
- [ ] **Where the Docker pages live.** They are in this repository, so the sessions inside the containers cannot read them. Keep them here, or move them to the shared documentation repository.

## Repositories

- [ ] **Shared documentation repository.** Created locally in `volumes/documentations`, still empty. Write its first pages and give it a remote.
- [ ] **Service repositories.** Create one repository per service and one for the UI, each in its `volumes/<service>/workspaces` folder.
- [ ] **Access keys.** Decide between one deploy key per repository and one key on the account, then set up the SSH client on the Docker host accordingly.
- [ ] **History of this repository.** Collapse the first commits into a single initial commit.

## Docker system

- [ ] **One source for `authorized_keys`.** The file exists in two folders (`dockerfiles/service` and `dockerfiles/web`); a key must be added to both.
- [ ] **Starting the applications.** Nothing starts by itself: each application is launched by hand from an SSH session. Decide when and how they should start with their container.
- [ ] **HTTPS.** The entry point serves plain HTTP only.
- [ ] **Health checks.** No container declares one, so `docker compose ps` cannot tell a working service from a stopped application.

## Services

- [ ] **Base of each service.** Install Fastify (or socket.io for notification) and the Redis client in each workspace, listening on `0.0.0.0` and on the port given by `API_PORT` or `SOCKET_PORT`.
- [ ] **UI.** Choose the dev server, make it listen on `0.0.0.0:4200`, and allow the host name used to browse.
