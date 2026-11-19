# Journal de bord — Providence Server

Mis à jour le 19 novembre 2026.

Fiche projet (PDF) : [projet-homeserver.pdf](https://yourir.github.io/projet-homeserver.pdf)

## Le projet en bref

Providence Server est un serveur maison construit presque entièrement avec du matériel récupéré, qui héberge les services numériques privés de la famille : fichiers, messagerie, médiathèque et accès à distance, sans dépendre d'un cloud tiers.

Ce journal retrace le projet étape par étape, du montage matériel à l'état actuel. Les premiers services ont tourné le 2 août 2026 ; l'essentiel de l'infrastructure était en place une quinzaine de jours plus tard. Les dates précédées de « ~ » sont approximatives.

| Élément | Valeur |
| --- | --- |
| Nom d'hôte | providenceserver |
| Système | Debian 13 « Trixie » |
| IP LAN | 192.168.1.50 |
| Domaine privé | providence.mq |
| Nom externe | sous-domaine DuckDNS (DNS dynamique) |
| Utilisateurs | 4 comptes Nextcloud : 3 membres de la famille et un espace partagé |
| Seul port ouvert sur Internet | 51820/UDP (VPN WireGuard) |

## Étape 1 — Récupération du matériel et montage

**Période :** avant août 2026 (date exacte non notée)

La machine a été assemblée en grande partie avec des pièces de réemploi, puis montée soi-même à l'aide de tutoriels en ligne et de vidéos YouTube.

| Composant | Provenance | Usage final |
| --- | --- | --- |
| 2 disques durs de 1 To | Récupérés chez mon père après un grand rangement | RAID1 des données |
| Disque dur de 1,5 To (1,4 To utiles) | Trouvé en déchetterie (ancien disque Windows) | Disque de sauvegarde |
| Barrette de RAM de 4 Go | Trouvée en déchetterie | Mémoire vive |
| Seconde barrette de RAM | Trouvée dans le matériel de mon père | Mémoire vive |
| SSD NVMe 500 Go | Récupéré sur un ordinateur portable | Système |
| Processeur | Récupéré sur la carte mère défectueuse d'une ancienne tour PC | Processeur |
| Carte mère neuve | Achetée en Martinique | — |
| Alimentation | Achetée en Martinique | — |
| Boîtier | Acheté en Martinique | — |

Ce que j'ai appris :

- assembler un PC complet (composants, câblage, alimentation) ;
- naviguer dans un BIOS/UEFI : ordre de démarrage, détection des disques et de la RAM, activation et désactivation des ports SATA (un port a été désactivé pendant la création du RAID, puis réactivé) ;
- vérifier que du matériel d'occasion est fonctionnel avant de lui confier des données.

## Étape 2 — Installation de Debian et organisation du stockage

**Période :** avant août 2026 pour le système et le RAID ; 11 août 2026 pour le disque de sauvegarde

Le stockage est organisé en trois niveaux : système sur SSD, données en RAID1, sauvegardes sur un disque séparé. Le RAID protège d'une panne de disque, mais ne remplace pas une sauvegarde.

1. Installation de Debian 13 sur le SSD NVMe, partitionné en LVM (`/`, `/boot`, `/boot/efi`, swap).
2. Création du RAID1 logiciel `md0` avec mdadm sur les deux disques de 1 To, monté sur `/srv/storage` (environ 930 Go utiles, en miroir).
3. **11 août 2026** : branchement du disque de 1,5 To, effacement complet (`wipefs`), table GPT, partition ext4, montage sur `/mnt/backup`.
4. Auto-montage au démarrage via `/etc/fstab`, par UUID plutôt que par nom de périphérique (`/dev/sdX` peut changer d'un démarrage à l'autre).

| Disque | Taille | Rôle | Point de montage |
| --- | --- | --- | --- |
| nvme0n1 | 476,9 Go | Système (LVM) | `/` |
| sda + sdb | 2 × 931,5 Go | RAID1 des données | `/srv/storage` |
| sdc | 1,4 To | Sauvegardes | `/mnt/backup` |

## Étape 3 — Docker et premiers services

**Période :** avant le 2 août 2026 (Docker, Portainer) → ~8 août 2026

Tous les services tournent en conteneurs Docker, avec une organisation identique pour chacun : il se maintient, se migre et se sauvegarde de la même façon.

- Docker installé depuis le dépôt officiel (plugin `docker compose` inclus).
- Docker lui-même reste sur le SSD (`/var/lib/docker`) ; les données des applications vont sur le RAID.
- Convention : définitions dans `/srv/storage/docker/compose/<service>/`, données dans `/srv/storage/docker/<service>/`.
- Réseau Docker commun `services` : les conteneurs se joignent par leur nom.
- Feuille de route décidée au départ : Nextcloud, puis Matrix, puis Jellyfin ; une messagerie privée plutôt qu'un serveur e-mail ; accès externe par VPN, sans DMZ.

| Date | Service | Rôle | Points notables |
| --- | --- | --- | --- |
| ~7–8 août 2026 | Comptes famille | Nextcloud et Matrix | 4 comptes Nextcloud, quotas 200/200/200/100 Go (ratio 2/7, 2/7, 2/7, 1/7) ; comptes Matrix testés sur 2 téléphones |
| 4–5 août 2026 | Matrix Synapse + PostgreSQL | Messagerie privée | Synapse opérationnel le 5 août ; `server_name` matrix.providence.mq (définitif), inscriptions fermées, comptes créés à la main ; Element desktop et mobile validés |
| 2 août 2026 | Nextcloud + MariaDB + cron | Stockage familial | Version 34.0.2.1 ; tâches de fond par conteneur cron toutes les 5 min |
| avant le 2 août 2026 | Portainer | Gestion des conteneurs par interface web | HTTPS natif sur le port 9443 |

## Étape 4 — DNS privé, reverse proxy et HTTPS interne

**Période :** ~5 août → 9 novembre 2026

Chaque service est désormais joignable par un nom clair en HTTPS (`cloud.providence.mq`, `mail.providence.mq`…) au lieu d'une adresse IP et d'un port.

1. **~5 août 2026 — Technitium DNS** : d'abord installé directement sur le système, puis migré vers Docker pour suivre la convention. Zone privée `providence.mq`, un enregistrement A par service vers 192.168.1.50. Le DHCP du routeur distribue ce DNS à tout le réseau.
2. **5–6 août 2026 — Nginx Proxy Manager** : reçoit le trafic sur 80/443 et le redirige vers le bon conteneur. Règles retenues : on vise le nom du service dans le compose et son port interne. Le 8 août, l'hôte de Technitium est corrigé (port 5380 au lieu de 53).
3. **~12 septembre 2026 — NPM reconstruit** : après la perte du mot de passe administrateur, NPM est réinstallé à zéro et les proxy hosts recréés.
4. **2–3 octobre 2026 — HTTPS interne avec mkcert** : Let's Encrypt ne fonctionne pas sur un domaine privé, donc création d'une autorité de certification maison. Certificat multi-domaines (valable jusqu'au 3 janvier 2029) importé dans NPM, « Force SSL » activé, validation réussie avec `curl`.
5. **Octobre 2026 — Guide pour la famille** : procédure d'installation du certificat racine sur Android et iPhone.
6. **6 novembre 2026** : certificat racine installé sur mon PC Windows.
7. **9 novembre 2026** : certificat racine installé sur une machine Ubuntu (Gamsye-MiniLab) ; réglages Nextcloud derrière le proxy (`overwriteprotocol`, `trusted_proxies`) validés, https://cloud.providence.mq fonctionne sans alerte.

| Sous-domaine | Service |
| --- | --- |
| cloud.providence.mq | Nextcloud |
| mail.providence.mq | Matrix Synapse |
| books.providence.mq | Kavita |
| flix.providence.mq | Jellyfin |
| portainer.providence.mq | Portainer |
| dns.providence.mq | Technitium (administration) |

## Étape 5 — Accès à distance

**Période :** 7 → 8 août 2026

Aucun service n'est exposé directement sur Internet : l'accès depuis l'extérieur passe uniquement par le VPN, soit un seul port ouvert.

- **7–8 août 2026 — DuckDNS** : maintient le nom DuckDNS du serveur à jour avec l'IP de la box. L'image officielle échoue le 7 août ; elle est remplacée le 8 par un script maison dans un conteneur Alpine.
- **8 août 2026 — WireGuard (wg-easy)** : port 51820/UDP redirigé sur la box. Le VPN pousse le DNS Technitium aux clients, donc les noms `*.providence.mq` fonctionnent aussi hors de la maison. L'idée d'une DMZ est écartée (moins sûre).
- **8 août 2026 au soir — Validation** : test réussi en 4G, Wi-Fi coupé, avec accès à Nextcloud.
- **Entre mi-septembre et début octobre 2026** : panne du VPN sur téléphone en 4G, diagnostiquée (`wg show`, DuckDNS, redirection de port) puis résolue.

## Étape 6 — Sauvegardes et sécurisation

**Période :** 11 → ~14 août 2026

Les données sont sauvegardées chaque nuit et la restauration a été testée avec succès ; l'accès d'administration est verrouillé par clé SSH.

**Sauvegardes (restic)**

- **11 août 2026** : création du dépôt `/mnt/backup/restic-repo`, mot de passe généré dans un fichier protégé, premier instantané de 12,5 Gio.
- **11 août 2026** : test de restauration réussi vers `/mnt/backup/restore-test`, et tâche cron quotidienne à 3 h mise en place.
- Contenu : données de tous les services, bibliothèque de livres et fichiers compose. Rétention : 7 sauvegardes journalières et 12 mensuelles.
- **12–13 août 2026** : sauvegardes nocturnes en échec ; `TMPDIR` déplacé sur le disque de sauvegarde, fonctionnement vérifié le lendemain.

**SSH**

- **~13–14 août 2026** : compte dédié `admin` avec sudo, clé ed25519 ; ancien compte supprimé.
- Connexion par clé uniquement, mots de passe et connexion root désactivés.
- Une clé distincte par appareil client. Pour ajouter une deuxième clé, le serveur a été rebranché à un écran (carte graphique) le temps de l'opération.

## Étape 7 — Médiathèque

**Période :** 8 août 2026 (Kavita) ; Jellyfin ensuite (date à préciser)

Le serveur sert aussi de bibliothèque familiale : livres et BD avec Kavita, films et séries avec Jellyfin.

- **8 août 2026 — Kavita** (books.providence.mq) : bibliothèques `/books/romans` (EPUB, PDF) et `/books/comics` (CBZ, CBR). Le 9 novembre, l'adresse renvoie une erreur 502, à diagnostiquer.
- **Jellyfin** (flix.providence.mq) : médias montés en lecture seule depuis `/srv/storage/media/films`, `series` et `musique` ; certificat mkcert dédié importé dans NPM.
- **Chaîne d'automatisation** (en cours de configuration) : Seerr pour les demandes, Radarr et Sonarr, Prowlarr avec FlareSolverr, qBittorrent et Bazarr pour les sous-titres. Téléchargements prévus dans `/srv/storage/media/downloads`.

## Incidents rencontrés et solutions

Chaque problème a été diagnostiqué jusqu'à sa cause avant d'être corrigé.

| Date | Problème | Cause trouvée | Solution |
| --- | --- | --- | --- |
| 9 nov. 2026 | Nextcloud redirigeait encore en http:// derrière le proxy | Nextcloud ignorait qu'il était servi en HTTPS | `overwriteprotocol=https` et `trusted_proxies` |
| date à préciser | Serveur injoignable via le VPN depuis certains Wi-Fi | Le réseau distant utilisait la même plage 192.168.1.0/24 que la maison | Route ciblée 192.168.1.50/32 dans les AllowedIPs des clients, sans renuméroter le réseau |
| date à préciser | Appareils du Wi-Fi mesh sans accès au serveur | Routeurs Strong ATRIA en double NAT (192.168.7.0/24) | Bail DHCP statique pour le mesh et redirection sur le routeur principal ; passage en mode point d'accès toujours prévu |
| ~12 sept. 2026 | Mot de passe administrateur de NPM perdu | Réinitialisation par la base SQLite impossible | NPM réinstallé à zéro, proxy hosts recréés |
| ~12 sept. 2026 | Un PC ne résolvait plus les noms internes | Il utilisait le DNS de la box (192.168.1.1) au lieu de Technitium | Renouvellement du bail DHCP (`ipconfig /release` puis `/renew`) |
| 12–13 août 2026 | Sauvegardes nocturnes en échec | restic utilisait `/tmp`, en RAM (tmpfs) et trop petit | `TMPDIR` sur `/mnt/backup/tmp` |
| 11 août 2026 | Restauration de test : milliers d'erreurs « no space left » | Restauration vers `/tmp`, en RAM | Restauration refaite vers `/mnt/backup/restore-test` : réussie |
| 8 août 2026 | Les noms internes répondaient, mais plus les sites externes | La règle NAT créée par Docker pour le port 53 interceptait aussi le DNS sortant du serveur ; 1.1.1.1 injoignable depuis ce réseau | Exceptions iptables rendues permanentes ; forwarder sur 8.8.8.8 |
| 7–8 août 2026 | DuckDNS ne mettait pas l'IP à jour | L'image linuxserver/duckdns détecte l'IP via Cloudflare, injoignable ici | Script maison avec `ip=` vide : DuckDNS déduit l'IP lui-même |
| 5–6 août 2026 | Erreur 502 sur Nextcloud via NPM | Le service s'appelait `app` dans le compose | Service renommé `nextcloud` ; Portainer en schéma https |
| 4–5 août 2026 | Synapse refusait de démarrer | Paramètres manquants (`report_stats`, `media_store_path`, `registration_shared_secret`) | Paramètres ajoutés à `homeserver.yaml` |
| 2 août 2026 | Nextcloud ne trouvait pas sa base | Faute de frappe dans `MYSQL_HOST` | Nom corrigé |

## Bilan

**Réemploi et environnement.** Les trois disques durs (3,5 To au total), les deux barrettes de RAM, le SSD et le processeur sont des pièces récupérées : chez mon père, en déchetterie, sur un portable ou sur une ancienne tour en panne. Seuls la carte mère, l'alimentation et le boîtier ont été achetés neufs, en Martinique. Du matériel destiné à être jeté fait aujourd'hui tourner un service utilisé par toute la famille, et remplace des abonnements à des clouds commerciaux.

**Compétences acquises.**

- Matériel : assemblage d'un PC, BIOS/UEFI.
- Système : Debian, LVM, RAID mdadm, fstab, cron, gestion des comptes.
- Réseau : DNS, DHCP, NAT et iptables, VPN WireGuard, reverse proxy, adressage.
- Sécurité : certificats et autorité de certification (TLS/PKI), durcissement SSH, réduction de la surface d'exposition.
- Services : Docker Compose, MariaDB, PostgreSQL, sauvegarde et restauration avec restic.
- Utilisateurs : quotas, guide d'installation pour la famille, documentation technique.

## Prochaines étapes

- [ ] Corriger l'erreur 502 sur books.providence.mq (constatée le 9 novembre)
- [ ] Tester mail, books, portainer et dns en HTTPS
- [ ] Installer le certificat racine dans les navigateurs de Gamsye-MiniLab, puis sur les téléphones et PC de la famille
- [ ] Ajouter les clients WireGuard pour le reste de la famille (avec la route 192.168.1.50/32)
- [ ] Passer les routeurs mesh en mode point d'accès
- [ ] Mettre à jour Nextcloud, après une sauvegarde restic à jour
- [ ] Terminer la configuration de la chaîne Jellyfin (Seerr, Radarr, Sonarr, Prowlarr, Bazarr)
- [ ] Installer fail2ban contre la force brute
- [ ] Mettre en place une sauvegarde hors site (règle 3-2-1) et des alertes en cas d'échec
- [ ] Tester GLPI pour l'inventaire et les tickets
- [ ] Décider de l'usage du second PC HP SFF : labo Proxmox ou poste Linux
- [ ] Prévoir le passage à un RAID de 4 To, en gardant le ratio des quotas
