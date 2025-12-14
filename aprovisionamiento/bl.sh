#!/bin/bash

apt-get update


apt-get install -y nginx


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


ln -sf /etc/nginx/sites-available/balancer /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default


nginx -t


systemctl restart nginx
systemctl enable nginx