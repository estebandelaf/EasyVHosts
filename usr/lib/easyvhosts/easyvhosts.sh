#
# Easy Virtual Hosts
# Copyright (C) 2012 Esteban De La Fuente Rubio (esteban[at]sasco.cl)
#
# Este programa es software libre: usted puede redistribuirlo y/o modificarlo
# bajo los términos de la Licencia Pública General GNU publicada
# por la Fundación para el Software Libre, ya sea la versión 3
# de la Licencia, o (a su elección) cualquier versión posterior de la misma.
#
# Este programa se distribuye con la esperanza de que sea útil, pero
# SIN GARANTÍA ALGUNA; ni siquiera la garantía implícita
# MERCANTIL o de APTITUD PARA UN PROPÓSITO DETERMINADO.
# Consulte los detalles de la Licencia Pública General GNU para obtener
# una información más detallada.
#
# Debería haber recibido una copia de la Licencia Pública General GNU
# junto a este programa.
# En caso contrario, consulte <http://www.gnu.org/licenses/gpl.html>.
#
# Este archivo corresponde a la definición de funciones propias del
# proyecto EasyVirtualHost
#
# Visite http://dev.sasco.cl/easyvhosts para más detalles.
#

# $1 Nombre del dominio
function generate_bind {
	# generar configuración de bind solo si existe su directorio
	if [ -d $BIND_DIR ]; then
		# mensaje de registro
		log " Generando zonas de dns para dominio $1"
		# plantillas
		ZONE_BODY_FILE="$TEMPLATE_DIR/zone_body"
		ZONE_HEADER_INTERNAL_FILE="$TEMPLATE_DIR/zone_header_internal"
		ZONE_HEADER_EXTERNAL_FILE="$TEMPLATE_DIR/zone_header_external"
		AUX="/tmp/$1"
		# crear detalle de la zona interna
		cp $ZONE_BODY_FILE $AUX
		file_replace $AUX domain $1
		file_replace $AUX ip $IP_INTERNAL
		file_replace $AUX serial `date +%Y%m%d%H`
		mv $AUX $BIND_DIR/internal/$1
		# crear detalle de la zona externa
		cp $ZONE_BODY_FILE $AUX
		file_replace $AUX domain $1
		file_replace $AUX ip $IP_EXTERNAL
		file_replace $AUX serial `date +%Y%m%d%H`
		mv $AUX $BIND_DIR/external/$1
		# agregar zona al archivo de definición de zonas internas
		cp $ZONE_HEADER_INTERNAL_FILE $AUX
		file_replace $AUX domain $1
		cat $AUX >> $BIND_DIR/internal/zones.conf
		# agregar zona al archivo de definición de zonas externas
		cp $ZONE_HEADER_EXTERNAL_FILE $AUX
		file_replace $AUX domain $1
		cat $AUX >> $BIND_DIR/external/zones.conf
		# eliminar auxiliar
		rm -f $AUX
	fi
}

# $1 Nombre del dominio
# $2 Ubicación del dominio
# $3 Usuario
function generate_vhosts {
        # mensaje de registro
        log " Generando dominios virtuales para $1"
        # archivo de configuración apache para este dominio
        VHOST_FILE="$APACHE_DIR/easyvhosts_$1.conf"
        # archivo de configuración
        if [ -d $NGINX_DIR ]; then
                NGINX_FILE="$NGINX_DIR/easyvhosts_$1.conf"
        fi
        # buscar dominios virtuales (cada uno de los directorios en htdocs)
        DOMAINS=`ls $2/$WWW_VHOST_DIR`
        for REAL_NAME in $DOMAINS; do
                DOMAIN=`invertir $REAL_NAME`
                log "  Procesando el dominio $DOMAIN.$1"
                # copiar plantilla a archivo auxiliar
                TEMPLATE="$TEMPLATE_DIR/vhost_generic"
                AUX="/tmp/$DOMAIN.$1"
                cp $TEMPLATE $AUX
                # si es el dominio principal (se usa carpeta www y se crea alias a esta misma)
                if [ "$DOMAIN" = "$WWW_VHOST_MAIN" ]; then
                        SERVER_NAME="$1"
                        SERVER_ALIAS="$1 $WWW_VHOST_MAIN.$1"
                else
                        SERVER_NAME="$DOMAIN.$1"
                        SERVER_ALIAS="$DOMAIN.$1"
                fi
                # buscar si existen certificados SSL para el dominio
                if [ -f "$2/ssl/$REAL_NAME.$1.crt" -a -f "$2/ssl/$REAL_NAME.$1.key" ]; then
                        log "   Se encontró certificado SSL"
			# ubicación certificados
			CRT="$2/ssl/$REAL_NAME.$1.crt"
			KEY="$2/ssl/$REAL_NAME.$1.key"
                        # verifica rque la llave no se encuentre encriptada
			if [ -n "`cat $KEY | grep ENCRYPTED`" ]; then
				log "    Clave privada se encuentra encriptada, no se usará SSL"
				SSL=""
			# llave no se encuentra encriptada	
			else
				# opciones para cargar el certificado
                        	SSL="SSLEngine on\n\tSSLCertificateFile $CRT\n\tSSLCertificateKeyFile $KEY\n\tSetEnvIf User-Agent \".*MSIE.*\" nokeepalive ssl-unclean-shutdown"
			fi
                else
                        SSL=""
                fi
                # configuraciones personalizadas para el dominio virtual
                CONF="$2/conf/httpd/$REAL_NAME.$1.conf"
                if [ -f $CONF  ]; then
                        log "   Se encontró configuración personalizada"
                        # alias (subdominios del mismo u otros dominios) asociados a este dominio
                        ALIASES=`conf_get $CONF ALIASES`
                        if [ -n "$ALIASES" ]; then
				log "    Cargando alias para el dominio"
				for ALIAS in $ALIASES; do
					if [[ $ALIAS != *.* ]]; then
						ALIAS=$ALIAS.$1
					fi
					SERVER_ALIAS="$SERVER_ALIAS $ALIAS"
				done
                        fi
			# si existen cerfificados ssl y se fuerza ssl se configura
                        SSL_FORCE=`conf_get $CONF SSL_FORCE`
                        if [ -n "$SSL" -a "$SSL_FORCE" = "yes" ]; then
				log "    Forzando el uso de SSL"
                                SSL_FORCE="RewriteCond %{SERVER_PORT} 80\n\t\tRewriteCond %{REQUEST_URI} /\n\t\tRewriteRule ^(.*)$ https://$DOMAIN.$1/\$1 [R,L]"
			else
				SSL_FORCE=""
                        fi
			# redirigir el alias al server name
			REDIRECT_WWW=`conf_get $CONF REDIRECT_WWW`
			if [ "$REDIRECT_WWW" = "yes"  ]; then
				log "    Forzando el no uso de www"
				REDIRECT_WWW="RewriteCond %{HTTP_HOST} ^www\.(.+)$ [NC]\n\t\tRewriteRule ^(.*)$ http://%1/\$1 [R=301,L]"
			else
				REDIRECT_WWW=""
			fi
			# si se require utilizar o no suphp
                        SUPHP=`conf_get $CONF SUPHP`
			if [ "$SUPHP" = "yes" ]; then
				log "    Utilizando SuPHP"
				SUPHP="php_admin_flag engine off\n\tsuPHP_Engine on\n\tAddHandler application/x-httpd-php .php\n\tsuPHP_AddHandler application/x-httpd-php\n\tsuPHP_UserGroup $3 `id $3 -ng`"
			else
				SUPHP=""
			fi
		# si no hay archivo de configuracion se limpian variables, excepto SERVER_ALIAS que fue definida antes
		else
			SSL_FORCE=""
			REDIRECT_ALIAS=""
			SUPHP=""
                fi
		# si existe ssl para este dominio habilitar
		if [ -n "$SSL" ]; then 
			AUX_SSL="$AUX-ssl"
			cp $AUX  $AUX_SSL
                	# remplazar campos en la plantilla
	                file_replace $AUX_SSL servername "$SERVER_NAME"
        	        file_replace $AUX_SSL serveralias "$SERVER_ALIAS"
                	file_replace $AUX_SSL root "$2/$WWW_VHOST_DIR/$REAL_NAME"
                	file_replace $AUX_SSL domain "$1"
                	file_replace $AUX_SSL realname "$REAL_NAME"
	                file_replace $AUX_SSL alias "$ALIAS_DIR"
        	        file_replace $AUX_SSL logs "$2/logs"
			file_replace $AUX_SSL port $HTTPS_PORT
			file_replace $AUX_SSL redirect_www "$REDIRECT_WWW"
			file_replace $AUX_SSL suphp "$SUPHP"
                	file_replace $AUX_SSL ssl "$SSL"
	                file_replace $AUX_SSL ssl_force ""
                	# agregar configuracion en el archivo de apache
                	cat $AUX_SSL >> $VHOST_FILE
                	# borrar archivo auxiliar
	                rm -f $AUX_SSL
		fi
                # remplazar campos en la plantilla
                file_replace $AUX servername "$SERVER_NAME"
                file_replace $AUX serveralias "$SERVER_ALIAS"
                file_replace $AUX root "$2/$WWW_VHOST_DIR/$REAL_NAME"
                file_replace $AUX domain "$1"
                file_replace $AUX realname "$REAL_NAME"
                file_replace $AUX alias "$ALIAS_DIR"
                file_replace $AUX logs "$2/logs"
		file_replace $AUX port $HTTP_PORT
		file_replace $AUX redirect_www "$REDIRECT_WWW"
		file_replace $AUX suphp "$SUPHP"
                file_replace $AUX ssl ""
                file_replace $AUX ssl_force "$SSL_FORCE"
                # agregar configuracion en el archivo de apache
                cat $AUX >> $VHOST_FILE
                # borrar archivo auxiliar
                rm -f $AUX
		# generar dominio para nginx
		if [ -d $NGINX_DIR ]; then
			log "   Generando configuración para nginx"
			# copiar plantilla a archivo auxiliar
	                TEMPLATE="$TEMPLATE_DIR/nginx_server"
        	        AUX="/tmp/$DOMAIN.$1"
                	cp $TEMPLATE $AUX
			# reemplazar campos en la plantilla
	                file_replace $AUX servername "$SERVER_NAME"
        	        file_replace $AUX serveralias "$SERVER_ALIAS"
                	#file_replace $AUX root "$2/$WWW_VHOST_DIR/$REAL_NAME"
                	#file_replace $AUX domain "$1"
	                #file_replace $AUX realname "$REAL_NAME"
        	        #file_replace $AUX logs "$2/logs"
			file_replace $AUX port 80
                	# agregar configuracion en el archivo de nginx para el dominio
	                cat $AUX >> $NGINX_FILE
	                # borrar archivo auxiliar
        	        rm -f $AUX
		fi
        done
        # crear directorio para logs
        mkdir -p $2/logs
        chown $3: $2/logs
        # asignar permisos de ejecucion para otros al home del usuario
        chmod o+x $USER_HOME
}

