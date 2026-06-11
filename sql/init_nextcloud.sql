CREATE DATABASE nextcloud;
CREATE USER 'nextcloud'@'%' IDENTIFIED BY 'mot_de_passe';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';
FLUSH PRIVILEGES;