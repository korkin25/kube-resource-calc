#!/bin/sh

pt=prettytable.sh/prettytable.sh

for ns in $(kubectl get ns --no-headers=true | awk '{print $1}'); do
	for type in deploy ds statefulsets; do
		for deploy in $(kubectl -n "${ns}" get "${type}" --no-headers=true 2>/dev/null | awk '{print $1}' ) ; do
		    tmp="$(mktemp)"
			kubectl -n "${ns}" get "${type}" "${deploy}" -o json > "${tmp}"
			replicas=$(cat "${tmp}" | jq '" \(.spec.replicas) "' | sed -r 's/("|\ )//g')
			for container in $(cat "${tmp}" | jq '" \(.spec.template.spec.containers[].name)"' | sed -r 's/("|\ )//g'); do
				printf "${ns} ${type} ${deploy} ${replicas} ${container}"
				cat "${tmp}" | jq '.spec.template.spec.containers[] | select (.name=="'${container}'")  | " \(.resources.limits.cpu) \(.resources.limits.memory)"' | sed 's/"//g'
				
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
		{ 
			printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1,$2,$3,$4,$5,calc_cpu($6),calc_ram($7))
		}' | bash "${pt}"
