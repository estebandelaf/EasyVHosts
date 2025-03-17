Easy Virtual Hosts (EasyVHosts)
===============================

---
**ARCHIVADO**: Lo he reemplazado por estos repositorios:

- https://github.com/derafu/docker-php-caddy-server
- https://github.com/derafu/deployer
- https://github.com/derafu/github
---

Easy Virtual Hosts o EasyVHosts es una herramienta para la administración de
dominios virtuales de diferentes usuarios en un sistema GNU/Linux. Utiliza un
formato de directorios y archivos para los dominios de los usuarios, obteniendo
dinámicamente las características de los mismos y generando automáticamente los
archivos de configuración para lo servicios involucrados (como httpd o named).

Instalación y ejecución
-----------------------

Para instalar EasyVHosts basta clonar el proyecto:

        # mkdir -p ~/app
        # cd ~/app
        # git clone https://github.com/sascocl/EasyVHosts.git easyvhosts

Para generar los archivos de configuración y recargar los servicios basta
ejecutar el script easyvhosts dentro del directorio bin, o sea estándo dentro
del directorio easyvhosts (si se usa como esta por defecto) se puede hacer con:

        # cd ~/app/easyvhosts
        # bin/easyvhosts

Autodetección
-------------

EasyVHosts funciona con el principio de autodetección, verifica una serie de
directorios y archivos y dependiendo de su prescencia tomará una u otra acción.

### Dominios

Los dominios son definidos bajo el directorio WWW_DIR, cada uno de los
directorios aquí creados será una zona dentro del DNS. Así se tendrá por ejemplo
(asumiendo usuario delaf y WWW_DIR=www):

                     /home/delaf/www
                      |           |
                cl.delaf         cl.sasco

Notar que los dominios se escriben al revés, dominio de nivel superior primero
(en este caso .cl) y luego el dominio. Esto es muy importante y se debe
respetar.

### Subdominios

Los subdominios de cada dominio están dentro del directorio htdocs, en este se
colocan los dominios sin el dominio principal. En el caso de subdominios en
varios niveles se escriben al revés, ejemplo el subdominio
demo.clientes.sasco.cl se alojará dentro del directorio htdocs del dominio
sasco.cl como clientes.demo, el dominio principal se compartirá con el dominio
www, por lo cual sasco.cl será alojado en el directorio www, de esta forma se
tendrá:

                     /home/delaf/www
                      |           |
                cl.delaf         cl.sasco
                   |                |
                 htdocs           htdocs
                 |    |           |    |
               blog  www        www    clientes.demo

#### nginx

En caso de existir el directorio /etc/nginx/conf.d (o el especificado en la
configuración) se asumirá que se desea utilizar y se creará la configuración
necesaria para cada uno de los subdominios detectados. Se utilizará

	proxy_pass  http://localhost;

Por lo cual en el archivo /etc/nginx/conf.d/default.conf se debe
añadir la siguiente configuración:

	# nginx reverse proxy for localhost web server
	upstream localhost {
		server 127.0.0.1:8080;
	}

Lo anterior asume que se configuró el puerto 8080 en Apache.

### Certificados SSL

Estos irán en el directorio ssl y tendrán como nombre el subdominio y
terminando en la extensión correspondiente, un ejemplo:

                     /home/delaf/www
                            |
                         cl.delaf
                            |
                           ssl
                           | |
                    blog.crt blog.key
       (certificado firmado) (clave privada)

### Autoindex

Si existe un directorio autoindex (en la raiz del subdominio) y dentro un
archivo header.php o footer.php se utilizará para reemplazar en el Index
generado por Apache en caso de no encontrar uno (que no exista index.html o
index.php básicamente). Esta carpeta estará oculta en el listado. Un ejemplo:

                     /home/delaf/www
                            |
                         cl.delaf
                            |
                         htdocs
                            |
                          debian
                            |
                        autoindex
                        |       |
                 header.php    footer.php

Si se quiere utilizar una imagen o un archivo css (u otra cosa), dejarla dentro
del directorio autoindex.

Configuración mediante archivos
-------------------------------

Actualmente solo se puede personalizar la configuración para Apache.

### Apache

El directorio de configuración por dominio es conf/httpd y se deberá colocar un
archivo por cada subdominio, con el nombre del subdominio y la extensión .conf
Dentro del archivo se podrán definir ciertas opciones que modificarán la
creación de la configuración para Apache para dicho dominio. Un ejemplo:

                     /home/delaf/www
                            |
                         cl.delaf
                            |
                           conf
                            |
                          httpd
                            |
                         www.conf

Dentro del archivo www.conf se puede utilizar:

	ALIASES="*"
	REDIRECT_WWW="yes"
	SSL_FORCE="yes"
	SUPHP="yes"

*	**ALIASES**: indica a que otros nombres responde el dominio, si es *
	responderá a cualquier nombre que no haya sido definido por otro
	subdominio. Otra alternativa es especificar un listado separado por
	espacio de otros dominios (subdominios u otros).

	Ejemplos:

		ALIASES="*"
		ALIASES="www2.example.com"
		ALIASES="www2.example.com www3.example.com"
		ALIASES="otrodominio.com www.otrodominio.com"

	Default:

*	**REDIRECT_WWW**: indica si al utilizar www este será redireccionado
	al dominio pricipal, esto en caso que se quiera "evitar" que se acceda
	mediante www.example.com.

	Default: "no"

*	**SSL_FORCE**: fuerza el uso de HTTPS si el usuario entra mediante HTTP,
	requiere que exista un certificado en el directorio ssl que este
	asociado al dominio.

	Default: "yes"

*	**SUPHP**: indica si se debe utilizar SuPHP para servir las páginas PHP
	del dominio.

	Defaultl: "no"

*	**DOCUMENT_ROOT_SUFFIX**: permite definir un subdirectorio dentro del
	directorio del dominio virtual para ser publicado como base del dominio.

	Ejemplo: DOCUMENT_ROOT_SUFFIX=/public

	Default:

SSL con Let's Encrypt
---------------------

EasyVHosts puede utilizar certificados SSL generados con Let's Encrypt. Sólo se
deben crear los certificados y se podrán usar con este script.

Para crear los certificados usar:

	# certbot certonly --standalone --preferred-challenges http -d sasco.cl \
	  --pre-hook "service apache2 stop" --post-hook "service apache2 start"

Para renovar el certificado usar:

	# certbot certonly --standalone -n --preferred-challenges http -d sasco.cl \
	  --pre-hook "service apache2 stop" --post-hook "service apache2 start"

Se agrega un parámetro `-n` para la renovación.

Por supuesto, cambiar `sasco.cl` por el dominio correspondiente.
