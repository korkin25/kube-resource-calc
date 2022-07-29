#!/bin/bash

JQ="/usr/bin/jq"
BASH="/bin/bash"
TAIL="/usr/bin/tail"
SED="/usr/bin/sed"
WGET="/usr/bin/wget"
MD5SUM="/usr/bin/md5sum"
KUBECTL="/usr/local/bin/kubectl"
AWK="/usr/bin/awk"
RM="/usr/bin/rm"
CAT="/usr/bin/cat"
ECHO="/usr/bin/echo"
TEE="/usr/bin/tee"
GREP="/usr/bin/grep"
MKTEMP="/usr/bin/mktemp"
DIRNAME="/usr/bin/dirname"



usage()
{
	${CAT} << END 1>&2
${0} options:

	--tabbed -- switch pretty output to space delimited (to use in spreadsheets&etc)
END
	exit 1
}

log(){
	${ECHO} "--- ${*}" 1>&2
}


pretty=1

if [ $# -gt 0 ]; then
	if [ "${1}" = "--tabbed" ]; then
		log Pretty out is off 
		pretty=0
		shift
	fi
	if [ "${1}" = "--help" ]; then
		usage
	fi
	if [ "${1}" = "-h" ]; then
		usage
	fi	
	if [ -n "${1}" ]; then
		log Unknown flag
		usage
	fi
fi

pt_url="https://github.com/jakobwesthoff/prettytable.sh/raw/c5d52169e9bf6ab6a56595f8a9084e9bcd30bc5a/prettytable.sh"
pt_md5="404f68d34943f8ca20aa326d0c79ca23"

md5_check() {
	if [ $# -ne 2 ]; then
		log Usage: md5_check "${pt_md5} pretytable.sh" 
		exit 1
	fi
	
	${ECHO} "${1} ${2}" | "${MD5SUM}" -c 1>&2
	return $?
}

download_pretytable() {
	local pt="${1}"
	log "Downloading ${pt_url} -> ${pt}"
	wget_log="$(${MKTEMP})"
	log "$("${WGET}" -c -t 3 -O "${pt}" "${pt_url}" 2>&1 | ${TEE} "${wget_log}" | ${GREP} saved )"
	
	if md5_check "${pt_md5}" "${pt}"; then
		log  "MD5 sum checked"
	else
		log "Unable to download prettytable.sh from ${pt_url} and save to ${pt}"
		${CAT} "${wget_log}" 1>&2
		exit 1
	fi
	${RM} "${wget_log}"
}

pt="$(${DIRNAME} "${0}")/prettytable.sh/prettytable.sh"

if [ ! -r "${pt}" ]; then
	pt="${0}.prettytable.sh"
	if [ ! -r "${pt}" ]; then
		download_pretytable "${pt}"
	else
		
		if md5_check "${pt_md5}" "${pt}"; then
			log Using cached "${pt}"
		else
			download_pretytable "${pt}"
		fi
	fi
fi



for ns in $("${KUBECTL}" get ns --no-headers=true | ${AWK} '{print $1}'); do
	for type in deploy ds statefulsets; do
		for deploy in $("${KUBECTL}" -n "${ns}" get "${type}" --no-headers=true 2>/dev/null | ${AWK} '{print $1}' ) ; do
			tmp="$(${MKTEMP})"
			"${KUBECTL}" -n "${ns}" get "${type}" "${deploy}" -o json > "${tmp}"
			replicas=$("${JQ}" '" \(.spec.replicas) "' < "${tmp}"| "${SED}" -r 's/("|\ )//g')
			for container in $("${JQ}" '" \(.spec.template.spec.containers[].name)"' < "${tmp}" | "${SED}" -r 's/("|\ )//g'); do
                    		printf "${ns} ${type} ${deploy} ${replicas} ${container}"
                    		"${JQ}" '.spec.template.spec.containers[] | select (.name=="'"${container}"'")  | " \(.resources.limits.cpu) \(.resources.limits.memory)"' < "${tmp}" | "${SED}" 's/"//g'
			done
			${RM} "${tmp}"
		done
	done
done | 
	${AWK} '
		function get_num_by_suff(str,suff) {
			if (index(str,suff) !=0 ) {
					split(str,num,suff)
					return(num[1])
			} else {
				return(str)
			}
		}
		function calc_cpu(cpus){
			if (index(cpus,"null") == 0 ) {
				suff="m"
				if (index(cpus,suff) !=0 ) {
					return(get_num_by_suff(cpus,suff)/1000)
				}else {
					return(cpus)
				}
			}else{
				return(0)
			}
		}
		function calc_ram(ram){
			if (index(ram,"null") == 0 ) {
				suff="Mi"
				if (index(ram,suff) !=0 ) {
					return(get_num_by_suff(ram,suff))
				}else{
					suff="Gi"
					if (index(ram,suff) !=0 ) {
						return(get_num_by_suff(ram,suff)*1024)
					}else {
						suff="Ki"
						if (index(ram,suff) !=0 ) {
							return(get_num_by_suff(ram,suff)/1024)
						} else {
							return(ram)
						}						
					}

				}
			}else{
				return(0)
			}			
		}
		BEGIN {printf("namespace\ttype\tname\treplicas\tcontainer\tcpu\tmemory\n")}
		{ 
			printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1,$2,$3,$4,$5,calc_cpu($6),calc_ram($7))
		}' | 
			(
				if [ "${pretty}" -eq 1 ]; then
					cmd="${BASH} ${pt}"
				else
					cmd="${CAT} | ${TAIL} -n +2"
				fi
				$cmd
			)
