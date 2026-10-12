# To do — Docker system

Open work on the Docker system. Tick an item when it is done; remove it once nobody needs the reminder.

French version: [TODO.fr.md](TODO.fr.md).

## To decide

- [ ] **Orchestration container.** It has no role yet. Keep it as a placeholder, or remove it until a process spanning several services needs a coordinator.
- [ ] **Host port.** The overview diagram says "80 / 8080"; the template and the port table say 80. Settle which one the documentation should show.

## Docker system

- [ ] **One source for `authorized_keys`.** The file exists in two folders (`dockerfiles/service` and `dockerfiles/web`); a key must be added to both.
- [ ] **Starting the applications.** Nothing starts by itself: each application is launched by hand from an SSH session. Decide when and how they should start with their container.
- [ ] **HTTPS.** The entry point serves plain HTTP only.
- [ ] **Health checks.** No container declares one, so `docker compose ps` cannot tell a working service from a stopped application.
