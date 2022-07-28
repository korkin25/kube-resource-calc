#!/bin/sh

usage()
{
	cat << END
${0} options:

	--tabbed -- switch pretty output to space delimited (to use in spreadsheets&etc)
END
	exit 1
}

pretty=1

if [ $# -gt 0 ]; then
	if [ "${1}" = "--tabbed" ]; then
		echo Pretty out is off 1>&2
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
		echo Unknown flag
		usage
	fi
fi

pt=prettytable.sh/prettytable.sh

for ns in $(kubectl get ns --no-headers=true | awk '{print $1}'); do
	for type in deploy ds statefulsets; do
		for deploy in $(kubectl -n "${ns}" get "${type}" --no-headers=true 2>/dev/null | awk '{print $1}' ) ; do
		    tmp="$(mktemp)"
			kubectl -n "${ns}" get "${type}" "${deploy}" -o json > "${tmp}"
			replicas=$(jq '" \(.spec.replicas) "' < "${tmp}"| sed -r 's/("|\ )//g')
			for container in $(jq '" \(.spec.template.spec.containers[].name)"' < "${tmp}" | sed -r 's/("|\ )//g'); do
				printf "${ns} ${type} ${deploy} ${replicas} ${container}"
				jq '.spec.template.spec.containers[] | select (.name=="'"${container}"'")  | " \(.resources.limits.cpu) \(.resources.limits.memory)"' < "${tmp}" | sed 's/"//g'
				
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
					/bin/bash "${pt}"
				else
					cat | tail -n +2
				fi
			)
