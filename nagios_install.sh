#!/bin/bash
# Nagios installtion script
# set -e
# Installation LOG
LOG="/var/log/nag.log"
THIS_SCRIPT=$(readlink -f $0)
RELEASE=$(lsb_release -i | awk '{print $3}'| tr A-Z a-z)
# Download location
DOWNLOAD="/etc/downloads"
# Download link
NAGIOS_LINK="http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-3.4.1.tar.gz"
NAGIOS_PLUGIN_LINK="http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.16.tar.gz"
NAGIOS_CLIENT="http://prdownloads.sourceforge.net/sourceforge/nagios/nrpe-2.14.tar.gz"

# Prep 1 - Are we  "root" ?
[[ $UID -ne 0 ]] && echo -e "* $(tput bold)$(tput setaf 3)Please Run This Script as root or use sudo bash $0"$(tput sgr 0) && exit  || echo "We are root: `date`." >> $LOG

#COLORS
RED () { 
  echo "$(tput bold)$(tput setaf 1) $@ $(tput sgr 0)"
}

YELLOW () { 
	echo "$(tput bold)$(tput setaf 2) $@ $(tput sgr 0)"
}

BLUE () { 
	echo "$(tput bold)$(tput setaf 4) $@ $(tput sgr 0)"
}

PINK () { 
	echo "$(tput bold)$(tput setaf 5) $@ $(tput sgr 0)"
}

WHITE () { 
	echo "$(tput bold)$(tput setaf 9) $@ $(tput sgr 0)"
}

CLIENT () {

PACKAGE_CHECKING () 
{
YELLOW "*\Checking Required Packages..."
# check gcc
if ! which gcc > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1 -p "gcc package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "gcc"
			yum install -y "glibc glibc-common"
		else
			echo "Please installed gcc packages"
			exit 1
		fi
	else
	RED "*\GCC Already Installed"
fi

# check openssl-devel

if ! rpm -qi openssl-devel > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "openssl-devel package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "openssl-devel"
		else
			echo "Please installed openssl-devel packages"
			exit 1
		fi
	else
	RED "*\OPENSSL Already Installed"
fi


# xinetd
if ! rpm -qi xinetd > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "xinetd package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "xinetd"
		else
			echo "Please installed xinetd packages"
			exit 1
		fi
	else
	RED "*\XINETD Already Installed"
fi
}

USER_ADD ()
{
# Create Nagios User
if ! grep nagios "/etc/passwd" > /dev/null 2>&1; then
useradd -m nagios

# Create Nagios group
groupadd nagcmd

# Add nagios user and apache user to nagios group
usermod -a -G nagcmd nagios
usermod -a -G nagcmd apache
else
RED "User nagios is already added"
fi

}

DOWNLOAD () 
{
# Create Directory for nagios download
[[  -d $DOWNLOAD ]] || mkdir $DOWNLOAD 

cd $DOWNLOAD
if [ -e nrpe.tar.gz ]; then
RED "NRPE is already downloaded"
find . -type d -name "nrpe*" -exec rm -rf  {} \; > /dev/null 2>&1
PKG_SIZE=$(du -s nrpe.tar.gz | awk '{ print $1}')
	WHITE "Checking Package.."
	if [ $PKG_SIZE -lt "400" ]; then
		RED "Package seems curreputed"
		sleep 1
		YELLOW "Downloading again..."
		sleep 1
		rm -f nagios*
		# Download NRPE
		wget $NAGIOS_CLIENT -O nrpe.tar.gz
	fi
else
	wget $NAGIOS_CLIENT -O nrpe.tar.gz
fi

if [  -e nagios-plugins.tar.gz ]; then
	RED "Nagios-plugins is already downloaded"
	find . -type d -name "nagios*" -exec rm -rf  {} \; > /dev/null 2>&1
_PKG_SIZE=$(du -s nagios-plugins.tar.gz | awk '{ print $1}')
	WHITE "Checking Package...."
	if [ $_PKG_SIZE -lt "2040" ]; then
		RED "Package seems curreputed"
		sleep 1
		YELLOW "Downloading again..."
		sleep 1
		rm -f nagios-plugins.tar.gz	
		# wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.15.tar.gz -O nagios-plugins.tar.gz
		wget $NAGIOS_PLUGIN_LINK -O nagios-plugins.tar.gz
	fi
else
	wget $NAGIOS_PLUGIN_LINK -O nagios-plugins.tar.gz
fi


}

COMPILE ()
{
# Nagios Plugin
{
cd $DOWNLOAD
tar -xzf nagios-plugins.tar.gz
cd nagios-plugins*[0-9]*
WHITE "Compiling Nagios-plugins"
./configure --with-nagios-user=nagios --with-nagios-group=nagios >> $LOG 2>&1 

if [ $? -eq 0 ]; then 
	YELLOW "\* Configure Completed Successfully"
else
	RED 'error while ./configure'
	exit 1
fi

sleep 1
make >> $LOG 2>&1 

if [ $? -eq 0 ]; then
	YELLOW "\* Make Completed Successfully"
else
	RED "error while make" 
	exit 1
fi 
sleep 1
make install >> $LOG 2>&1 

if [ $? -eq 0 ]; then
	YELLOW "\* Make install Completed Successfully"
else
	RED "error while make install" 
	exit 1
fi
}

# NRPE Compilation
{
cd $DOWNLOAD
tar -xzf nrpe.tar.gz
cd nrpe*
WHITE "Compiling NRPE..."
./configure >> $LOG 2>&1 
if [ $? -eq 0 ]; then 
	YELLOW "\* configure Completed Successfully"
else
	RED "error while ./configure"
	exit 1
fi 

sleep 1
wait
make all >> $LOG 2>&1 
if [ $? -eq 0 ]; then 
	YELLOW "\* Make all Completed Successfully"
else
	RED "error while make all" 
	exit 1
fi
sleep 2
wait
make install-plugin >> $LOG 2>&1 
if [ $? -eq 0 ]; then 
	YELLOW "\* Make install-plugin Completed Successfully"
else 
	RED "error while make install-plugin" 
	exit 1
fi

sleep 1
wait
make install-daemon >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-daemon Completed Successfully"
else
	RED "error while make install-daemon" 
	exit 1
fi 

sleep 1
wait
make install-daemon-config >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-daemon-config Completed Successfully"
else
	RED "error while make install-daemon-config" 
	exit 1
fi 

sleep 1
wait
make install-xinetd >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-xinetd Completed Successfully"
else
	RED "error while make install-xinetd" 
	exit 1
fi 
}
}

CLIENT_SETTINGS ()
{
# Configure SERVER IP
while [ x"$SRV_IP" = x ]; do
BLUE "Enter NagiOs Server IP :- "
read  SRV_IP
done

if ! grep "$SRV_IP" /etc/xinet.d/nrpe >/dev/null 2>&1; then
	sed -i "s/only_from       \= 127.0.0.1/only_from       \= 127.0.0.1 $SRV_IP/g" /etc/xinetd.d/nrpe
	service xinetd restart >/dev/null 2>&1
fi

if ! grep "5666" /etc/services >/dev/null 2>&1; then
	echo "nrpe 5666/tcp # NRPE" >> /etc/services
fi

cat <<_EOF
#############################################################
@@@ NEED TO CHECK FOLLOWING THINGS @@@

* Nagios server run:
/usr/local/nagios/libexec/check_nrpe -n -H xxx.xxx.xxx.xxx-p 5666

This time where xxx is the IP address of your remote host(NRPE), you should get back the nagios version.
#############################################################
_EOF
}

# check wheather ubuntu or redhat
CHECK_OS () 
{
if [ "$RELEASE" == "centos" ]; then
	RED "Detecting Redhat base System"
	WHITE "Installing Packages..."
	PACKAGE_CHECKING
	WHITE "Adding nagios user"
	USER_ADD
	DOWNLOAD
	WHITE "Compiling packages"
	COMPILE
	WHITE "Configuring NRPE"
	CLIENT_SETTINGS

elif [ "$RELEASE" == "ubuntu" ]; then
		YELLOW "Detected Debeine base System.."
		WHITE "Installing Packages..."
		DOWNLOAD
		WHITE "Compiling packages"
		# check build-essential
		if ! dpkg-query -S build-essential > /dev/null 2>&1; then
			while [ x"$REPLY" = x ]; do
				read -n 1  -p "build-essential package not found! Install? (y/n) " REPLY
			done
				if [ "$REPLY" == "y" ]; then
					apt-get install build-essential -y
				else
					echo "Please installed build-essential packages"
					exit 1
				fi
			fi		
		COMPILE
		WHITE "Configuring NRPE"
		CLIENT_SETTINGS
else
		RED "lsb_release Packages Not installed Or Unknow os"
fi
}

CHECK_OS
}


SHOW_HELP () {

cat << _EOF
Usage:
	$THIS_SCRIPT [options]
	
Options:
	--setup-client			-sc 	install & setup client
	--install-server		-is 	start NagiOs server installation
	--install-server-debug		-id 	start NagiOs server installation in debug mode
_EOF
}

# Server Related 
SERVER () {


PACKAGE_CHECKING_CENTOS () 
{
# Required Packages
# Apache, PHP, GCC & GD 
# First check this packages if not install then install those packages

# check apache 
if ! which httpd > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1 -p "apache server not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "httpd"
		else
			echo "Please installed apache server packages"
			exit 1
		fi
	fi
# check gcc

if ! which gcc > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "gcc package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "gcc"
			yum install -y "glibc glibc-common"
		else
			echo "Please installed gcc packages"
			exit 1
		fi
	fi

# check gd
if ! rpm -qi gd > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "gd package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "gcc"
			yum install -y "gd-devel"
		else
			echo "Please installed gd packages"
			exit 1
		fi
	fi
	
# Check php
if ! rpm -qi php > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "php package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			yum install -y "php"
		else
			echo "Please installed gcc packages"
			exit 1
		fi
	fi

if [ -d /usr/local/nagios ]; then
RED "NagiOs is already installed"
while [ x"$REPLY" = x ]; do
read -n 1 -p "whould you like to continue? (y/n)" REPLY
	done
		if [ "$REPLY" == "y" ]; then
			YELLOW "Tacking backup of existing nagios to nagios.old"
			sleep 1
			mv /usr/local/nagios /usr/local/nagios.$(date +%F)
		else
			exit 1
		fi
	fi

	
}

PACKAGE_CHECKING_UBUNTU () 
{
# Required Packages
# Apache, PHP, GCC & GD 
# First check this packages if not install then install those packages

# check apache 
if ! which apache2 > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "apache server not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			apt-get install apache2 -y
		else
			echo "Please installed apache server packages"
			exit 1
		fi
	fi


# check build-essential
if ! dpkg-query -S build-essential > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "build-essential package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			apt-get install build-essential -y
		else
			echo "Please installed build-essential packages"
			exit 1
		fi
	fi
	
# Check php
if ! dpkg  -s php5 > /dev/null 2>&1; then
	while [ x"$REPLY" = x ]; do
	read -n 1  -p "php5 package not found! Install? (y/n) " REPLY
	done
		if [ "$REPLY" == "y" ]; then
			apt-get install php5 -y
		else
			echo "Please installed php5 packages"
			exit 1
		fi
	fi

if [ -d /usr/local/nagios ]; then
RED "NagiOs is already installed"
while [ x"$REPLY" = x ]; do
read -n 1 -p "whould you like to continue? (y/n)" REPLY
	done
		if [ "$REPLY" == "y" ]; then
			echo ""
			YELLOW "Tacking backup of existing nagios to nagios.old"
			sleep 1
			mv /usr/local/nagios /usr/local/nagios.$(date +%F)
		else
			exit 1
		fi
	fi

	
}


USER_ADD ()
{
# Create Nagios User
if ! grep nagios "/etc/passwd" > /dev/null 2>&1; then
useradd -m nagios

# Create Nagios group
groupadd nagcmd

# Add nagios user and apache user to nagios group
usermod -a -G nagcmd nagios
usermod -a -G nagcmd apache
fi

}

DOWNLOADING_NAGIOS ()
{
# Create Directory for nagios download
[[  -d $DOWNLOAD ]] || mkdir $DOWNLOAD 

cd $DOWNLOAD
if [ -e nagios.tar.gz ]; then
RED "Nagios is already downloaded"
find . -type d -name "nagios*" -exec rm -rf  {} \; > /dev/null 2>&1
PKG_SIZE=$(du -s nagios.tar.gz | awk '{ print $1}')
	WHITE "Checking Package.."
	if [ $PKG_SIZE -lt "1740" ]; then
		RED "Package seems curreputed"
		sleep 1
		YELLOW "Downloading again..."
		sleep 1
		rm -f nagios.tar.gz
		# Download Nagios and Plugins files
		wget $NAGIOS_LINK -O nagios.tar.gz
	fi
else
	# wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-3.2.3.tar.gz -O nagios.tar.gz
	wget $NAGIOS_LINK -O nagios.tar.gz
fi

if [  -e nagios-plugins.tar.gz ]; then
	RED "Nagios-plugins is already downloaded"
	find . -type d -name "nagios*" -exec rm -rf  {} \; > /dev/null 2>&1
_PKG_SIZE=$(du -s nagios-plugins.tar.gz | awk '{ print $1}')
	WHITE "Checking Package...."
	if [ $_PKG_SIZE -lt "2040" ]; then
		RED "Package seems curreputed"
		sleep 1
		YELLOW "Downloading again..."
		sleep 1
		rm -f nagios-plugins.tar.gz	
		# wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.15.tar.gz -O nagios-plugins.tar.gz
		wget $NAGIOS_PLUGIN_LINK -O nagios-plugins.tar.gz
	fi
else
	wget $NAGIOS_PLUGIN_LINK -O nagios-plugins.tar.gz
fi
}

SETTINGUP_NAGIOS () 
{
# Extract files
cd $DOWNLOAD
# tar -xzf nagios.tar.gz && cd nagios*[0-9]*
tar -xzf nagios.tar.gz && cd nagios
WHITE "Compiling Nagios..."
./configure --with-command-group=nagcmd >> $LOG 2>&1 

if [ $? -eq 0 ]; then 
	YELLOW "\* configure Completed Successfully"
else
	RED "error while ./configure"
	exit 1
fi 

sleep 1

make all >> $LOG 2>&1 
if [ $? -eq 0 ]; then 
	YELLOW "\* Make all Completed Successfully"
else
	RED "error while make all" 
	exit 1
fi

sleep 2

make install >> $LOG 2>&1 

if [ $? -eq 0 ]; then 
	YELLOW "\* Make install Completed Successfully"
else 
	RED "error while make install" 
	exit 1
fi

sleep 1

make install-init >> $LOG 2>&1 

if [ $? -eq 0 ]; then
	YELLOW "\* Make install-init Completed Successfully"
else
	RED "error while make install-init" 
	exit 1
fi 

sleep 1

make install-config >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-config Completed Successfully"
else
	RED "error while make install-config" 
	exit 1
fi
sleep 1

make install-commandmode >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-commandmode Completed Successfully"
else
	RED 'error while make install-commandmode'
	exit 1
fi

sleep 1
make install-webconf >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install-webconf Completed Successfully"
else
	RED 'error while make install-webconf'
	exit 1
fi

sleep 1

# Create Web Interface User account
if [ -e "/usr/local/nagios/etc/htpasswd.users" ]; then
	mv /usr/local/nagios/etc/htpasswd.users /tmp
	BLUE "Enter Password for Web Interface User account \"admin\""
	htpasswd -c /usr/local/nagios/etc/htpasswd.users admin
fi
wait
(/etc/init.d/httpd restart >/dev/null 2>&1) || (/etc/init.d/apache2 restart >/dev/null 2>&1)

# Install Nagios Plugins
cd $DOWNLOAD
tar -xzf nagios-plugins.tar.gz
cd nagios-plugins*[0-9]*
echo ""	
WHITE "Compiling Nagios-plugins"
./configure --with-nagios-user=nagios --with-nagios-group=nagios >> $LOG 2>&1 

if [ $? -eq 0 ]; then 
	YELLOW "\* Configure Completed Successfully"
else
	RED 'error while ./configure'
	exit 1
fi
sleep 1
make >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make Completed Successfully"
else
	RED "error while make" 
	exit 1
fi 
sleep 1
make install >> $LOG 2>&1 
if [ $? -eq 0 ]; then
	YELLOW "\* Make install Completed Successfully"
else
	RED "error while make install" 
	exit 1
fi

echo ""
WHITE  "\* Enable Nagios to start at system startup"
chkconfig --add nagios >/dev/null 2>&1 || update-rc.d -n nagios defaults
chkconfig nagios on >/dev/null 2>&1 
chkconfig httpd on >/dev/null 2>&1 
YELLOW "\* chkconfig Done"
/etc/init.d/nagios restart >/dev/null 2>&1

IP_ADDR=$(ip -f inet addr show dev eth0 | sed -n 's/^ *inet *\([.0-9]*\).*/\1/p')
# Create Web Interface User account
if [ -e "/usr/local/nagios/etc/htpasswd.users" ]||[ ! -e "/usr/local/nagios/etc/htpasswd.users" ]; then
	mv /usr/local/nagios/etc/htpasswd.users /tmp/  >/dev/null 2>&1
	while [ x"$pass" = x ]; do
	BLUE "Enter Password for Web Interface User account \"nagiosadmin\""
	read -s pass
done
	htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin $pass
fi
sleep 2
WHITE "Installation Completed"
WHITE "Now You can access NagiOs via below URL:"
YELLOW "http://$IP_ADDR/nagios"
WHITE "Username : nagiosadmin"
}

# check wheather ubuntu or redhat
CHECK_OS () 
{
if [ "$RELEASE" == "centos" ]; then
	RED "Detecting Redhat base System"
	WHITE "Installing Packages..."
	PACKAGE_CHECKING_CENTOS
	WHITE "Adding nagios user"
	USER_ADD
	DOWNLOADING_NAGIOS
	SETTINGUP_NAGIOS
elif [ "$RELEASE" == "ubuntu" ]; then
	YELLOW "Detected Debeine base System.."
	WHITE "Installing Packages..."
	PACKAGE_CHECKING_UBUNTU
	WHITE "Adding nagios user"
	USER_ADD
	DOWNLOADING_NAGIOS
	#SETTINGUP_NAGIOS
else
	RED "lsb_release Packages Not installed Or Unknow os"
fi
}


CHECK_OS

}

MAIN () {

case "$1" in 
	-h | --help)
			  SHOW_HELP  ;;
	    -sc | --setup-client)
			 CLIENT	 ;;
		-is | --install-server)
			SERVER	;;
		-id | --install-server-debug)
			#set -x
			SERVER	;;
			*)
			SHOW_HELP
esac
}

MAIN $*
