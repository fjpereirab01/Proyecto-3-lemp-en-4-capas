#!/bin/bash
set -e

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
wsrep_node_address="192.168.40.30"
wsrep_node_name="db2FJ"
EOF


systemctl start mariadb


systemctl status mariadb --no-pager

systemctl enable mariadb


mysql -e "SHOW STATUS LIKE 'wsrep_%';" 2>/dev/null | grep -E "(wsrep_cluster_size|wsrep_cluster_status|wsrep_ready|wsrep_connected)"