# Proyecto-3-lemp-en-4-capas
Esta es la tercera practica de implantación web. Consiste en un entorno vagrant constituido por 7 maquinas donde un servidor nginx se conectara via buscador de internet a el cluster de mariadb. 

## Estructura
La estructura consiste en lo siguiente:
```
                              ┌──────────────────────┐
                              │        USUARIO        │
                              │   Navegador / HTTP    │
                              └───────────┬──────────┘
                                          │ 8080 → 80
                                          ▼
                    ┌────────────────────────────────────┐
                    │        BALANCEADOR NGINX            │
                    │          balanceadorFJ              │
                    │   192.168.10.10 / 192.168.20.30     │
                    └───────────────┬───────────────┬────┘
                                    │               │
                                    ▼               ▼
        ┌──────────────────────────────┐   ┌──────────────────────────────┐
        │        SERVER WEB 1           │   │        SERVER WEB 2           │
        │        serverweb1FJ           │   │        serverweb2FJ           │
        │        192.168.20.20          │   │        192.168.20.30          │
        └───────────────┬──────────────┘   └───────────────┬──────────────┘
                        │                                  │
                        │  PHP / Archivos compartidos     │
                        ▼                                  ▼
               ┌──────────────────────────────────────────────────┐
               │              SERVIDOR NFS + PHP-FPM               │
               │                   serverNFSFJ                     │
               │        192.168.20.10 / 192.168.30.20               │
               └───────────────────────┬──────────────────────────┘
                                       │
                                       │ MySQL
                                       ▼
                   ┌────────────────────────────────────┐
                   │        PROXY BASE DE DATOS           │
                   │           HAProxy BD                │
                   │             proxyBDFJ               │
                   │     192.168.30.10 / 192.168.40.10   │
                   └───────────────┬───────────────┬────┘
                                   │               │
                                   ▼               ▼
        ┌──────────────────────────────┐   ┌──────────────────────────────┐
        │     MARIADB GALERA NODO 1     │   │     MARIADB GALERA NODO 2     │
        │            db1FJ              │   │            db2FJ              │
        │        192.168.40.20          │   │        192.168.40.20          │
        └──────────────────────────────┘   └──────────────────────────────┘

```

## Vagrantfile
Este es el vagrantfile que permitira montar toda la estructura al hacer vagrant up en la terminal:
```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"

  config.vm.define "balanceadorFJ" do |balanceadorFJ|
    balanceadorFJ.vm.hostname = "balanceadorFJ"
    balanceadorFJ.vm.network "private_network", ip: "192.168.10.10"
    balanceadorFJ.vm.network "private_network", ip: "192.168.20.30"
    balanceadorFJ.vm.network "forwarded_port", guest: 80, host: 8080
    balanceadorFJ.vm.provision "shell", path: "aprovisionamiento/bl.sh"
  end
    config.vm.define "serverweb1FJ" do |web1FJ|
    web1FJ.vm.hostname = "serverweb1FJ"
    web1FJ.vm.network "private_network", ip: "192.168.20.20"
    web1FJ.vm.provision "shell", path: "aprovisionamiento/web.sh"
  end
    config.vm.define "serverweb2FJ" do |web2FJ|
    web2FJ.vm.hostname = "serverweb2FJ"
    web2FJ.vm.network "private_network", ip: "192.168.20.30"
    web2FJ.vm.provision "shell", path: "aprovisionamiento/web2.sh"
  end
    config.vm.define "serverNFSFJ" do |serverNFSFJ|
    serverNFSFJ.vm.hostname = "serverNFSFJ"
    serverNFSFJ.vm.network "private_network", ip: "192.168.20.10"
    serverNFSFJ.vm.network "private_network", ip: "192.168.30.20"
    serverNFSFJ.vm.provision "shell", path: "aprovisionamiento/nfs.sh"
  end
    config.vm.define "proxyBDFJ" do |proxyBDFJ|
    proxyBDFJ.vm.hostname = "proxyBDFJ"
    proxyBDFJ.vm.network "private_network", ip: "192.168.30.10"
    proxyBDFJ.vm.network "private_network", ip: "192.168.40.10"
    proxyBDFJ.vm.provision "shell", path: "aprovisionamiento/proxybd.sh"
  end
    config.vm.define "db2FJ" do |db2FJ|
    db2FJ.vm.hostname = "db2FJ"
    db2FJ.vm.network "private_network", ip: "192.168.40.30"
    db2FJ.vm.provision "shell", path: "aprovisionamiento/bd2.sh"
  end
  config.vm.define "db1FJ" do |db1FJ|
    db1FJ.vm.hostname = "db1FJ"
    db1FJ.vm.network "private_network", ip: "192.168.40.20"
    db1FJ.vm.provision "shell", path: "aprovisionamiento/bd.sh"
  end
end
```


## Balanceador
Para seguir la estructura empezaremos por el script del balanceador:



```
apt-get update
```
Actualiza la lista de paquetes disponibles del sistema para asegurar que se instalen las versiones más recientes.

```
apt-get install -y nginx
Instala el servidor web Nginx, que en este caso se utilizará como proxy inverso y balanceador de carga.
```
La opción -y acepta automáticamente todas las confirmaciones.

```
cat > /etc/nginx/sites-available/balancer << 'EOF'
upstream backend_servers {
    # Algoritmo de balanceo: round-robin (por defecto)
    # Otras opciones: least_conn, ip_hash
    
    server 192.168.20.20:80 max_fails=3 fail_timeout=30s;
    server 192.168.20.30:80 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name _;
    
    # Logs del balanceador
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    location / {
        proxy_pass http://backend_servers;
        
        # Headers para mantener informacion del cliente
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint (opcional)
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
```
Crea el archivo de configuración del sitio balanceador en Nginx.
El uso de 'EOF' evita la expansión de variables de Bash dentro del archivo.

```
upstream backend_servers {
    server 192.168.20.20:80 max_fails=3 fail_timeout=30s;
    server 192.168.20.30:80 max_fails=3 fail_timeout=30s;
}
```
Define un grupo de servidores backend que recibirán el tráfico:

El algoritmo de balanceo es round-robin (por defecto).

Cada servidor se marca como inactivo tras 3 fallos.

El tiempo de espera antes de volver a intentarlo es de 30 segundos.

```
server {
    listen 80;
    server_name _;
```
Nginx escucha en el puerto 80.

server_name _; indica que acepta peticiones para cualquier nombre de dominio.

```
access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log;
```
Registra las peticiones HTTP y los errores del balanceador para facilitar el diagnóstico y la monitorización.

```
location / {
    proxy_pass http://backend_servers;
```
Redirige todas las peticiones entrantes al grupo de servidores definido en upstream.

```
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```
Estas cabeceras permiten que los servidores backend conozcan:



El protocolo utilizado

```
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
```
Evita que el balanceador quede bloqueado si un backend tarda demasiado en responder.

```
location /nginx-health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```
Crea un endpoint de verificación que devuelve el estado del balanceador.


```
ln -sf /etc/nginx/sites-available/balancer /etc/nginx/sites-enabled/
```
Habilita la configuración del balanceador mediante un enlace simbólico.

```
rm -f /etc/nginx/sites-enabled/default
```
Evita conflictos eliminando la configuración por defecto de Nginx.



```
nginx -t
```
Comprueba que la sintaxis de la configuración de Nginx sea correcta antes de aplicar los cambios.


```
systemctl restart nginx
systemctl enable nginx
```
Reinicia Nginx para aplicar la configuración.

Configura el servicio para que se inicie automáticamente al arrancar el sistema.

## Servidores WEB

El siguiente escalon es el script de servidor web:

```
apt-get install -y nginx nfs-common
```

Instala:

Nginx como servidor web.

nfs-common para permitir el montaje de sistemas de archivos NFS.

```
mkdir -p /var/www/html/webapp
```

Crea el directorio donde se montará el sistema de archivos NFS compartido.

```
mount -t nfs 192.168.20.10:/var/www/html/webapp /var/www/html/webapp
```

Monta el directorio exportado por el servidor NFS en el sistema local, permitiendo compartir los archivos web entre varios servidores.

```
echo "192.168.20.10:/var/www/html/webapp /var/www/html/webapp nfs defaults 0 0" >> /etc/fstab
```

Añade la entrada a /etc/fstab para que el sistema de archivos NFS se monte automáticamente en cada arranque.

```
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/html/webapp;
    index index.php index.html index.htm;
    
    # Logs especificos
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        # PHP-FPM en el servidor NFS (remoto)
        fastcgi_pass 192.168.20.10:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
```

Crea la configuración del sitio web con las siguientes características:

Escucha en el puerto 80.

Usa el directorio NFS como document root.

Define archivos índice (index.php, index.html).

Registra logs de acceso y errores.

```
location / {
    try_files $uri $uri/ /index.php?$args;
}
```

Permite servir archivos estáticos y redirige las peticiones no encontradas a index.php, típico en aplicaciones PHP.
```
location ~ \.php$ {
    fastcgi_pass 192.168.20.10:9000;
}
```

Las peticiones PHP se envían al servidor PHP-FPM remoto.

El procesamiento PHP no se realiza en el servidor web, mejorando la escalabilidad.

```
location ~ /\.ht {
    deny all;
}
```

Bloquea el acceso a archivos ocultos (.htaccess, .htpasswd, etc.).

```
ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
```

Habilita la configuración del sitio.

Elimina el sitio por defecto de Nginx para evitar conflictos.

```
nginx -t
```

Comprueba que la configuración de Nginx sea correcta antes de aplicarla.

```
systemctl restart nginx
systemctl enable nginx
```

Reinicia Nginx para aplicar los cambios.

Configura el servicio para iniciarse automáticamente al arrancar el sistema.

## NFS

Lo sguiente es el script del NFS que se encontrara conectado a los servidores web y al haproxy : 

```
apt-get update -qq
apt-get install -y git mariadb-client
```

Actualiza los repositorios del sistema.

Instala:

Git para descargar la aplicación web.

Cliente MariaDB para importar la base de datos.

```
apt-get install -y nfs-kernel-server
```

Instala el servicio NFS que permitirá compartir el directorio web con los servidores web.

```
apt-get install -y php-fpm php-mysql php-curl php-gd php-mbstring \
    php-xml php-xmlrpc php-soap php-intl php-zip netcat-openbsd
```

Instala PHP-FPM y las extensiones necesarias para ejecutar la aplicación PHP, además de netcat para comprobaciones de red.

```
mkdir -p /var/www/html/webapp
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp
```

Crea el directorio que se compartirá por NFS y ajusta permisos para el usuario del servidor web (www-data).

```
cat > /etc/exports << 'EOF'
/var/www/html/webapp 192.168.20.20(rw,sync,no_subtree_check,no_root_squash)
/var/www/html/webapp 192.168.20.30(rw,sync,no_subtree_check,no_root_squash)
EOF
```

Exporta el directorio web a los servidores web:

Permisos de lectura y escritura.

Sin comprobación de subdirectorios.

Sin restricción de usuario root.

```
exportfs -a
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server
```

Aplica las exportaciones y asegura que el servicio NFS se inicie automáticamente.

```
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
```

Detecta automáticamente la versión de PHP instalada y localiza su archivo de configuración.
```
sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 9000|' "$PHP_FPM_CONF"
sed -i 's|;listen.allowed_clients.*|listen.allowed_clients = 192.168.20.20,192.168.20.30|' "$PHP_FPM_CONF"
```

Configura PHP-FPM para escuchar en el puerto 9000.

Limita las conexiones a los servidores web autorizados.

```
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm
```

Reinicia PHP-FPM y habilita su arranque automático.
```
netstat -tlnp | grep 9000
```

Verifica que PHP-FPM esté escuchando correctamente en el puerto 9000.
```
git clone https://github.com/josejuansanchez/iaw-practica-lamp.git /tmp/lamp
```

Descarga la aplicación web utilizada en la práctica desde GitHub.
```
cp -r /tmp/lamp/src/* /var/www/html/webapp/
```

Copia los archivos de la aplicación al directorio compartido por NFS.

```
define('DB_HOST', '192.168.30.10');
define('DB_NAME', 'lamp_db');
define('DB_USER', 'fj');
define('DB_PASS', '1234');
```

Configura las credenciales de acceso a la base de datos MariaDB a través del proxy de base de datos.
```
phpinfo();
```

Crea un archivo info.php para verificar el correcto funcionamiento de PHP-FPM.

```
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp
```

Garantiza permisos correctos tras el despliegue de la aplicación.

```
mysql -h 192.168.30.10 -u fj -p1234 lamp_db < /tmp/lamp/db/database.sql
```

Importa la estructura de la base de datos necesaria para la aplicación y verifica la creación de las tablas.

```
rm -rf /tmp/lamp
ls -lh /var/www/html/webapp/
```

Elimina archivos temporales y muestra el contenido final del directorio web compartido

## Haproxy

Este script pertenece al haproxy que actua de "balanceador" para el cluster de base de datos:

```
apt-get install -y haproxy
```

Instala HAProxy, que se utilizará como balanceador de conexiones TCP para MariaDB.
```
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 10s
    timeout client 1h
    timeout server 1h


frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend

backend mariadb_backend
    mode tcp
    balance roundrobin
    option tcp-check
    
    # Health check mas permisivo
    tcp-check connect

    server db1FJ 192.168.40.20:3306 check inter 5s rise 2 fall 3
    server db2FJ 192.168.40.30:3306 check inter 5s rise 2 fall 3


listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE
    stats auth admin:admin
EOF
```

Sobrescribe el archivo principal de configuración de HAProxy con una configuración específica para MariaDB.

```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
```

Define el sistema de logs.

Ejecuta HAProxy en entorno aislado (chroot).

Crea un socket de administración.

Ejecuta el servicio como usuario no privilegiado.

Activa el modo daemon.

```
defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 10s
    timeout client 1h
    timeout server 1h
```

Define el modo TCP, adecuado para MariaDB.

Habilita logs detallados de conexiones.

Configura timeouts amplios para conexiones persistentes a base de datos.

```
frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend
```

Escucha en el puerto 3306.

Acepta conexiones desde cualquier interfaz de red.

Redirige el tráfico al backend del clúster Galera.

```
backend mariadb_backend
    balance roundrobin
    option tcp-check
```

Distribuye conexiones usando round-robin.

Habilita comprobaciones de estado mediante TCP.

```
server db1FJ 192.168.40.20:3306 check inter 5s rise 2 fall 3
server db2FJ 192.168.40.30:3306 check inter 5s rise 2 fall 3
```

Comprueba el estado de cada nodo cada 5 segundos.

Un nodo se considera operativo tras 2 respuestas correctas.

Se marca como caído trasxis de 3 fallos consecutivos.

```
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE
    stats auth admin:admin
```

Habilita una interfaz web de estadísticas.

Accesible desde el puerto 8080.

Protegida mediante autenticación básica.

```
systemctl enable haproxy
```

Configura HAProxy para iniciarse automáticamente al arrancar el sistema.
```
systemctl restart haproxy
```

Aplica la nueva configuración reiniciando el servicio.

```
systemctl status haproxy --no-pager
```

Muestra el estado actual del servicio para confirmar que está activo.

## Base de datos

Por último, este es el script de base de datos:

```
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync
```

Instala:

MariaDB Server y Client

Galera 4 para replicación síncrona

rsync para la sincronización inicial de datos (SST)

```
systemctl stop mariadb
```

Detiene MariaDB antes de aplicar la configuración del clúster Galera.

```
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
```

Crea el archivo de configuración específico de Galera con los siguientes parámetros:

Configuración general de MariaDB
```
binlog_format=ROW: necesario para Galera.

default-storage-engine=innodb

innodb_autoinc_lock_mode=2

bind-address=0.0.0.0: permite conexiones remotas.

Configuración del proveedor Galera

Habilita Galera (wsrep_on=ON).

Define la librería del proveedor Galera.

Configuración del clúster

Nombre del clúster: galera_cluster.

Dirección del clúster con los nodos participantes.

Sincronización

Método SST: rsync.

Configuración del nodo

Dirección IP del nodo: 192.168.40.20.

Nombre del nodo: db1FJ.
```
```
galera_new_cluster
```

Inicializa el clúster Galera desde este nodo, que actúa como nodo primario.

```
sleep 15
```

Permite que el servicio termine de arrancar correctamente antes de realizar comprobaciones.

```
systemctl status mariadb --no-pager
```

Comprueba que MariaDB esté en ejecución.

```
CREATE DATABASE lamp_db;
CREATE USER 'fj'@'%';
```

Se crean los siguientes recursos:

Base de datos lamp_db para la aplicación web.

Usuario fj con permisos completos sobre la base de datos.

Usuario haproxy para comprobaciones de estado del proxy.

Usuario root remoto para administración.

Se aplican los privilegios y se verifican los usuarios creados.

```
systemctl enable mariadb
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
```

Configura MariaDB para iniciarse automáticamente.

Comprueba el tamaño del clúster Galera para verificar la replicación.

## Comprobación 

Para poder acceder a la pagian web, ejecuta en tu navegador:
```
http://localhost:8080
```
## Conclusión

Este proyecto implementa un entorno LAMP distribuido y altamente disponible, integrando múltiples tecnologías para garantizar escalabilidad, tolerancia a fallos y eficiencia en la gestión de aplicaciones web.

Los componentes principales y su función dentro del sistema son:

Servidores Web (Nginx) con PHP-FPM remoto

Los servidores web (serverweb1FJ y serverweb2FJ) consumen contenido desde un directorio compartido mediante NFS (serverNFSFJ), lo que permite coherencia de archivos y despliegues centralizados.

La ejecución de PHP mediante PHP-FPM remoto desacopla el procesamiento de las aplicaciones del servidor web, mejorando la escalabilidad y el rendimiento.

Servidor NFS con PHP-FPM

Centraliza los archivos de la aplicación y provee servicios PHP para los servidores web.

Facilita la gestión centralizada de la aplicación, evitando inconsistencias entre nodos web.

Clúster de Bases de Datos MariaDB Galera

Dos nodos (db1FJ y db2FJ) replican datos en tiempo real mediante Galera, asegurando alta disponibilidad y tolerancia a fallos.

Los nodos permiten conexiones remotas y se sincronizan automáticamente al añadir nuevos nodos.

HAProxy como proxy de base de datos

Distribuye las conexiones MariaDB entre los nodos Galera de forma balanceada.

Implementa health checks para garantizar que solo se enruten conexiones a nodos activos.

Balanceador Front-end (Nginx)

Gestiona las peticiones entrantes de usuarios, repartiendo la carga entre los servidores web.

Permite el acceso externo mediante redirección de puertos y proporciona alta disponibilidad a la capa web.

Automatización mediante Vagrant y scripts de aprovisionamiento

Todos los servicios se configuran automáticamente mediante scripts Bash.

Esto permite replicar el entorno de forma consistente y eficiente, simplificando pruebas y despliegues.

![](https://iescelia.org/web/wp-content/uploads/2012/05/iescelia_1950.jpg)
