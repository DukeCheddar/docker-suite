# À faire — Système Docker

Travaux en suspens sur le système Docker. Cocher un élément quand il est fait; le retirer quand plus personne n'a besoin du rappel.

Version anglaise : [TODO.en.md](TODO.en.md).

## À décider

- [ ] **Conteneur d'orchestration.** Il n'a pas encore de rôle. Le garder en attente, ou le retirer jusqu'à ce qu'un processus qui traverse plusieurs services ait besoin d'un coordonnateur.
- [ ] **Port sur l'hôte.** Le schéma d'ensemble indique « 80 / 8080 »; le gabarit et le tableau des ports indiquent 80. Trancher ce que la documentation doit montrer.
- [ ] **Emplacement des pages Docker.** Elles sont dans ce dépôt : les sessions à l'intérieur des conteneurs ne peuvent pas les lire. Les garder ici, ou les déplacer dans le dépôt de la documentation partagée.

## Dépôts

- [ ] **Dépôt de la documentation partagée.** Créé localement dans `volumes/documentations`, encore vide. Écrire ses premières pages et lui donner un dépôt distant.
- [ ] **Dépôts des services.** Créer un dépôt par service et un pour l'interface, chacun dans son dossier `volumes/<service>/workspaces`.
- [ ] **Clés d'accès.** Choisir entre une clé de déploiement par dépôt et une seule clé sur le compte, puis configurer le client SSH de l'hôte Docker en conséquence.
- [ ] **Historique de ce dépôt.** Regrouper les premiers commits en un seul commit initial.

## Système Docker

- [ ] **Une seule source pour `authorized_keys`.** Le fichier existe dans deux dossiers (`dockerfiles/service` et `dockerfiles/web`); une clé doit être ajoutée aux deux.
- [ ] **Démarrage des applications.** Rien ne démarre tout seul : chaque application est lancée à la main, à partir d'une session SSH. Décider quand et comment elles doivent démarrer avec leur conteneur.
- [ ] **HTTPS.** La porte d'entrée ne sert que du HTTP.
- [ ] **Vérifications de santé.** Aucun conteneur n'en déclare : `docker compose ps` ne distingue pas un service qui fonctionne d'une application arrêtée.

## Services

- [ ] **Base de chaque service.** Installer Fastify (ou socket.io pour notification) et le client Redis dans chaque espace de travail, à l'écoute sur `0.0.0.0` et sur le port donné par `API_PORT` ou `SOCKET_PORT`.
- [ ] **Interface.** Choisir le serveur de développement, le faire écouter sur `0.0.0.0:4200` et autoriser le nom d'hôte utilisé pour naviguer.
