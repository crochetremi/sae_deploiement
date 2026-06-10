# Déploiement de BookStack avec authentification LDAP
**SAÉ Déploiement d’une application collaborative - Rémi Crochet et Ronan Fisson**

---

## 1. C'est quoi LDAP ?

LDAP (Lightweight Directory Access Protocol) est un protocole qui permet d'accéder à un annuaire centralisé d'utilisateurs. Concrètement, c'est ce qui permet à une entreprise d'avoir un seul compte par personne, utilisable sur toutes les applications internes — c'est le principe du SSO (Single Sign-On).

L'annuaire est organisé comme un arbre (DIT - Directory Information Tree). Chaque utilisateur est une entrée avec des attributs (nom, e-mail, identifiant...) et est identifié par un DN (Distinguished Name) unique, par exemple `uid=einstein,dc=iut,dc=org`. Pour interroger l'annuaire, on effectue d'abord un **bind** (authentification de service), puis un **search** (recherche d'entrées), et enfin un nouveau **bind** pour vérifier le mot de passe de l'utilisateur.


## 2. Architecture de notre Déploiement (Infrastructure Locale)

Dans un premier temps, nous avions relié BookStack au serveur de test public `ldap.forumsys.com`. Pour garantir la sécurité, la robustesse et l'autonomie totale de notre application, nous avons finalement fait évoluer notre infrastructure en déployant **notre propre annuaire LDAP local**.

Notre fichier `docker-compose.yml` orchestre désormais 4 conteneurs :

1. **MariaDB** : La base de données relationnelle pour BookStack.
2. **BookStack** : L'application web collaborative (accessible sur le port `8080`).
3. **OpenLDAP** (`osixia/openldap`) : Notre serveur d'annuaire local, configuré sur le domaine `dc=iut,dc=org`.
4. **phpLDAPadmin** (`osixia/phpldapadmin`) : Une interface web d'administration pour gérer notre annuaire facilement (accessible sur le port `8081`).

### Lancer l'infrastructure

Toute l'infrastructure se lance avec une seule commande :

```bash
docker compose up -d

```

* **BookStack :** `http://localhost:8080`
* **phpLDAPadmin :** `http://localhost:8081`



## 3. Administration de l'annuaire et des Utilisateurs

Contrairement au serveur public, notre image locale démarre avec un annuaire vierge. Nous avons pu le peupler de deux manières :

**Méthode 1 : En ligne de commande (CLI)**
Nous avons injecté des utilisateurs (comme Nikola Tesla) directement dans le conteneur via des requêtes LDIF :

```bash
docker exec -i bookstack_ldap ldapadd -x -D "cn=admin,dc=iut,dc=org" -w adminpassword 
<< EOF
dn: uid=tesla,dc=iut,dc=org
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: tesla
sn: Tesla
cn: Nikola Tesla
mail: tesla@iut.org
userPassword: password
EOF
```

**Méthode 2 : Via l'interface graphique (phpLDAPadmin)**
Afin de simuler un environnement de production réaliste, nous avons déployé phpLDAPadmin. En nous connectant avec le compte `cn=admin,dc=iut,dc=org`, nous pouvons désormais lister, modifier et créer de nouveaux utilisateurs (modèle *Generic: User Account*) en quelques clics sans toucher au terminal.

**Remarque :**

On peut d'ailleurs constater l'apparition des utilisateurs qu'on crée en ligne de commandes dans l'interface.

On a par la même occasion pu constater que notre LDAP Local fonctionnait pour l'authentification à Bookstack car il est maintenant possible de se connecter notamment avec le compte `tesla` et celui si obtiendra l'email ̀`tesla@iut.org` qu'on ne pourra modifier.

## 4. Observations et Difficultés rencontrées

**1. Le filtre de recherche LDAP de l'énoncé est erroné**
Le sujet indique d'utiliser la variable `(uid=${input})`. Cependant, la documentation de BookStack attend la syntaxe `(uid=${user})`. Avec `${input}`, la recherche échouait silencieusement. Remplacer cette variable par `${user}` a résolu le problème. De plus, dans le fichier `.yml`, le symbole `$` doit être doublé (`$${user}`) pour ne pas être interprété par Docker.

**2. Erreur 500 : Problème de cache et variables d'environnement**
Lors de nos premiers déploiements, les logs ont révélé une erreur `Access denied for user 'database_username'`. L'image LinuxServer utilise un script pour générer un fichier `.env`. Si ce script conserve d'anciens caches, il injecte les variables par défaut, ignorant nos variables `DB_USER` et `DB_PASS`.
*Solution apportée :* Nous avons injecté directement les variables natives de Laravel (`DB_USERNAME` et `DB_PASSWORD`), ce qui court-circuite le fichier `.env`.

**3. Les "Fantômes" Docker (Ports bloqués et Volumes persistants)**
En migrant vers l'infrastructure locale, nous avons rencontré des erreurs `bind: address already in use` et des connexions "fantômes". Des processus système (le navigateur et le `docker-proxy`) maintenaient les ports ouverts en tâche de fond, et Docker réutilisait silencieusement nos anciennes bases de données incomplètes.
*Solution apportée :* Nous avons forcé la destruction des processus orphelins (commande `kill`), redémarré le service Docker, et renommé les volumes en vanilla pour s'assurer un environnement totalement vierge.