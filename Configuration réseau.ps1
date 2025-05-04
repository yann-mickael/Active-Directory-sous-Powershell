# Définir l'adresse IP, le masque de sous-réseau, et la passerelle par défaut
New-NetIPAddress -IPAddress "192.168.1.5" -PrefixLength 24 -InterfaceIndex (Get-NetAdapter).ifIndex -DefaultGateway "192.168.1.1"

# Définir le serveur DNS (ici on utilise l'adresse 127.0.0.1 comme DNS local)
Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter).ifIndex -ServerAddresses ("127.0.0.1")

# Renommer l'interface réseau de "Ethernet0" à "LAN"
Rename-NetAdapter -Name "Ethernet0" -NewName "LAN"
