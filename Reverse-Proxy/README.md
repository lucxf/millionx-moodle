# REVERSE PROXY CON NGINX

[ngnix docu](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
[yt video](https://www.youtube.com/watch?v=DyXl4c2XN-o)
[hostinguer docu](https://www.swhosting.com/en/comunidad/manual/how-to-create-a-reverse-proxy-with-nginx)

1. Instalar **nginx**

```bash
apt install nginx -y
```

![alt text](image.png)

![alt text](image-1.png)

2. Configurar el **sites-available**

Crear un fichero con el nombre del dominio, en este caso el fichero se llamará `millionx-academy.com.conf` con la extensión **.conf**

```conf
server {
    # Escuchar en el puerto 80 para el subdominio nextcloud.
    listen 80;

    # Nombre del servidor o subdominio.
    server_name nextcloud.millionx-academy.com;

    access_log /var/log/nginx/nextcloud.millionx-academy.com.access.log;

    location / {
        # Configuración del proxy para redirigir a la IP interna.
        proxy_pass http://192.168.20.12:700/;
        
        # Otras configuraciones del proxy (si es necesario).
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

3. Enlace simbolico

```bash
sudo ln -s /etc/nginx/sites-available/millionx-academy.com.conf /etc/nginx/sites-enabled/
```

4. Reiniciar nginx

Una vez reiniciado nginx, nos daremos cuenta de que si accedemos tendremos problemas debido a que nos dice que no es de confianza, para ello tendremos que configurar mas cosas.

Tendremos que ir a nuestro nextcloud y editar el fichero `config.php` donde agregaremos dentro como tursted `nextcloud.millionx-academy.com`

![alt text](image-3.png)

![alt text](image-4.png)

![alt text](image-5.png)

Como podemos comprobar ya funciona correctametne, solo faltará el **TLS**

![alt text](image-6.png)

# TLS

1. Crear directorio donde guardar los certificados

```bash
mkdir -p /etc/nginx/ssl
chmod 700 /etc/nginx/ssl
```

2. Crear clave privada del certificado

```bash
openssl genpkey -algorithm RSA -out /etc/nginx/ssl/clave_privada.key
```

3. Crear una solicitud para certificado ssl

pones tus datos, email puede ser falso

```bash
openssl req -new -key /etc/nginx/ssl/clave_privada.key -out /etc/nginx/ssl/solicitud.csr
```

4. Creo el certificado usando la solicitud

```bash
openssl x509 -req -days 365 -in /etc/nginx/ssl/solicitud.csr -signkey /etc/nginx/ssl/clave_privada.key -out /etc/nginx/ssl/certificado.crt
```

```bash
server {
  #Listen in the harbor 80, ipv4.
  listen 80; 
}

server{

  listen 442;
  #Here you must enter the name of your domain.
  server_name millionx-academy.com;
  
  ssl_certificate /etc/nginx/ssl/certificado.crt;
  ssl_certificate_ley /etc/nginx/ssl/clave_privada.key

  access_log            /var/log/nginx/millionx-academy.com.access.log;

  location / {
      #The proxy settings.
      proxy_pass http://192.168.20.12:700/;
  }
}
```

5. RELOAD

```bash
nginx -s reload
```