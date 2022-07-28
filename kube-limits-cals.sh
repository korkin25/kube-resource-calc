#!/bin/bash

usage()
{
	cat << END 1>&2
${0} options:

	--tabbed -- switch pretty output to space delimited (to use in spreadsheets&etc)
END
	exit 1
}

log(){
	echo "--- ${*}" 1>&2
}

jq="$(which jq)"
if [ ! -x "${jq}" ]; then
	log Need jq
	exit 1
fi

bash="$(which bash)"
if [ ! -x "${bash}" ]; then
	log Need bash
	exit 1
fi

tail="$(which tail)"
if [ ! -x "${tail}" ]; then
	log Need tail
	exit 1
fi

sed="$(which sed)"
if [ ! -x "${sed}" ]; then
	log Need sed
	exit 1
fi

wget="$(which wget)"
if [ ! -x "${sed}" ]; then
	log wget not found. It may be required
fi

md5sum="$(which md5sum)"
if [ ! -x "${md5sum}" ]; then
	log md5sum not found. It may be required
fi

kubectl="$(which kubectl)"
if [ ! -x "${kubectl}" ]; then
	log Need kubectl
	exit 1
fi

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
	
	echo "${1} ${2}" | "${md5sum}" -c 1>&2
	return $?
}

download_pretytable() {
	local pt="${1}"
	log "Downloading ${pt_url} -> ${pt}"
	wget_log="$(mktemp)"
	log "$("${wget}" -c -t 3 -O "${pt}" "${pt_url}" 2>&1 | tee "${wget_log}" | grep saved )"
	
	if md5_check "${pt_md5}" "${pt}"; then
		log  "MD5 sum checked"
	else
		log "Unable to download prettytable.sh from ${pt_url} and save to ${pt}"
		cat "${wget_log}" 1>&2
		exit 1
	fi
	rm "${wget_log}"
}

pt="$(dirname "${0}")/prettytable.sh/prettytable.sh"

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



for ns in $("${kubectl}" get ns --no-headers=true | awk '{print $1}'); do
	for type in deploy ds statefulsets; do
		for deploy in $("${kubectl}" -n "${ns}" get "${type}" --no-headers=true 2>/dev/null | awk '{print $1}' ) ; do
			tmp="$(mktemp)"
			"${kubectl}" -n "${ns}" get "${type}" "${deploy}" -o json > "${tmp}"
			replicas=$("${jq}" '" \(.spec.replicas) "' < "${tmp}"| "${sed}" -r 's/("|\ )//g')
			for container in $("${jq}" '" \(.spec.template.spec.containers[].name)"' < "${tmp}" | "${sed}" -r 's/("|\ )//g'); do
                    		printf "${ns} ${type} ${deploy} ${replicas} ${container}"
                    		"${jq}" '.spec.template.spec.containers[] | select (.name=="'"${container}"'")  | " \(.resources.limits.cpu) \(.resources.limits.memory)"' < "${tmp}" | "${sed}" 's/"//g'
			done
			rm "${tmp}"
		done
	done
done | 
	awk '
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
					cmd="${bash} ${pt}"
				else
					cmd="cat | ${tail} -n +2"
				fi
				$cmd
			)
