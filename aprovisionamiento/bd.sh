#!/bin/bash


apt-get update -qq


DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync


systemctl stop mariadb


cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << 'EOF'
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

# Galera Provider Configuration
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so

# Galera Cluster Configuration
wsrep_cluster_name="galera_cluster"
wsrep_cluster_address="gcomm://192.168.40.20,192.168.40.30"

# Galera Synchronization Configuration
wsrep_sst_method=rsync

# Galera Node Configuration
wsrep_node_address="192.168.40.20"
wsrep_node_name="db1FJ"
EOF


galera_new_cluster


sleep 15


systemctl status mariadb --no-pager


mysql << 'EOSQL'
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS lamp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para la aplicacion
CREATE USER IF NOT EXISTS 'fj'@'%' IDENTIFIED BY '1234';
GRANT ALL PRIVILEGES ON lamp_db.* TO 'fj'@'%';

-- Usuario para health checks de HAProxy 
CREATE USER IF NOT EXISTS 'haproxy'@'%' IDENTIFIED BY '';
GRANT USAGE ON *.* TO 'haproxy'@'%';

-- Crear usuario root remoto para administracion
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

-- Verificar usuarios creados
SELECT User, Host FROM mysql.user WHERE User IN ('fj', 'haproxy', 'root');
EOSQL


systemctl enable mariadb
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null