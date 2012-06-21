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
# Este archivo corresponde a la definición general de funciones, se
# podrían utilizar estas directamente en otro proyecto ya que son
# independientes del proyecto EasyVirtualHost
#
# Visite http://dev.sasco.cl/easyvhosts para más detalles.
#

# $1 Nonbre del archivo 
# $2 ¿Qué reemplazar? (se agregara automaticamente llaves {})
# $3 ¿Por qué reemplazar?
function file_replace {
        FILE_REPLACE="/tmp/file_replace_`date +%H%M%S%N`"
        TO=${3//\//\\\/};
        sed s/{$2}/"$TO"/g $1 > $FILE_REPLACE
        mv $FILE_REPLACE $1
}

# $1 Archivo configuración
# $2 Variable que se busca
# $3 Valor por defecto en caso que la variable no se encuentre
function conf_get {
        awk -F = -v var=$2 '{if($1==var)print $2}' $1
}

# $1 Mensaje a enviar al log
function log {
        echo "`date`: $1"
}

# Invertir un string delimitado por puntos
function invertir {
	OIFS=$IFS
	IFS='.'
	AUX=''
	for parte in $1; do
		if [ "$AUX" != "" ]; then
			AUX=".$AUX"
		fi
		AUX="$parte$AUX"
	done
	IFS=$OIFS
	echo $AUX
}

# $1 que
# $2 donde
function in_array {
	OK=1
	for element in $2; do
		if [ "$element" = "$1" ]; then
			OK=0
			break
		fi
	done
	echo $OK
}

# $1 dominio
# $2 usuario
function checkMapDomain {
	OK=1
	if [ ${#MAPDOMAIN[@]} -gt 0 ]; then
		i=0
		while [ $i -lt ${#MAPDOMAIN[@]} ]; do
        		DOMAIN=${MAPDOMAIN[$i]}
	        	USER=${MAPDOMAIN[$i+1]}
	        	if [ "$DOMAIN" = "$1" -a "$USER" = "$2"  ]; then
				OK=0
				break
		        fi
        		i=`expr $i + 2`
		done
	else
		OK=0
	fi
	echo $OK
}

