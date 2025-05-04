
# 💻 Active Directory sous PowerShell

Ce projet permet de configurer un contrôleur de domaine Active Directory via PowerShell, en partant d'un serveur Windows propre.

---

## 🔧 Étapes de configuration

### 🖥️ 1. Renommer le serveur
```powershell
Rename-Computer -NewName SRV-LAPLATEFORME -Force 
Restart-Computer
```

---

### 🌐 2. Configuration réseau
Définir une adresse IP statique, une passerelle, le DNS, et renommer l’interface réseau.

```powershell
New-NetIPAddress -IPAddress "192.168.1.5" -PrefixLength "24" -InterfaceIndex (Get-NetAdapter).ifIndex -DefaultGateway "192.168.1.254"
Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter).ifIndex -ServerAddresses ("127.0.0.1")
Rename-NetAdapter -Name Ethernet0 -NewName LAN
```

---

### ⚙️ 3. Installation des rôles et fonctionnalités
Services requis :
- AD DS (Active Directory Domain Services)
- DNS
- RSAT (Outils d'administration graphique)

```powershell
$FeatureList = @("RSAT-AD-Tools", "AD-Domain-Services", "DNS")

foreach ($Feature in $FeatureList) {
    if (((Get-WindowsFeature -Name $Feature).InstallState) -eq "Available") {
        Write-Output "Feature $Feature will be installed now!"
        try {
            Add-WindowsFeature -Name $Feature -IncludeManagementTools -IncludeAllSubFeature
            Write-Output "$Feature : Installation is a success!"
        } catch {
            Write-Output "$Feature : Error during installation!"
        }
    }
}
```

---

### 🏢 4. Création d’un domaine Active Directory

Définir les noms DNS et NetBIOS puis créer la forêt Active Directory.

```powershell
$DomainNameDNS = "Laplateforme.io"
$DomainNameNetbios = "LAPLATEFORME"

$ForestConfiguration = @{
    '-DatabasePath' = 'C:\Windows\NTDS';
    '-DomainMode' = 'Default';
    '-DomainName' = $DomainNameDNS;
    '-DomainNetbiosName' = $DomainNameNetbios;
    '-ForestMode' = 'Default';
    '-InstallDns' = $true;
    '-LogPath' = 'C:\Windows\NTDS';
    '-NoRebootOnCompletion' = $false;
    '-SysvolPath' = 'C:\Windows\SYSVOL';
    '-Force' = $true;
    '-CreateDnsDelegation' = $false
}

Import-Module ADDSDeployment
Install-ADDSForest @ForestConfiguration
```

---

### 📦 5. Module PowerShell AD (Windows Server 2012+)

```powershell
Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
```

---

### 📄 6. Import d’utilisateurs via un fichier CSV

#### Exemple de chemin :
```powershell
$CSVFile = "C:\Users\Administrateur\Scripts\AD_USERS\Utilisateurs.csv"
$CSVData = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
```

---

### 👥 7. Création automatique des groupes AD

Tous les groupes utilisés dans le CSV sont extraits et créés dans l'OU `Personnel`.

```powershell
foreach ($Utilisateur in $CSVData) {
    # Extraction et traitement des groupes...
}
```

---

### 👤 8. Création des utilisateurs et affectation aux groupes

Les utilisateurs sont créés dans l’OU `Personnel` et assignés à leurs groupes, s’ils existent.

```powershell
New-ADUser -Name "Nom Prénom" ...
Add-ADGroupMember -Identity $Groupe -Members $UtilisateurLogin
```

---

### 📛 Contraintes rencontrées

> Une règle ICMPv4 a dû être ajoutée dans le pare-feu (serveur + client) pour permettre l’intégration des postes clients au domaine.  
> Néanmoins, bien que les comptes aient été créés, **l’ajout automatique aux groupes a échoué dans certains cas**.

---

### 📸 Captures d'écran

![Capture 1](image.png)  
![Capture 2](image-1.png)

---

## ✅ À faire

- Vérifier que les groupes sont bien créés dans l'OU `Personnel`.
- S'assurer que les noms et groupes dans le CSV sont bien remplis.
- Ajouter une vérification de retour lors de l’ajout à un groupe AD.

---

## 🗂️ Auteur

Projet réalisé dans le cadre d’un déploiement de maquette Active Directory automatisée via PowerShell.
