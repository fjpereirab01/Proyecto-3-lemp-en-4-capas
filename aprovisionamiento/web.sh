#!/bin/bash


apt-get update


apt-get install -y nginx nfs-common


mkdir -p /var/www/html/webapp


mount -t nfs 192.168.20.10:/var/www/html/webapp /var/www/html/webapp


echo "192.168.20.10:/var/www/html/webapp /var/www/html/webapp nfs defaults 0 0" >> /etc/fstab


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


ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default


nginx -t


systemctl restart nginx
systemctl enable nginx