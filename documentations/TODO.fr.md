# À faire — Système Docker

Travaux en suspens sur le système Docker. Cocher un élément quand il est fait; le retirer quand plus personne n'a besoin du rappel.

Version anglaise : [TODO.en.md](TODO.en.md).

## À décider

- [ ] **Conteneur d'orchestration.** Il n'a pas encore de rôle. Le garder en attente, ou le retirer jusqu'à ce qu'un processus qui traverse plusieurs services ait besoin d'un coordonnateur.
- [ ] **Port sur l'hôte.** Le schéma d'ensemble indique « 80 / 8080 »; le gabarit et le tableau des ports indiquent 80. Trancher ce que la documentation doit montrer.

## Système Docker

- [ ] **Une seule source pour `authorized_keys`.** Le fichier existe dans deux dossiers (`dockerfiles/service` et `dockerfiles/web`); une clé doit être ajoutée aux deux.
- [ ] **Démarrage des applications.** Rien ne démarre tout seul : chaque application est lancée à la main, à partir d'une session SSH. Décider quand et comment elles doivent démarrer avec leur conteneur.
- [ ] **HTTPS.** La porte d'entrée ne sert que du HTTP.
- [ ] **Vérifications de santé.** Aucun conteneur n'en déclare : `docker compose ps` ne distingue pas un service qui fonctionne d'une application arrêtée.
