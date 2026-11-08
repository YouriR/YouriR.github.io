# Journal de bord — Lab Active Directory

Lab Windows Server de **BiznesRentab**, PME fictive de 50 salariés. Journal tenu séance par séance : tâches, commandes, difficultés et solutions.

Scripts utilisés : [`scripts/`](scripts/)

## Fiche projet

Objectif : monter un domaine Active Directory fonctionnel sur une VM Windows Server, du contrôleur de domaine au poste de travail.

| Élément | Valeur |
| --- | --- |
| Hyperviseur | VirtualBox (réseau NAT « LabAD » 10.0.2.0/24) |
| OS du contrôleur de domaine | Windows Server 2019 Standard (Desktop Experience), interface en anglais |
| Nom de la VM | SRV-DC01 |
| Adresse IP (fixe) / masque / passerelle | 10.0.2.10 / 255.255.255.0 (/24) / 10.0.2.1 |
| DNS | 127.0.0.1 (le serveur lui-même), redirecteur 8.8.8.8 ; zone inverse 2.0.10.in-addr.arpa |
| Nom de domaine (FQDN) | ad.biznesrentab.mq |
| Nom NetBIOS | BIZNESRENTAB |
| Postes clients | PC-WIN11-01 (Windows 11 Enterprise, adresse par DHCP, OU Ordinateurs/Postes) |
| Rôles installés | AD DS, DNS, DHCP (étendue 10.0.2.100–200) |

## Entrées

### Séance n°1 — Première installation

Objectif de la séance : préparer le futur contrôleur de domaine.

#### Tâches effectuées

- [x] Installation d'une première VM Windows Server
- [x] Configuration d'une adresse IP fixe
- [x] Renommage du serveur

#### Résultat

Cette première VM a été abandonnée (mot de passe administrateur perdu, édition Server Core installée par erreur) : le serveur a été réinstallé proprement à la séance 2, où AD DS a été déployé.

#### Sources consultées

- Tutoriels Dade Academy

### Séance n°2 — 04/11/2026

Objectif de la séance : réinstaller le serveur et poser les fondations du domaine BiznesRentab.

#### Tâches effectuées

- [x] Réinstallation de Windows Server 2019 Standard (Desktop Experience)
- [x] Réseau NAT VirtualBox « LabAD » 10.0.2.0/24, DHCP VirtualBox désactivé
- [x] IP fixe 10.0.2.10, nom SRV-DC01, fuseau UTC−4
- [x] Installation d'AD DS et promotion : forêt ad.biznesrentab.mq (NetBIOS BIZNESRENTAB)
- [x] Vérification du DNS : redirecteur, résolution interne et externe, `dcdiag`
- [x] Arborescence des OU dans la console ADUC
- [x] 9 groupes globaux de sécurité, imbrication des équipes dans `GG_Pole-Technique`
- [x] Import de 50 utilisateurs avec `Creer-Utilisateurs.ps1` et un CSV
- [x] Comptes admin séparés (`adm.dthalmensy` Domain Admin, `adm.alucien` helpdesk) et délégation de réinitialisation des mots de passe

#### Commandes et configurations

| Commande / action | Rôle | Résultat |
| --- | --- | --- |
| `New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.2.10 -PrefixLength 24 -DefaultGateway 10.0.2.1` | IP fixe du serveur | OK |
| `Rename-Computer -NewName "SRV-DC01" -Restart` | Nom du serveur | OK |
| `Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools` | Installer le rôle AD DS | Success |
| `Test-ADDSForestInstallation` puis `Install-ADDSForest -DomainName "ad.biznesrentab.mq" -DomainNetbiosName "BIZNESRENTAB" -InstallDns` | Simuler puis créer la forêt | Serveur promu, DNS 127.0.0.1 |
| `Get-DnsServerForwarder`, `Resolve-DnsName`, `dcdiag /q` | Vérifier DNS et santé du DC | OK |
| Script `Creer-Utilisateurs.ps1` | Créer 50 comptes depuis un CSV | 50 comptes créés |
| `Set-ADAccountPassword -Reset -Credential $Cred` | Tester la délégation helpdesk | Réussi sur un salarié, « Access is denied » sur un compte admin |

#### Difficultés rencontrées

| Problème (symptôme, message d'erreur) | Cause identifiée | Solution appliquée | Résolu ? |
| --- | --- | --- | --- |
| Mot de passe administrateur de l'ancienne VM oublié | VM non utilisée depuis longtemps | Réinstallation complète | Oui |
| « The password on this account cannot be changed at this time » | Message générique : mot de passe refusé par une règle | Autre mot de passe | Oui |
| Pas d'interface graphique après l'installation | Édition Server Core choisie au lieu de Desktop Experience | Réinstallation (GUI non ajoutable après coup) | Oui |

#### Sources consultées

- Documentation Microsoft sur AD DS et les modules PowerShell ActiveDirectory

#### Ce que j'ai appris

- Les conteneurs Users et Computers ne sont pas des OU : on ne peut pas y lier de GPO
- Lire un Distinguished Name de droite à gauche
- Méthode AGDLP : groupes globaux pour les personnes, domaine local pour les ressources
- Un script doit être réexécutable sans doublon et ne jamais contenir de mot de passe
- Moindre privilège : compte admin séparé et délégation ciblée plutôt que Domain Admins pour tous

#### Prochaines étapes

- [x] Stratégies de groupe (fait à la séance 3)

Captures d'écran prises : arborescence des OU, groupes et membres de GG\_Pole-Technique, OU remplie et fiche utilisateur, test de délégation

### Séance n°3 — 05/11/2026

Objectif de la séance : stratégies de groupe, DHCP, poste client Windows 11 et tests par profil d'utilisateur.

#### Tâches effectuées

- [x] Default Domain Policy : mots de passe 12 caractères + complexité, historique 24, pas d'expiration, verrouillage 5 échecs / 15 min
- [x] GPO `U_Restrictions-Bureautique` liée à Direction, Comptabilite, RH, Commercial
- [x] GPO `U_Pole-Technique` liée à Pole-Technique (scripts RemoteSigned)
- [x] GPO `C_Securite-Postes` liée à Postes et Domain Controllers (bannière, verrouillage 15 min, journalisation PowerShell, exécution USB bloquée)
- [x] Zone DNS inverse 2.0.10.in-addr.arpa
- [x] Rôle DHCP : autorisation dans AD, étendue LAN-Postes 10.0.2.100–200, options 003 / 006 / 015
- [x] VM Windows 11 Enterprise PC-WIN11-01 jointe au domaine dans l'OU Postes
- [x] Tests avec gerard.lajan (Direction) et steeve.zobda (Pôle Technique)
- [x] Faille PowerShell via le Terminal détectée et corrigée
- [x] Partages de fichiers : script Creer-Partages.ps1 (7 dossiers, groupes DL\_Partage-\*\_RW/\_RO, NTFS héritage coupé, partage \\\\SRV-DC01\\Partages avec ABE)
- [x] GPO U\_Lecteur-Reseau (préférences, lecteur S:) liée à l'OU Utilisateurs ; tests : Compta voit Comptabilite + Commun, Direction lit la compta sans pouvoir écrire, Pôle Technique voit Technique + Commun

#### Commandes et configurations

| Commande / action | Rôle | Résultat |
| --- | --- | --- |
| `Get-ADDefaultDomainPasswordPolicy` | Vérifier la stratégie de mots de passe du domaine | Valeurs conformes |
| `Get-GPInheritance -Target "OU=..."` | Voir les GPO liées et héritées d'une OU | Liaisons et ordre LSDOU corrects |
| `Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-PowerShell/Operational"; Id=4104}` | Contrôler la journalisation PowerShell | Événements 4104 présents |
| `Add-DnsServerPrimaryZone -NetworkId "10.0.2.0/24" -ReplicationScope "Forest"` | Créer la zone DNS inverse | `Resolve-DnsName 10.0.2.10` renvoie SRV-DC01 |
| `Install-WindowsFeature DHCP` + `Add-DhcpServerInDC` | Installer et autoriser le DHCP | Serveur autorisé |
| `Add-DhcpServerv4Scope` + `Set-DhcpServerv4OptionValue` | Créer l'étendue et ses options | Le poste reçoit IP, passerelle, DNS et suffixe |
| `Add-Computer -DomainName ... -OUPath ... -Credential BIZNESRENTAB\adm.dthalmensy` | Joindre le poste au domaine dans l'OU Postes | Jonction réussie |
| `Rename-Computer -NewName ... -DomainCredential ...` | Renommer un poste déjà joint | PC-WIN11-01 |
| `Get-ExecutionPolicy -List` | Vérifier la stratégie d'exécution imposée | `UserPolicy : RemoteSigned` |
| `gpresult /r /scope user` | Voir les GPO réellement appliquées | U\_Pole-Technique seule pour Steeve |
| Script Creer-Partages.ps1 (New-ADGroup -GroupScope DomainLocal, icacls /inheritance:r, New-SmbShare -FolderEnumerationMode AccessBased) | Créer les dossiers, les groupes DL\_, les permissions NTFS et le partage | 7 dossiers, \\\\SRV-DC01\\Partages avec ABE |
| GPO U\_Lecteur-Reseau (préférences de lecteur, S:) | Mapper le lecteur réseau à la connexion | Chaque service ne voit que ses dossiers + Commun |

#### Difficultés rencontrées

| Problème (symptôme, message d'erreur) | Cause identifiée | Solution appliquée | Résolu ? |
| --- | --- | --- | --- |
| « Removable Disks: Deny execute access » introuvable côté User Configuration | Le paramètre n'existe que côté Computer Configuration | Déplacé dans `C_Securite-Postes` | Oui |
| « No bootable device found » au premier démarrage de la VM Windows 11 | Démarrage sur l'ISO non déclenché | Vérification ISO et ordre de démarrage, redémarrage | Oui |
| `Add-Computer` : « The directory service is busy », renommage échoué | Renommage envoyé juste après la création de l'objet ordinateur | Redémarrage puis `Rename-Computer -DomainCredential` | Oui |
| PowerShell accessible à la Direction via le Terminal | Le blocage par nom de fichier ne couvrait pas `WindowsTerminal.exe` | Ajout de `WindowsTerminal.exe` et `wt.exe` à la liste bloquée | Oui (limite : AppLocker) |
| Mot de passe initial des utilisateurs oublié | Saisi au lancement du script, non noté | Réinitialisation du compte dans ADUC | Oui |
| Heure du poste décalée (00:38 au lieu de 19:44) | Fuseau horaire par défaut de l'installation | `Set-TimeZone` à faire sur le poste | Non |

#### Sources consultées

- Recommandation de la CNIL sur les mots de passe (2022)
- Documentation Microsoft sur les stratégies de groupe et le DHCP

#### Ce que j'ai appris

- Une GPO a une partie Ordinateur et une partie Utilisateur ; elle ne fait rien tant qu'elle n'est pas liée, et s'applique dans l'ordre LSDOU
- La stratégie de mots de passe des comptes AD doit être liée au domaine, pas à une OU
- « Don't run specified Windows applications » ne bloque que les programmes lancés par l'Explorateur : AppLocker est la vraie solution
- Un serveur DHCP doit être autorisé dans AD pour distribuer des adresses
- `-OUPath` à la jonction évite que l'ordinateur tombe dans le conteneur Computers, où aucune GPO ne s'applique
- `gpresult /r` montre ce qui s'applique réellement, groupes imbriqués compris
- AGDLP en pratique : les groupes globaux (GG\_) entrent dans des groupes domaine local (DL\_), et seuls les DL\_ reçoivent les permissions NTFS
- L'énumération basée sur l'accès (ABE) masque les dossiers auxquels l'utilisateur n'a pas accès
- Couper l'héritage NTFS (icacls /inheritance:r) pour que chaque dossier n'ait que les droits voulus

#### Prochaines étapes

- [ ] Corriger le fuseau horaire du poste (`Set-TimeZone`)
- [x] Partages de fichiers par service : groupes DL\_, permissions NTFS, lecteurs mappés par GPO
- [ ] Scénarios d'arrivée et de départ d'un salarié
- [ ] Déclarer le sous-réseau 10.0.2.0/24 dans Sites and Services
- [ ] Bonus : AppLocker, `ms-DS-MachineAccountQuota` à 0
- [ ] Documentation et scripts sur GitHub

Captures d'écran prises : Password Policy, `Get-ADDefaultDomainPasswordPolicy`, rapport Settings des GPO, bannière, événement 4104, étendue DHCP, `ipconfig /all`, objet PC-WIN11-01 dans ADUC, messages de blocage (Gerard), `Get-ExecutionPolicy -List`, script exécuté, `gpresult` (Steeve)

## Bilan des compétences

| Compétence | Séance(s) | Preuve (capture, script, extrait) |
| --- | --- | --- |
| Installation et configuration de Windows Server | 1, 2 |  |
| Déploiement AD DS et promotion en contrôleur de domaine | 2 |  |
| DNS intégré à AD | 2, 3 |  |
| DHCP | 3 | Capture de l'étendue DHCP, ipconfig /all du poste |
| Organisation en OU, utilisateurs et groupes | 2 | Capture de l'arborescence des OU, membres de GG\_Pole-Technique |
| Stratégies de groupe (GPO) | 3 | gpresult de Steeve, messages de blocage de Gérard, rapports Settings des GPO |
| Jonction d'un poste client au domaine | 3 | Objet PC-WIN11-01 dans l'OU Postes, bannière de connexion |
| Automatisation PowerShell | 2, 3 | Scripts Creer-Utilisateurs.ps1 (+ CSV des 50 salariés) et Creer-Partages.ps1 |
| Partages de fichiers (AGDLP, NTFS, ABE, lecteur mappé par GPO) | 3 | Script Creer-Partages.ps1, tests d'accès par service |
