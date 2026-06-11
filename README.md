# Déploiement de BookStack et Nextcloud avec authentification SSO LDAP

**SAÉ Déploiement d’une application collaborative - Rémi Crochet et Ronan Fisson**

---

## 1. C'est quoi LDAP ?

LDAP (Lightweight Directory Access Protocol) est un protocole qui permet d'accéder à un annuaire centralisé d'utilisateurs. Concrètement, c'est ce qui permet à une entreprise d'avoir un seul compte par personne, utilisable sur toutes les applications internes — c'est le principe du SSO (Single Sign-On).

L'annuaire est organisé comme un arbre (DIT - Directory Information Tree). Chaque utilisateur est une entrée avec des attributs (nom, e-mail, identifiant...) et est identifié par un DN (Distinguished Name) unique, par exemple `uid=einstein,ou=users,dc=mongroupe,dc=local`. Pour interroger l'annuaire, on effectue d'abord un **bind** (authentification de service), puis un **search** (recherche d'entrées), et enfin un nouveau **bind** pour vérifier le mot de passe de l'utilisateur.

---

## 2. Architecture du Déploiement (Infrastructure Locale & Sécurisée)

Dans un premier temps, nous avions relié BookStack au serveur de test public `ldap.forumsys.com`. Pour garantir la sécurité, la robustesse et l'autonomie totale de notre application, nous avons fait évoluer notre infrastructure en déployant **notre propre annuaire LDAP local**, un service de Cloud (Nextcloud), et un **Reverse Proxy (Nginx)** pour sécuriser les échanges.

Nous avons structuré notre projet de manière professionnelle avec des dossiers dédiés :

```text
.
├── docker-compose.yml
├── nginx/
│   ├── certs/
│   │   ├── selfsigned.crt
│   │   └── selfsigned.key
│   └── nginx.conf
├── script/
│   ├── start.sh
│   └── structure.ldif
└── sql/
    └── init_nextcloud.sql

```

Notre infrastructure orchestre désormais **6 conteneurs interconnectés** :

1. **MariaDB** : La base de données relationnelle mutualisée pour BookStack et Nextcloud (Réseau interne).
2. **OpenLDAP** : Notre serveur d'annuaire local, configuré sur `dc=mongroupe,dc=local`.
3. **BookStack** : L'application web collaborative (Isolée sur le réseau interne).
4. **Nextcloud** : Le service de stockage et de partage de fichiers (Isolé sur le réseau interne).
5. **phpLDAPadmin** : L'interface web d'administration de l'annuaire (Isolée sur le réseau interne).
6. **Nginx (Reverse Proxy)** : Le point d'entrée public de notre serveur.

---

## 3. Reverse Proxy, Sécurité et HTTPS (Nginx)

Afin de simuler un environnement de production réaliste, nous avons déployé un proxy inverse Nginx. Son rôle est de regrouper nos services derrière un point d'entrée unique et de chiffrer les communications (HTTPS).

* **Génération des certificats SSL :** En l'absence de domaine public, nous avons généré nos propres certificats auto-signés (`openssl req -x509...`) stockés dans le dossier `nginx/certs/`.
* **Routage et Virtual Hosts :** Le fichier `nginx.conf` analyse l'URL demandée par l'utilisateur et redirige le trafic vers le bon conteneur Docker de manière transparente. Nginx force également la redirection du trafic HTTP (port 80) vers HTTPS (port 443).
* **Configuration applicative :** Les applications ont été reconfigurées pour être "conscientes" du proxy. BookStack utilise la variable `APP_URL=https://bookstack.mongroupe.local`, et Nextcloud s'appuie sur les variables `OVERWRITEPROTOCOL` et `OVERWRITEHOST` pour générer des liens sécurisés.
* **Résolution DNS Locale :** Puisque nos noms de domaine (`.local`) n'existent pas sur Internet, nous avons modifié le fichier `/etc/hosts` de la machine cliente pour assurer la résolution locale :
`127.0.0.1 bookstack.mongroupe.local nextcloud.mongroupe.local phpldapadmin.mongroupe.local`

**Accès aux services :**

* `https://bookstack.mongroupe.local`
* `https://nextcloud.mongroupe.local`
* `https://phpldapadmin.mongroupe.local` 

---

## 4. Déploiement et Automatisation de l'Infrastructure

Pour garantir un déploiement propre et reproductible sans intervention manuelle à l'intérieur des conteneurs, nous avons automatisé la création des bases de données et la population de l'annuaire LDAP.

### Automatisation de la Base de Données

Le conteneur MariaDB crée nativement la base `bookstackapp` grâce aux variables d'environnement. Pour Nextcloud, nous avons monté le fichier `sql/init_nextcloud.sql` dans le dossier spécial `/docker-entrypoint-initdb.d/` de MariaDB. Lors du premier lancement, MariaDB lit ce script et crée automatiquement la base et l'utilisateur `nextcloud`.

### Automatisation du LDAP et Lancement

Plutôt que de taper une simple commande `docker compose up`, nous avons créé le script d'initialisation `script/start.sh`. Ce script se charge d'exécuter la commande `ldapadd` depuis la machine hôte pour injecter automatiquement notre fichier `structure.ldif`. Ce fichier crée l'arborescence (`ou=users`, `ou=groups`) et génère 3 scientifiques de test (Einstein, Curie, Turing).

### Lancer l'infrastructure (Premier démarrage)

```bash
cd script
chmod +x start.sh
./start.sh

```

---

## 5. Intégration LDAP dans Nextcloud

L'intégration de l'annuaire dans Nextcloud s'effectue via son interface d'administration, en paramétrant finement les filtres de recherche pour correspondre à notre structure `ou=users,dc=mongroupe,dc=local`.
Nous avons ajouté un dossier `ldap_nextcloud_images` qui permet de visualiser quelle est exactement la configuration que nous avons utilisée pour lier LDAP.

* **Filtre des utilisateurs :** `(&(objectclass=inetOrgPerson))` (Permet à Nextcloud de compter le nombre d'utilisateurs humains valides dans l'annuaire).
* **Filtre de connexion :** `(&(&(objectclass=inetOrgPerson))(uid=%uid))` (Permet de faire correspondre la saisie de l'utilisateur avec l'attribut `uid` du LDAP).
* **Attribut Nom d'utilisateur interne :** Forcé sur `uid` dans les paramètres avancés pour éviter que Nextcloud ne génère des dossiers avec des identifiants (UUID) illisibles.

---

## 6. Observations et Difficultés rencontrées

**1. Le filtre de recherche LDAP BookStack erroné**
Le sujet indique d'utiliser la variable `(uid=${input})`. Cependant, la documentation de BookStack attend la syntaxe `(uid=${user})`. Remplacer cette variable par `${user}` a résolu le problème (en n'oubliant pas de doubler le symbole `$${user}` dans le `.yml` pour Docker).

**2. Erreur 500 : Problème de cache de l'image LinuxServer**
L'image BookStack utilise un script pour générer un fichier `.env`. S'il conserve d'anciens caches, il injecte des variables par défaut corrompues (`Access denied for user 'database_username'`). Nous avons contourné le problème en injectant directement les variables natives de Laravel (`DB_USERNAME` et `DB_PASSWORD`), court-circuitant ainsi le fichier `.env`.

**3. Les "Fantômes" Docker (Ports bloqués)**
En migrant vers l'infrastructure locale, nous avons rencontré des erreurs `bind: address already in use`. Des processus système orphelins (le `docker-proxy`) maintenaient les ports ouverts en tâche de fond. Nous avons dû forcer la destruction des processus via la commande `kill` et renommer nos volumes (`_vanilla`) pour garantir un environnement vierge.

**4. Le ciblage de la base utilisateur dans Nextcloud**
Lors de la configuration LDAP dans l'interface de Nextcloud, bien que la connexion au serveur soit établie, l'application ne trouvait initialement aucun utilisateur.
*Solution apportée :* Au lieu de laisser Nextcloud chercher à la racine globale de l'annuaire, nous avons explicitement renseigné le chemin de notre unité organisationnelle dans le paramètre du DN de base utilisateur : `ou=users,dc=mongroupe,dc=local`. Ce ciblage précis a immédiatement permis au système de localiser et de valider nos comptes de test.

**5. Résolution DNS locale et sécurité des navigateurs (DoH)**
Lors de la configuration de Nginx, les domaines virtuels `.local` définis dans le fichier `/etc/hosts` de la machine n'étaient pas toujours reconnus par les navigateurs web, renvoyant une erreur "Adresse introuvable" malgré un terminal réussissant le "ping".
*Solution apportée :* Nous avons identifié que la fonctionnalité de sécurité "DNS over HTTPS" (DoH) de Firefox contournait le fichier `hosts` local pour interroger directement des serveurs DNS publics. Désactiver cette option dans le navigateur a permis de rétablir le routage Nginx local.