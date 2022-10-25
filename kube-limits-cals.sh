#!/bin/bash


#### prettytable related code is imported from https://github.com/jakobwesthoff/prettytable.sh

####
# Copyright (c) 2016-2021
#   Jakob Westhoff <jakob@westhoffswelt.de>
#
####

_prettytable_char_top_left="┌"
_prettytable_char_horizontal="─"
_prettytable_char_vertical="│"
_prettytable_char_bottom_left="└"
_prettytable_char_bottom_right="┘"
_prettytable_char_top_right="┐"
_prettytable_char_vertical_horizontal_left="├"
_prettytable_char_vertical_horizontal_right="┤"
_prettytable_char_vertical_horizontal_top="┬"
_prettytable_char_vertical_horizontal_bottom="┴"
_prettytable_char_vertical_horizontal="┼"


# Escape codes

# Default colors
_prettytable_color_blue="0;34"
_prettytable_color_green="0;32"
_prettytable_color_cyan="0;36"
_prettytable_color_red="0;31"
_prettytable_color_purple="0;35"
_prettytable_color_yellow="0;33"
_prettytable_color_gray="1;30"
_prettytable_color_light_blue="1;34"
_prettytable_color_light_green="1;32"
_prettytable_color_light_cyan="1;36"
_prettytable_color_light_red="1;31"
_prettytable_color_light_purple="1;35"
_prettytable_color_light_yellow="1;33"
_prettytable_color_light_gray="0;37"

# Somewhat special colors
_prettytable_color_black="0;30"
_prettytable_color_white="1;37"
_prettytable_color_none="0"

function _prettytable_prettify_lines() {
   cat - | sed -e "s@^@${_prettytable_char_vertical}@;s@\$@	@;s@	@	${_prettytable_char_vertical}@g"
}

function _prettytable_fix_border_lines() {
   cat - | sed -e "1s@ @${_prettytable_char_horizontal}@g;3s@ @${_prettytable_char_horizontal}@g;\$s@ @${_prettytable_char_horizontal}@g"
}

function _prettytable_colorize_lines() {
   local color="$1"
   local range="$2"
   local ansicolor="$(eval "echo \${_prettytable_color_${color}}")"

   cat - | sed -e "${range}s@\\([^${_prettytable_char_vertical}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${_prettytable_color_none}m@g"
}

function prettytable() {
   local cols="${1}"
   local color="${2:-none}"
   local input="$(cat -)"
   local header="$(echo -e "${input}"|head -n1)"
   local body="$(echo -e "${input}"|tail -n+2)"
   {
      # Top border
      echo -n "${_prettytable_char_top_left}"
      for i in $(seq 2 ${cols}); do
         echo -ne "\t${_prettytable_char_vertical_horizontal_top}"
      done
      echo -e "\t${_prettytable_char_top_right}"

      echo -e "${header}" | _prettytable_prettify_lines

      # Header/Body delimiter
      echo -n "${_prettytable_char_vertical_horizontal_left}"
      for i in $(seq 2 ${cols}); do
         echo -ne "\t${_prettytable_char_vertical_horizontal}"
      done
      echo -e "\t${_prettytable_char_vertical_horizontal_right}"

      echo -e "${body}" | _prettytable_prettify_lines

      # Bottom border
      echo -n "${_prettytable_char_bottom_left}"
      for i in $(seq 2 ${cols}); do
         echo -ne "\t${_prettytable_char_vertical_horizontal_bottom}"
      done
      echo -e "\t${_prettytable_char_bottom_right}"
   } | column -t -s $'\t' | _prettytable_fix_border_lines | _prettytable_colorize_lines "${color}" "2"
}

#### end of imported code

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

required_stack="jq bash tail sed wget kubectl awk"
for cmd in $required_stack; do
   cmd_test="$(which "${cmd}" )"
   if [ ! -x "${cmd_test}" ]; then
      log Need "${cmd}"
      exit 1
   fi
   declare "${cmd}"="${cmd_test}"
done

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

for ns in $("${kubectl}" get ns --no-headers=true | "${awk}" '{print $1}'); do
   for type in deploy ds statefulsets; do
      for deploy in $("${kubectl}" -n "${ns}" get "${type}" --no-headers=true 2>/dev/null | "${awk}" '{print $1}' ) ; do
         tmp="$(mktemp)"
         "${kubectl}" -n "${ns}" get "${type}" "${deploy}" -o json > "${tmp}"
         if [ "${type}" = "ds" ]; then
            replicas=$("${jq}" '" \(.status.numberAvailable) "' < "${tmp}"| "${sed}" -r 's/("|\ )//g')
         else
            replicas=$("${jq}" '" \(.spec.replicas) "' < "${tmp}"| "${sed}" -r 's/("|\ )//g')
         fi
         for container in $("${jq}" '" \(.spec.template.spec.containers[].name)"' < "${tmp}" | "${sed}" -r 's/("|\ )//g'); do
            printf "${ns} ${type} ${deploy} ${replicas} ${container}"
            "${jq}" '.spec.template.spec.containers[] | select (.name=="'"${container}"'")  | " \(.resources.limits.cpu) \(.resources.limits.memory)"' < "${tmp}" | "${sed}" 's/"//g'
         done
         rm "${tmp}"
      done
   done
done |
"${awk}" '
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
      cmd="prettytable"
   else
      cmd="cat | ${tail} -n +2"
   fi
   $cmd
)

