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

**Solucion de ChatGpt**

Solución

Debes agregar tu dominio (nextcloud.millionx-academy.com en este caso) a la lista de dominios confiables de Nextcloud. Para hacerlo, debes editar el archivo config.php en el directorio de configuración de Nextcloud.

    Ubicación del archivo config.php: El archivo config.php de Nextcloud generalmente se encuentra en la siguiente ruta dentro de tu instalación de Nextcloud:

/var/www/nextcloud/config/config.php

Nota: El directorio puede variar según tu configuración, pero generalmente está en la carpeta de instalación de Nextcloud.

Editar `config.php`: Abre el archivo config.php con un editor de texto, por ejemplo, nano:

`sudo nano /var/www/nextcloud/config/config.php`

Agregar el dominio confiable: Dentro de este archivo, busca el parámetro 'trusted_domains'. Si no está presente, deberás agregarlo. Debes agregar el dominio o subdominio que estás utilizando (en este caso, nextcloud.millionx-academy.com).

El bloque que debes agregar o modificar se verá así:
```php
'trusted_domains' =>
array (
  0 => 'localhost',
  1 => 'nextcloud.millionx-academy.com',  // Agrega tu dominio aquí
),
```
Si ya hay otros dominios en esta lista, simplemente agrega el nuevo dominio como una nueva línea numerada (en este caso, 1 => 'nextcloud.millionx-academy.com').

Guardar y cerrar: Una vez que hayas agregado el dominio, guarda el archivo y cierra el editor (Ctrl + O para guardar y Ctrl + X para salir en nano).

Reiniciar el servidor web: Después de modificar el archivo de configuración, es recomendable reiniciar el servidor web para asegurarte de que los cambios tomen efecto. Si estás usando Nginx, ejecuta:

`sudo systemctl reload nginx`
