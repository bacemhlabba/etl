# Projet ETL et Visualisation

Ce projet est composé de deux parties principales : un processus ETL (Extract, Transform, Load) construit avec SQL Server Integration Services (SSIS) et une application web de visualisation de données construite en Python.

## Structure du Projet

Le projet est organisé comme suit :

- `bacem_amal/` : Contient le projet SSIS pour l'ETL.
- `viz_app/` : Contient l'application de visualisation de données en Python.
- `create_views_for_viz.sql` : Script SQL pour créer les vues nécessaires à l'application de visualisation.
- `bacem_amal.sln` : Fichier de solution Visual Studio pour le projet ETL.

## Partie ETL (bacem_amal)

Cette partie du projet est responsable de l'extraction des données de la source, de leur transformation et de leur chargement dans un entrepôt de données.

### Contenu

- **Fichiers `.dtsx`** : Ce sont les packages SSIS qui définissent les flux de données et les tâches ETL (par exemple, `Dim CustomerETL.dtsx`, `Fact table sales.dtsx`).
- **Fichiers `.sql`** : Scripts SQL pour diverses opérations de base de données comme la création de tables (`Create_Dim_DeliveryMethod_Table.sql`), la correction de données (`FIX_DeliveryMethod_DuplicateKey.sql`) et les procédures stockées (`usp_MergeDimDeliveryMethod.sql`).
- **Fichiers `.conmgr`** : Gestionnaires de connexion pour les sources et destinations de données.
- **`bacem_amal.dtproj`** : Le fichier de projet SSIS.

### Comment l'utiliser

1.  Ouvrez `bacem_amal.sln` avec Visual Studio avec l'extension SQL Server Data Tools (SSDT).
2.  Configurez les gestionnaires de connexion dans `Source Dataset.conmgr` et `Destination Dataset.conmgr` pour pointer vers vos bases de données source et de destination.
3.  Déployez le projet sur une instance de SQL Server avec Integration Services.
4.  Exécutez les packages SSIS pour peupler l'entrepôt de données.

## Application de Visualisation (viz_app)

C'est une application web, probablement basée sur Flask ou Dash, qui affiche les données de l'entrepôt de données.

### Contenu

- **`app.py`** : Le fichier principal de l'application web.
- **`data_loader.py`** : Gère probablement la connexion à la base de données et la récupération des données.
- **`config.py`** : Fichier de configuration pour l'application (par exemple, les informations d'identification de la base de données).
- **`requirements.txt`** : Liste des dépendances Python pour l'application.

### Comment l'exécuter

1.  Assurez-vous que Python est installé.
2.  Naviguez vers le répertoire `viz_app`.
3.  Installez les dépendances :
    ```bash
    pip install -r requirements.txt
    ```
4.  Configurez la connexion à la base de données dans `config.py`.
5.  Exécutez le script `create_views_for_viz.sql` sur votre entrepôt de données pour créer les vues nécessaires.
6.  Lancez l'application :
    ```bash
    python app.py
    ```
7.  Ouvrez votre navigateur et allez à l'adresse fournie (généralement `http://127.0.0.1:5000`).

## Base de Données

Avant d'exécuter l'ETL, vous devez avoir une base de données de destination. Les scripts SQL dans le dossier `bacem_amal` vous aideront à créer les tables nécessaires. Le script `create_views_for_viz.sql` doit être exécuté après que l'ETL a peuplé les tables pour que l'application de visualisation fonctionne.
