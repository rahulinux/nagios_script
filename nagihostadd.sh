#!/usr/bin/env bash
Read_Me() {
echo -en "\x0c"
tput bold
cat << '--README--'
This Script Is Created for :- 
  - Auto add Linux Host into NagiOS Server
  - *Required input file with following details 
	
	Hostname:IP_ADDRESS:LONG Name of Host 
	
	Note:- Details Must be Seperated By Colon(:) 
	
Currently this script include with linux host template,
but you can change/add/modify your template.

Name	:- nagihostadd	v 0.1 	Copyright (c) 20013-2014 
Author  :- Rahul Patil<http://www.linuxian.com>	
Created	:- 18 May 2013
Version	:- 0.1 Only supported for Compile NagiOS but you can use by changing varibles 
License :- GPL

Report `nagihostadd.sh` bugs to loginrahul90@gmail.com	
--README--
tput sgr 0
}

#-------------------------------------------
# Variables 
#-------------------------------------------

# Store tmp host.cfg file 
tmpCfg_Dir="/tmp/cfg"
if [[ ! -d $tmpCfg_Dir ]]; then
	mkdir $tmpCfg_Dir
elif  $(ls $tmpCfg_Dir/*.cfg >/dev/null 2>&1 ) ; then
	 mv $tmpCfg_Dir ${tmpCfg_Dir}_$(date +%F_%H_%M_%S)
fi

#-------------------------------------------
#  CHANGE/MODIFY FOLLOWING SETTINGS
#-------------------------------------------

Admin='youradmin@gmail.com'


#-------------------------------------------
#  DO NOT CHANGE/MODIFY FOLLOWING SETTINGS
#-------------------------------------------

# find NagiOS Installed Location
# nagios_dir="$( ( dirname $(which nagios3) || dirname $(which nagios) ) >/dev/null 2>&1  )"
# if [[ -z "${nagios_dir}" ]]; then

	nagios_dir="/usr/local/nagios/"

	# configuration files
	nagCfg="${nagios_dir}/etc/nagios.cfg"

	# binary file of nagios
	nagBin="${nagios_dir}/bin/nagios"
	
	# check_nrpe 
	check_nrpe="${nagios_dir}/libexec/check_nrpe"
	
	#command .cfg
	cmd_cfg="${nagios_dir}/etc/objects/commands.cfg"

# else
	# configuration files
	# nagCfg="/etc/nagios.cfg"

	# binary file of nagios
	# nagBin="${nagios_dir}/nagios"
# fi


#-------------------------------------------
# Functions 
#-------------------------------------------


show_Help() {
cat <<_HELP
Usage: $0 [OPTION]... [FILE]...
	  
Mandatory arguments to long options are mandatory for short options too.
  -f, --file  <filename>        Input file which contains Host details
  -r, --readme                  Read Script Info and Detals
  -v, --verify                  Verify all configuration data

	  
	  
Report $0 bugs to loginrahul90@gmail.com	
_HELP

exit 1
}


# check input file
# if input file not having colon seperated and 4 fields then notify

check_Input_File() {

        if [[ $( awk -F: 'END{ print NF }' $input_file ) -ne 3 ]]; then 
		clear
		echo "
              Number of fileds is less than required
              Input File Should looks like below
               
              Hostname  :    IP_ADDRESS : LONG Name of Host
                 
              Note Details Must be Seperated By Colon
			 "
		exit 1
		fi
                  
            
}



# Test Nagios configuration

test_NagCfg() {

${nagBin} -v ${nagCfg}

}

# Linux Host Template
Host_template() {

count=0
for i in "${HostName[@]}"
do


echo "
#--------------------------------------------------------------------------
# $${HostName[$count]}.cfg
# Added by naghostadd.sh on $(date)
#--------------------------------------------------------------------------

define host{
		name                  linux-box_${HostName[$count]}      ; Name of this template
		use                   generic-host                       ; Inherit default values
		check_period          24x7
		check_interval        5
		retry_interval        1
		max_check_attempts    10
		check_command         check-host-alive
		notification_period   24x7
		notification_interval 30
		notification_options  d,r
		contact_groups        admins
		register              0 					; DONT REGISTER THIS – ITS A TEMPLATE
}

###############################################################################
###############################################################################
#
# HOST DEFINITION
#
###############################################################################
###############################################################################

define host{
		use       linux-box_${HostName[$count]}  		; Inherit default values from a template
		host_name ${HostName[$count]} 	; The name we’re giving to this server
		address   ${IPaddr[$count]} 	; IP address of the server
		check_command check-host-alive
}


# define contact{
		# contact_name clientcontact
		# host_name ${HostName[$count]}
		# use generic-contact
		# alias Nagios client
		# email ${Admin}
# }

# define contactgroup{
		# contactgroup_name groupname
		# host_name ${HostName[$count]}
		# alias "${Long_name[$count]}"
		# members clientcontact,membersof ${HostName[$count]}
# }


###############################################################################
###############################################################################
#
# SERVICE DEFINITIONS
#
###############################################################################
###############################################################################

# Define a service to "ping" the local machine

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       ${HostName[$count]}
        service_description             PING
        check_command                   check_ping!100.0,20%!500.0,60%
        }

		
# Define a service to check the load on the machine.		
define service{
		use                 generic-service
		host_name           ${HostName[$count]}
		service_description CPU Load
		check_command       check_nrpe!check_load
}

# Define a service to check the number of currently logged in
# users on the  machine.  Warning if > 20 users, critical
# if > 50 users.

define service{
		use                         generic-service
		host_name                   ${HostName[$count]}
		service_description         Current Users
		check_command               check_nrpe!check_users
}


# Define a service to check the disk space of the root partition
# on the  machine.  Warning if < 20% free, critical if
# < 10% free space on partition.

define service{
		use                         generic-service
		host_name                   ${HostName[$count]}
		service_description         /dev/hda1 Free Space
		check_command               check_nrpe!check_hda1
}

# Define a service to check the number of currently running procs
# on the  machine.  Warning if > 250 processes, critical if
# > 400 users.
define service{
		use                        generic-service
		host_name                  ${HostName[$count]}
		service_description        Total Processes
		check_command              check_nrpe!check_total_procs
}

define service{
		use                        generic-service
		host_name                  ${HostName[$count]}
		service_description        Zombie Processes
		check_command              check_nrpe!check_zombie_procs
}

# Define a service to check HTTP on the local machine.
# Disable notifications for this service by default, as not all users may have HTTP enabled.
define service{
		use generic-service
		host_name ${HostName[$count]}
		service_description Apache Status
		check_command check_nrpe!check_http
}
" >$tmpCfg_Dir/${HostName[$count]}.cfg

let count=count+1
done

}

#-------------------------------------------
# Build Array from Input file
#-------------------------------------------
HostName=()
IPaddr=()
Long_name=()

create_Template_cfg() {
	while IFS=':' read Hostn Ipadr Longh
	do
			HostName+=( "$Hostn" )
			IPaddr+=( $Ipadr )
			Long_name+=( "${Longh}" )
								
	done <  <(grep -vE "^#|^$" "${input_file}")
}

Populate_template() {

Host_template 

}

Add_host() {
#cfg_file=/usr/local/nagios/etc/objects/linux_host.cfg

for fcfg in $tmpCfg_Dir/*; {
	fcfg=$(basename $fcfg)
	if [ -f $nagios_dir/etc/objects/$fcfg ] && grep -q "$fcfg" $nagCfg ; then
	
				while [[ $REPLAY != "y" ]] || [[ $REPLAY != "n" ]]; do
                        case $REPLAY in
                                y|Y)
								/bin/cp ${nagCfg}  ${nagCfg}_bkp_$(date +%F-%H-%M-%S)  # backup 
								/bin/cp $tmpCfg_Dir/$fcfg  $nagios_dir/etc/objects/$fcfg
								echo -e "\n Host Template Added"
                                
                                break
                                ;;
                                n|N)
									echo "Please Configure host .cfg in nagios.cfg manually..."
                                    exit 1
                                    ;;
                                *)
                                    echo "Seems to be Host Already Added"
                                    read -n 1  -p "Do want to Configure it forcefully .  (y/n)" REPLAY
                                     ;;
								 esac
					done
					
else
/bin/cp $tmpCfg_Dir/$fcfg  $nagios_dir/etc/objects/$fcfg
echo "
#--------------------------------------------------------------------------
# Added by naghostadd.sh on $(date)
#--------------------------------------------------------------------------
cfg_file=$nagios_dir/etc/objects/$fcfg
" >> ${nagCfg}

fi


	}

}

#--------------------------------------------
# Checks weather packages installed or not 
#--------------------------------------------
checks(){

if   [[ ! -x "$nagBin" ]]; then
		echo "Error: NagiOS Core Not Installed"
		exit 1
elif [[ ! "$UID" == "0" ]]; then
     echo
     echo " You need to run this script $(basename $0) as root."
     echo
     exit 1
elif [[ ! -x "$check_nrpe" ]]; then
		echo "Error: check_nrpe Plugin Not Installed"
		exit 1
elif [[ ! -f "$nagCfg" ]]; then
		echo "Error: NagiOS CFG file not found.."
		exit 1
elif  ! grep -q "check_nrpe" "${cmd_cfg}" ; then
		echo "check_nrpe Not Configured in $cmd_cfg"
		
		while [[ $REPLAY != "y" ]] || [[ $REPLAY != "n" ]]; do
                        case $REPLAY in
                                y|Y)
								cp ${cmd_cfg} ${cmd_cfg}_bkp_$(date +%F_%H_%M_%S)   # backup 
								echo "
#--------------------------------------------------------------------------
# Added by naghostadd.sh on $(date)
#--------------------------------------------------------------------------
" >> ${cmd_cfg}
                                echo '
								
define command{
       command_name    check_nrpe
       command_line    $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}' >> ${cmd_cfg}

echo -e "\ncheck_nrpe Template Added"
                                
                                break
                                ;;
                                n|N)
									echo "Please Configure check_nrpe manually..."
                                    exit 1
                                    ;;
                                *)
                                    echo ""
                                    read -n 1  -p "Do want to Configure it.  (y/n)" REPLAY
                                     ;;
                         esac
            done
fi

}


Main() {
	case $1 in 
		
			-f | --file )
				input_file="$2"
				[[ $# -ne 2 ]] && { show_Help; exit 1; };
				check_Input_File
				checks 
				test_NagCfg >/dev/null 2>&1
				[[ $? -ne 0 ]] && { echo "Your NagiOs Already having Some issue.. So Please clear that"; exit 1; }
				create_Template_cfg
				Populate_template
				Add_host
				test_NagCfg && echo "Host Successfully Added.. Now just Reload NagiOS and check from WebGUI."
				;;
			-r | --readme )
				Read_Me
				;;
				-v|--verify)
				test_NagCfg
				;;
			  *)
				show_Help
				;;
	esac
}


Main $*
