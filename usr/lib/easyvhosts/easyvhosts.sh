#
# Easy Virtual Hosts
# Copyright (C) 2014 Esteban De La Fuente Rubio (esteban[at]sasco.cl)
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

# Función que genera la configuración para bind
# $1 Nombre del dominio
function generate_bind {
	# recibir parámetros de la función
	DOMAIN=$1
	# generar configuración de bind solo si existe su directorio
	if [ -d $BIND_DIR ]; then
		# mensaje de registro
		log " Generando zonas de dns para dominio $DOMAIN"
		# plantillas
		ZONE_BODY_FILE="$TEMPLATE_DIR/zone_body"
		ZONE_HEADER_INTERNAL_FILE="$TEMPLATE_DIR/zone_header_internal"
		ZONE_HEADER_EXTERNAL_FILE="$TEMPLATE_DIR/zone_header_external"
		AUX="/tmp/$DOMAIN"
		# crear detalle de la zona interna
		cp $ZONE_BODY_FILE $AUX
		file_replace $AUX domain $DOMAIN
		file_replace $AUX ip $IP_INTERNAL
		file_replace $AUX serial `date +%Y%m%d%H`
		mv $AUX $BIND_DIR/internal/$DOMAIN
		# crear detalle de la zona externa
		cp $ZONE_BODY_FILE $AUX
		file_replace $AUX domain $DOMAIN
		file_replace $AUX ip $IP_EXTERNAL
		file_replace $AUX serial `date +%Y%m%d%H`
		mv $AUX $BIND_DIR/external/$DOMAIN
		# agregar zona al archivo de definición de zonas internas
		cp $ZONE_HEADER_INTERNAL_FILE $AUX
		file_replace $AUX domain $DOMAIN
		cat $AUX >> $BIND_DIR/internal/zones.conf
		# agregar zona al archivo de definición de zonas externas
		cp $ZONE_HEADER_EXTERNAL_FILE $AUX
		file_replace $AUX domain $DOMAIN
		cat $AUX >> $BIND_DIR/external/zones.conf
		# eliminar auxiliar
		rm -f $AUX
	fi
}

# Función que genera la configuración para Apache
# $1 Nombre del dominio
# $2 Ubicación del dominio
# $3 Usuario
function generate_vhosts {
	# recibir parámetros de la función
	DOMAIN=`invertir $1`
	DOMAIN_DIR=$2
	USER=$3
	# mensaje de registro
	log " Generando dominios virtuales para $DOMAIN"
	# archivo de configuración apache para este dominio
	VHOST_FILE="$APACHE_DIR/easyvhosts_$DOMAIN.conf"
	# archivo de configuración
	if [ -d $NGINX_DIR ]; then
		NGINX_FILE="$NGINX_DIR/easyvhosts_$DOMAIN.conf"
	fi
	# buscar dominios virtuales (cada uno de los directorios en htdocs)
	DOMAINS=`ls $DOMAIN_DIR/$WWW_VHOST_DIR`
	for REAL_NAME in $DOMAINS; do
		SUBDOMAIN=`invertir $REAL_NAME`
		log "  Procesando el dominio $SUBDOMAIN.$DOMAIN"
		# si es el dominio principal (se usa carpeta www y se crea alias
		# a esta misma)
		if [ "$SUBDOMAIN" = "$WWW_VHOST_MAIN" ]; then
			SERVER_NAME="$DOMAIN"
			SERVER_ALIAS="$SUBDOMAIN.$DOMAIN"
		else
			SERVER_NAME="$SUBDOMAIN.$DOMAIN"
			SERVER_ALIAS=""
		fi
		# buscar si existen certificados SSL para el dominio en el directorio
		# del dominio virtual
		SSL=""
		CRT="$DOMAIN_DIR/ssl/$REAL_NAME.crt"
		KEY="$DOMAIN_DIR/ssl/$REAL_NAME.key"
		if [ -f "$CRT" -a -f "$KEY" ]; then
			log "   Se encontró certificado SSL"
			# verificar que la llave no se encuentre encriptada
			if [ -n "`cat $KEY | grep ENCRYPTED`" ]; then
				log "    Encriptado, no se utilizará"
			# llave no se encuentra encriptada
			else
				# opciones por defecto para SSL
				SSL="SSLEngine on\n"
				SSL="$SSL\tSSLCertificateFile $CRT\n"
				SSL="$SSL\tSSLCertificateKeyFile $KEY"
				# en caso que exista archivo para Chain se
				# agrega
				C="$DOMAIN_DIR/ssl/${REAL_NAME}_ca.crt"
				if [ -f "$C" ]; then
					SSL="$SSL\n\tSSLCertificateChainFile $C"
				fi
				# fix para MSIE
				SSL="$SSL\n\tSetEnvIf User-Agent \".*MSIE.*\""
				SSL="$SSL nokeepalive ssl-unclean-shutdown"
			fi
		# buscar si existen certificados SSL con Let's Encrypt
		# WARNING no busca el certificado para www, se asume que los www
		# serán redireccionados, si hay un www se buscará sólo como el
		# dominio (sin www.)
		else
			if [ $SUBDOMAIN = "www" ]; then
				LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"
			else
				LETSENCRYPT_DIR="/etc/letsencrypt/live/$SUBDOMAIN.$DOMAIN"
			fi
			CRT="$LETSENCRYPT_DIR/cert.pem"
			KEY="$LETSENCRYPT_DIR/privkey.pem"
			if [ -f "$CRT" -a -f "$KEY" ]; then
				log "   Se encontró certificado SSL (by Let's Encrypt)"
				# opciones por defecto para SSL
				SSL="SSLEngine on\n"
				SSL="$SSL\tSSLCertificateFile $CRT\n"
				SSL="$SSL\tSSLCertificateKeyFile $KEY"
				# en caso que exista archivo para Chain se
				# agrega
				C="$LETSENCRYPT_DIR/chain.pem"
				if [ -f "$C" ]; then
					SSL="$SSL\n\tSSLCertificateChainFile $C"
				fi
				# fix para MSIE
				SSL="$SSL\n\tSetEnvIf User-Agent \".*MSIE.*\""
				SSL="$SSL nokeepalive ssl-unclean-shutdown"
			fi
		fi
		# cargar configuración para el dominio
		# configuración por defecto:
		ALIASES=""
		REDIRECT_WWW="no"
		SSL_FORCE="yes"
		SUPHP="no"
		DOCUMENT_ROOT_SUFFIX=""
		# configuración personalizada:
		CONF="$DOMAIN_DIR/conf/httpd/$REAL_NAME.conf"
		if [ -f $CONF  ]; then
			log "   Se encontró configuración personalizada"
			. $CONF
		fi
		# si existen cerfificados ssl y se fuerza ssl se configura
		if [ -n "$SSL" -a "$SSL_FORCE" = "no" ]; then
			log "   El uso de SSL es opcional"
		fi
		# redirigir www a non-www
		if [ "$REDIRECT_WWW" = "yes"  ]; then
			log "   Forzando el no uso de www"
			SERVER_ALIAS=""
		fi
		# alias (subdominios del mismo u otros dominios) asociados a
		# este dominio
		if [ -n "$ALIASES" ]; then
			log "   Cargando alias para el dominio"
			for ALIAS in $ALIASES; do
				if [[ $ALIAS != *.* ]]; then
					ALIAS=$ALIAS.$1
				fi
				SERVER_ALIAS="$SERVER_ALIAS $ALIAS"
			done
		fi
		# si se require utilizar o no suphp
		if [ "$SUPHP" = "yes" ]; then
			log "   Utilizando SuPHP"
			SUPHP="php_admin_flag engine off\n"
			SUPHP="$SUPHP\tsuPHP_Engine on\n"
			SUPHP="$SUPHP\tAddHandler application/x-httpd-php .php\n"
			SUPHP="$SUPHP\tsuPHP_AddHandler application/x-httpd-php\n"
			#SUPHP="$SUPHP\tsuPHP_UserGroup $USER `id $USER -ng`"
		else
			SUPHP=""
		fi
		# establecer DOCUMENT_ROOT
		DOCUMENT_ROOT="$DOMAIN_DIR/$WWW_VHOST_DIR/$REAL_NAME$DOCUMENT_ROOT_SUFFIX"
		# remplazar campos en la plantilla
		AUX="/tmp/$SUBDOMAIN.$DOMAIN"
		# en caso que se deba redireccionar WWW se hace tanto para el
		# dominio virtual en puerto estándar como para el dominio en
		# puerto HTTPS (en caso que se esté usando
		if [ "$SUBDOMAIN" = "$WWW_VHOST_MAIN" -a "$REDIRECT_WWW" = "yes" ]; then
			cp "$TEMPLATE_DIR/vhost/redirect_www" $AUX
			file_replace $AUX domain "$DOMAIN"
			file_replace $AUX port $HTTP_PORT
			file_replace $AUX protocol "http"
			file_replace $AUX ssl ""
			cat $AUX >> $VHOST_FILE
			if [ -n "$SSL" ]; then
				cp "$TEMPLATE_DIR/vhost/redirect_www" $AUX
				file_replace $AUX domain "$DOMAIN"
				file_replace $AUX port $HTTPS_PORT
				file_replace $AUX protocol "https"
				file_replace $AUX ssl "$SSL"
				cat $AUX >> $VHOST_FILE
			fi
		fi
		# si se debe forzar SSL solo se redirecciona
		if [ -n "$SSL" -a "$SSL_FORCE" = "yes" ]; then
			cp "$TEMPLATE_DIR/vhost/ssl_force" $AUX
			file_replace $AUX servername "$SERVER_NAME"
			file_replace $AUX serveralias "$SERVER_ALIAS"
			file_replace $AUX port $HTTP_PORT
			cat $AUX >> $VHOST_FILE
		# si no se debe forzar SSL entonces se genera el dominio virtual
		# para el puerto estándar de HTTP
		else
			cp "$TEMPLATE_DIR/vhost_generic" $AUX
			file_replace $AUX servername "$SERVER_NAME"
			file_replace $AUX serveralias "$SERVER_ALIAS"
			file_replace $AUX root "$DOCUMENT_ROOT"
			file_replace $AUX domain "$DOMAIN"
			file_replace $AUX realname "$REAL_NAME"
			file_replace $AUX alias "$ALIAS_DIR"
			file_replace $AUX logs "$DOMAIN_DIR/logs"
			file_replace $AUX port $HTTP_PORT
			file_replace $AUX suphp "$SUPHP"
			file_replace $AUX ssl ""
			cat $AUX >> $VHOST_FILE
		fi
		# borrar archivo auxiliar
		rm -f $AUX
		# si existe ssl para este dominio habilitar
		if [ -n "$SSL" ]; then
			AUX_SSL="/tmp/$SUBDOMAIN.$DOMAIN-ssl"
			cp "$TEMPLATE_DIR/vhost_generic" $AUX_SSL
			# remplazar campos en la plantilla
			file_replace $AUX_SSL servername "$SERVER_NAME"
			file_replace $AUX_SSL serveralias "$SERVER_ALIAS"
			file_replace $AUX_SSL root "$DOCUMENT_ROOT"
			file_replace $AUX_SSL domain "$DOMAIN"
			file_replace $AUX_SSL realname "$REAL_NAME"
			file_replace $AUX_SSL alias "$ALIAS_DIR"
			file_replace $AUX_SSL logs "$DOMAIN_DIR/logs"
			file_replace $AUX_SSL port $HTTPS_PORT
			file_replace $AUX_SSL suphp "$SUPHP"
			file_replace $AUX_SSL ssl "$SSL"
			# agregar configuracion en el archivo de apache
			cat $AUX_SSL >> $VHOST_FILE
			# borrar archivo auxiliar
			rm -f $AUX_SSL
		fi
		# generar dominio para nginx
		if [ -d $NGINX_DIR ]; then
			log "   Generando configuración para nginx"
			# copiar plantilla a archivo auxiliar
			AUX="/tmp/$SUBDOMAIN.$DOMAIN"
			cp "$TEMPLATE_DIR/nginx_server" $AUX
			# reemplazar campos en la plantilla
			file_replace $AUX servername "$SERVER_NAME"
			file_replace $AUX serveralias "$SERVER_ALIAS"
			#file_replace $AUX root "$DOCUMENT_ROOT"
			#file_replace $AUX domain "$DOMAIN"
			#file_replace $AUX realname "$REAL_NAME"
			#file_replace $AUX logs "$DOMAIN_DIR/logs"
			file_replace $AUX port 80
			# agregar configuracion en el archivo de nginx para el
			# dominio
			cat $AUX >> $NGINX_FILE
			# borrar archivo auxiliar
			rm -f $AUX
		fi
	done
	# crear directorio para logs
	mkdir -p $DOMAIN_DIR/logs
	chown $USER: $DOMAIN_DIR/logs
	# asignar permisos de ejecucion para otros al home del usuario
	chmod o+x $USER_HOME
}
