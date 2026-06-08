# Déploiement de BookStack avec authentification LDAP
**SAÉ Déploiement d’une application collaborative - Rémi Crochet et Ronan Fisson**

---

## C'est quoi LDAP ?

LDAP (Lightweight Directory Access Protocol) est un protocole qui permet d'accéder à un annuaire centralisé d'utilisateurs. Concrètement, c'est ce qui permet à une entreprise d'avoir un seul compte par personne, utilisable sur toutes les applications internes — c'est ce qu'on appelle le SSO (Single Sign-On).

L'annuaire est organisé comme un arbre (DIT - Directory Information Tree). Chaque utilisateur est une entrée avec des attributs (nom, e-mail, identifiant...) et est identifié par un DN (Distinguished Name) unique, par exemple `uid=einstein,dc=example,dc=com`. Pour interroger l'annuaire, on effectue d'abord un **bind** (authentification), puis une **search** (recherche d'entrées).

LDAP fonctionne traditionnellement sur le port 389 (non chiffré) ou sur le port 636 avec TLS (LDAPS).

---

## Déploiement et Configuration

L'application s'appuie sur deux conteneurs Docker configurés dans notre fichier `docker-compose.yml` : BookStack (l'application web PHP/Laravel) et MariaDB (la base de données). L'intégralité de la configuration, y compris le raccordement LDAP, est gérée via les variables d'environnement de ce fichier.

### 1. Générer la clé applicative (Optionnel si déjà définie)
La variable `APP_KEY` est requise pour le chiffrement de BookStack. Si vous devez en générer une nouvelle, utilisez la commande suivante avant de lancer le déploiement :
```bash
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey

```

Il suffit ensuite de coller cette clé dans la variable `APP_KEY` du fichier `docker-compose.yml`.

### 2. Lancer l'infrastructure

Toute l'infrastructure se lance avec une seule commande :

```bash
docker compose up -d

```

L'interface est ensuite disponible sur [http://localhost:6875](https://www.google.com/search?q=http://localhost:6875).

---

## Raccordement LDAP — Observations et Difficultés rencontrées

Nous avons utilisé le serveur de test public `ldap.forumsys.com` pour valider notre intégration. Pour explorer sa structure en ligne de commande, nous avons utilisé `ldapsearch` :

```bash
ldapsearch \
  -H ldap://ldap.forumsys.com \
  -D "cn=read-only-admin,dc=example,dc=com" \
  -w password \
  -b "dc=example,dc=com" \
  "(objectClass=*)"

```

Nous avons identifié que chaque utilisateur de test expose trois attributs utiles configurables dans BookStack : `uid` (identifiant), `mail` (e-mail) et `cn` (nom complet affiché).

### Difficultés et Solutions

**1. Le filtre de recherche LDAP de l'énoncé est erroné**
Le sujet indique d'utiliser la variable `(uid=${input})`. Cependant, la documentation de BookStack attend la syntaxe `(uid=${user})`. Avec `${input}`, la recherche échouait silencieusement et l'interface affichait "Ces informations ne correspondent à aucun compte". Remplacer cette variable par `${user}` a résolu le problème.

> **Note Docker Compose :** Dans le fichier `.yml`, le symbole `$` doit être doublé pour ne pas être interprété comme une variable système par Docker. Nous avons donc renseigné `LDAP_USER_FILTER=(uid=$${user})`.

**2. Erreur 500 : Problème de cache et variables d'environnement**
Lors du déploiement, nous avons été confrontés à une "Erreur 500" persistante. Les logs des conteneurs ont révélé une erreur `Access denied for user 'database_username'`. L'image Docker de LinuxServer utilise un script d'initialisation pour générer un fichier `.env`. Si ce script échoue ou conserve d'anciens caches, il injecte les variables par défaut de BookStack (dont `database_username`), ignorant ainsi nos variables `DB_USER` et `DB_PASS`.

> **Solution apportée :** Nous avons modifié le `docker-compose.yml` pour injecter directement les variables d'environnement natives de Laravel (`DB_USERNAME` et `DB_PASSWORD`), ce qui court-circuite et remplace le comportement par défaut du fichier `.env`. Nous avons également renommé nos volumes de persistance (`_v2`) pour garantir un déploiement entièrement propre.

**3. Absence d'adresse e-mail pour certains utilisateurs**
BookStack requiert obligatoirement une adresse e-mail pour créer le compte local de l'utilisateur lors de sa première connexion. Sur ce serveur LDAP de test, des utilisateurs comme `tesla` ou `newton` n'ont pas l'attribut `mail` renseigné, ce qui bloque la connexion. Nous avons donc effectué nos tests finaux avec l'utilisateur `einstein`, dont le profil LDAP est complet.

### Résultat final

En se connectant à l'interface web de BookStack avec l'identifiant `einstein` et le mot de passe `password`, l'authentification réussit. BookStack crée alors automatiquement le profil en récupérant les informations de l'annuaire : le nom affiché devient "Albert Einstein" et l'e-mail renseigné est `einstein@ldap.forumsys.com`.