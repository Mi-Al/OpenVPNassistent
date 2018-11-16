#!/bin/bash

# Mi-Al/OpenVPNassistent
VERS="20181014"

if [[ -d "configs" ]]; then
	echo ""
else
	mkdir configs
fi

if [[ "$(locale | grep LANG | grep -o ru)" == "ru" ]]; then
	LANGUAGE="Russian"
else
	LANGUAGE="English"
fi

source $(dirname $0)/lang/main.sh

currDir="$(pwd)"

clear

echo -e ${Lang[Strings3]}
read -n 1 -s -r -p "${Lang[Strings8]}"
echo
echo
echo -e ${Lang[Strings5]}
read -n 1 -s -r -p "${Lang[Strings8]}"
echo

which pacman > /dev/null 2>&1
if [[ $? -eq '0' ]]; then
	DebianOrArch="Arch"
	echo  -e ${Lang[Strings2]}
else
	which apt > /dev/null 2>&1
	if [ $? -eq '0' ]; then
		DebianOrArch="Debian"
		echo  -e ${Lang[Strings2]}
	else
	echo -e ${Lang[Strings1]}
	exit 1;
	fi
fi

which openvpn > /dev/null 2>&1
if [[ $? -eq '0' ]]; then
	echo  -e ${Lang[Strings4]}
else
	read  -p "${Lang[Strings6]}" -e -i "y" installOpenVPN
	if [[ "$installOpenVPN" == "n" || "$installOpenVPN" == "N" ]]; then
		echo -e ${Lang[Strings7]}
		exit 1;
	else
		if [[ "$DebianOrArch" == "Arch" ]]; then
			sudo pacman -Sy
			sudo pacman -S openvpn easy-rsa --noconfirm
		elif [[ "$DebianOrArch" == "Debian" ]]; then
			sudo apt update
			sudo apt -y install openvpn easy-rsa
		fi
	fi
fi

if [[ !(-d "/usr/share/easy-rsa/") && !(-d "/etc/easy-rsa/") ]]; then
	read  -p "${Lang[Strings20]}" -e -i "y" installeasyrsa
	if [[ "installeasyrsa" == "n" || "installeasyrsa" == "N" ]]; then
		echo -e ${Lang[Strings21]}
		exit 1;
	else
		if [[ "$DebianOrArch" == "Arch" ]]; then
			sudo pacman -Sy
			sudo pacman -S easy-rsa --noconfirm
		elif [[ "$DebianOrArch" == "Debian" ]]; then
			sudo apt update
			sudo apt -y install easy-rsa
		fi
	fi
fi

if [[ "$DebianOrArch" == "Arch" ]]; then
	if [[ -e "/etc/easy-rsa/pki/ca.crt" && -e "/etc/easy-rsa/pki/private/ca.key" ]]; then
		echo -e ${Lang[Strings9]}
	else
		read  -p "${Lang[Strings10]}" -e -i "y" createAC
		if [[ "$createAC" == "n" || "$createAC" == "N" ]]; then
			echo -e ${Lang[Strings11]}
			exit 1;
		else
			echo -e ${Lang[Strings12]}
			cd /etc/easy-rsa
			export EASYRSA=$(pwd)
			easyrsa init-pki
			easyrsa build-ca
			cd $currDir
		fi
	fi
elif [[ "$DebianOrArch" == "Debian" ]]; then
	if [[ -e "/usr/share/easy-rsa/pki/ca.crt" && -e "/usr/share/easy-rsa/pki/private/ca.key" ]]; then
		echo -e ${Lang[Strings9]}
	else
		read  -p "${Lang[Strings10]}" -e -i "y" createAC
		if [[ "$createAC" == "n" || "$createAC" == "N" ]]; then
			echo -e ${Lang[Strings11]}
			exit 1;
		else
			echo -e ${Lang[Strings12]}
			cd /usr/share/easy-rsa
			#cp openssl-easyrsa.cnf openssl.cnf
			#source ./vars
			#./clean-all
			#./build-ca
			export EASYRSA=$(pwd)
			./easyrsa init-pki
			./easyrsa build-ca
			cd $currDir
		fi
	fi
fi

echo -e ${Lang[Strings14]}
read  -p "${Lang[Strings15]}" -e -i "2" quantityofclients
read  -p "${Lang[Strings16]}" serverIP
read  -p "${Lang[Strings17]}" -e -i "1194" serverPORT


if [[ "$DebianOrArch" == "Arch" ]]; then
	cd /etc/easy-rsa
	easyrsa gen-req server nopass
	easyrsa sign-req server server
	openssl dhparam -out /tmp/dh2048.pem 2048
	openvpn --genkey --secret /tmp/ta.key


cat > $currDir/configs/server.opvn << _EOF_
port $serverPORT
 
proto udp
 
dev tun

server 10.8.0.0 255.255.255.0
 
ifconfig-pool-persist ipp.txt
 
push "redirect-gateway def1 bypass-dhcp"
 
keepalive 10 120

remote-cert-tls client
 
cipher AES-256-CBC

persist-key
persist-tun

status openvpn-status.log
 
verb 4

explicit-exit-notify 1

key-direction 0

<ca>
`cat /etc/easy-rsa/pki/ca.crt`
</ca>

<cert>
`cat /etc/easy-rsa/pki/issued/server.crt`
</cert>

<key>
`cat /etc/easy-rsa/pki/private/server.key`
</key>

<dh>
`cat /tmp/dh2048.pem`
</dh>

<tls-auth>
`cat /tmp/ta.key`
</tls-auth>
_EOF_

	for ((i = 1; i <=$quantityofclients; ++i )); do
		easyrsa gen-req "client${i}" nopass
		easyrsa sign-req client "client${i}"

cat > $currDir/configs/"client${i}".opvn << _EOF_
client
 
remote $serverIP

port $serverPORT

dev tun
 
proto udp

resolv-retry infinite

nobind
 
persist-key
persist-tun
 
remote-cert-tls server

cipher AES-256-CBC
 
verb 3

key-direction 1

<ca>
`cat /etc/easy-rsa/pki/ca.crt`
</ca>

<cert>
`cat /etc/easy-rsa/pki/issued/"client${i}".crt`
</cert>

<key>
`cat /etc/easy-rsa/pki/private/"client${i}".key`
</key>

<tls-auth>
`cat /tmp/ta.key`
</tls-auth>
_EOF_
	done
#Очистка
#	rm /etc/easy-rsa/pki/private/server.key
#	for ((i = 1; i <=$quantityofclients; ++i )); do
#		sudo rm /etc/easy-rsa/pki/private/"client${i}.key"
#	done
#	rm /tmp/dh2048.pem
#	rm /tmp/ta.key





elif [[ "$DebianOrArch" == "Debian" ]]; then
	cd /usr/share/easy-rsa
	#./build-key-server server
	#./build-dh
	#openvpn --genkey --secret /tmp/ta.key

	./easyrsa gen-req server nopass
	./easyrsa sign-req server server
	openssl dhparam -out /tmp/dh2048.pem 2048
	openvpn --genkey --secret /tmp/ta.key

cat > $currDir/configs/server.opvn << _EOF_
port $serverPORT
 
proto udp
 
dev tun

server 10.8.0.0 255.255.255.0
 
ifconfig-pool-persist ipp.txt
 
push "redirect-gateway def1 bypass-dhcp"
 
keepalive 10 120

remote-cert-tls client
 
cipher AES-256-CBC

persist-key
persist-tun

status openvpn-status.log
 
verb 4

explicit-exit-notify 1

key-direction 0

<ca>
`cat /usr/share/easy-rsa/pki/ca.crt`
</ca>

<cert>
`cat /usr/share/easy-rsa/pki/issued/server.crt`
</cert>

<key>
`cat /usr/share/easy-rsa/pki/private/server.key`
</key>

<dh>
`cat /tmp/dh2048.pem`
</dh>

<tls-auth>
`cat /tmp/ta.key`
</tls-auth>
_EOF_

	for ((i = 1; i <=$quantityofclients; ++i )); do
		#./build-key "client${i}"
		./easyrsa gen-req "client${i}" nopass
		./easyrsa sign-req client "client${i}"

cat > $currDir/configs/"client${i}".opvn << _EOF_
client
 
remote $serverIP

port $serverPORT

dev tun
 
proto udp

resolv-retry infinite

nobind
 
persist-key
persist-tun
 
remote-cert-tls server

cipher AES-256-CBC
 
verb 3

key-direction 1

<ca>
`cat /usr/share/easy-rsa/pki/ca.crt`
</ca>

<cert>
`cat /usr/share/easy-rsa/pki/issued/"client${i}".crt`
</cert>

<key>
`cat /usr/share/easy-rsa/pki/private/"client${i}".key`
</key>

<tls-auth>
`cat /tmp/ta.key`
</tls-auth>
_EOF_
	done
#Очистка
#	rm /usr/share/easy-rsa/pki/issued/server.crt
#	rm /usr/share/easy-rsa/pki/private/server.key
#	for ((i = 1; i <=$quantityofclients; ++i )); do
#		sudo rm /usr/share/easy-rsa/pki/private/"client${i}.key"
#	done
#	rm /tmp/dh2048.pem
#	rm /tmp/ta.key
fi

echo -e ${Lang[Strings18]}$currDir/configs/
ls -l $currDir/configs/

echo -e ${Lang[Strings19]}

