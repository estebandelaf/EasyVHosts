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

# $1 Nombre del dominio a actualizar
function update_nic {
        # mensaje de registro
        log " Actualizando DNS primario en nic.cl para dominio $1.cl"
	# solicitar clave para poder modificar dominio (y recuperar id de la sesión)
	RESULT=`curl --silent "https://www.nic.cl/cgi-bin/ingresa-solicitud?dominio=$1&opcode=M&pantalla=1"  | grep sessionid`
	SESSIONID=${RESULT:95:24}
	# recuperar codigo desde el correo
	AUTH_CODE="u93b29w"
	# enviar código para modificacion y recuperar datos del dominio
	RESULT=`curl --silent --data "pantalla=1&sessionid=$SESSIONID&dominio=$1&opcode=M&stamp=&i=E&auth_code=$AUTH_CODE&Continuar=Continuar" "https://www.nic.cl/cgi-bin/ingresa-solicitud?dominio=sasco&amp;opcode=M&amp;pantalla=1"`
#	echo $RESULT
	exit
}

