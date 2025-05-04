
# 💻 Active Directory sous PowerShell

Configuration d'un contrôleur de domaine Active Directory via PowerShell, en partant d'un serveur Windows 2012 R2 propre.

---

## Étapes de configuration

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

### 📦 5. Module PowerShell AD (Windows Server 2012 R2)

```powershell
Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
```
![Image](https://github.com/user-attachments/assets/412eb7de-4dd6-4dbf-8dba-7b6719e37368)
---

### 📄 6. Import d’utilisateurs via un fichier CSV

#### Exemple de chemin :
```powershell
$CSVFile = "C:\Users\Administrateur\Scripts\AD_USERS\Utilisateurs.csv"
$CSVData = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
```

---

---


### 7. Création des utilisateurs + les groupes dans l'OU personnel 

```Paramètres --
$CSVFile = "C:\Users\Administrateur\Scripts\AD_USERS\Utilisateurs.csv"
$CSVData = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8

-- Création des groupes AD dans l'OU "Personnel" s'ils n'existent pas ---
$TousLesGroupes = @()

foreach ($Utilisateur in $CSVData) {
    $GroupesUtilisateur = @($Utilisateur.groupe1, $Utilisateur.groupe2, $Utilisateur.groupe3, $Utilisateur.groupe4, $Utilisateur.groupe5, $Utilisateur.groupe6)
    $TousLesGroupes += $GroupesUtilisateur | Where-Object { $_ -and $_ -ne "" }
}

$GroupesUniques = $TousLesGroupes | Sort-Object -Unique

foreach ($Groupe in $GroupesUniques) {
    # Vérifier si le groupe existe déjà dans l'OU "Personnel"
    if (-not (Get-ADGroup -Filter { Name -eq $Groupe } -SearchBase "OU=Personnel,DC=laplateforme,DC=io")) {
        # Créer le groupe dans l'OU "Personnel"
        New-ADGroup -Name $Groupe -GroupScope Global -GroupCategory Security -Path "OU=Personnel,DC=laplateforme,DC=io"
        Write-Output "? Groupe créé dans 'Personnel' : $Groupe"
    } else {
        Write-Output "?? Groupe déjà existant dans 'Personnel' : $Groupe"
    }
}

----- Création des utilisateurs + ajout aux groupes -----
foreach ($Utilisateur in $CSVData) {
    $UtilisateurPrenom = $Utilisateur.Prénom
    $UtilisateurNom = $Utilisateur.Nom
    if (-not $UtilisateurPrenom -or -not $UtilisateurNom) {
        Write-Warning "Utilisateur avec prénom ou nom vide : ignoré"
        continue
    }

    $UtilisateurLogin = ($UtilisateurPrenom.Substring(0,1).ToLower()) + "." + ($UtilisateurNom.ToLower())
    $UtilisateurEmail = "$UtilisateurLogin@laplateforme.io"
    $UtilisateurMotDePasse = "Azerty_2025!"  # Mot de passe par défaut
    $UtilisateurFonction = $Utilisateur.Fonction

    if (Get-ADUser -Filter { SamAccountName -eq $UtilisateurLogin }) {
        Write-Warning "L'identifiant $UtilisateurLogin existe déjà dans l'AD"
        continue
    }

    try {
        # Créer l'utilisateur dans l'OU "Personnel"
        New-ADUser -Name "$UtilisateurNom $UtilisateurPrenom" `
            -DisplayName "$UtilisateurNom $UtilisateurPrenom" `
            -GivenName $UtilisateurPrenom `
            -Surname $UtilisateurNom `
            -SamAccountName $UtilisateurLogin `
            -UserPrincipalName "$UtilisateurLogin@laplateforme.io" `
            -EmailAddress $UtilisateurEmail `
            -Title $UtilisateurFonction `
            -Path "OU=Personnel,DC=laplateforme,DC=io" `
            -AccountPassword (ConvertTo-SecureString $UtilisateurMotDePasse -AsPlainText -Force) `
            -ChangePasswordAtLogon $true `  # L'utilisateur devra changer son mot de passe au premier logon
            -Enabled $true  # Activer le compte par défaut

        Write-Output "Création de l'utilisateur : $UtilisateurLogin ($UtilisateurNom $UtilisateurPrenom)"

        Start-Sleep -Seconds 2  # Petite pause pour laisser le temps à l'AD de répercuter la création

        # Ajouter l'utilisateur aux groupes dans l'OU "Personnel"
        $Groupes = @($Utilisateur.groupe1, $Utilisateur.groupe2, $Utilisateur.groupe3, $Utilisateur.groupe4, $Utilisateur.groupe5, $Utilisateur.groupe6)
        foreach ($Groupe in $Groupes) {
            if ($Groupe -and (Get-ADGroup -Filter { Name -eq $Groupe } -SearchBase "OU=Personnel,DC=laplateforme,DC=io")) {
                try {
                    Add-ADGroupMember -Identity $Groupe -Members $UtilisateurLogin
                    Write-Output "? $UtilisateurLogin ajouté au groupe $Groupe"
                } catch {
                    Write-Warning "Erreur lors de l'ajout de $UtilisateurLogin au groupe $Groupe : $_"
                }
            } elseif ($Groupe) {
                Write-Warning "?? Groupe non trouvé dans 'Personnel' : $Groupe"
            }
        }

    } catch {
        Write-Warning "? Erreur lors de la création de $UtilisateurLogin : $_"
    }
}


```powershell
New-ADUser -Name "Nom Prénom" ...
Add-ADGroupMember -Identity $Groupe -Members $UtilisateurLogin
```
![Image](https://github.com/user-attachments/assets/32bc932e-b94d-451e-89a5-3a9126dc7a60)
![Image](https://github.com/user-attachments/assets/febba07f-2d95-4b83-82c0-84d5f1407733)
---

###  8. Contraintes rencontrées

> Une règle ICMPv4 a dû être ajoutée dans le pare-feu (serveur + client) pour permettre l’intégration des postes clients au domaine.  .

---
## Téléchargement des machines virtuelles

- [Machines virtuelles VirtualBox (Windows Server & Windows 10 Client)](https://drive.google.com/drive/folders/1BSUC_SzOkHZSsCg_-OQ_1rUBm0-8Qw2Z?usp=drive_link)

---

## ✅ Tests réalisés

- Création des Utilisateurs et les groupes dans l'OU Personnel avec le script et le fichier CSV.
- Des tests ont été effectués pour vérifier l'intégration des machines clientes au domaine Active Directory. Ces tests incluent la connexion des clients, la résolution DNS, ainsi que la création automatique des utilisateurs et groupes.

---

### 🗂️ Références: Florian Burnel - Documentation -> Active Directory : L'adiminister sous powershell 
[https://www.librinova.com/librairie/florian-burnel/active-directory-l-administrer-avec-powershell](https://www.librinova.com/librairie/florian-burnel/active-directory-l-administrer-avec-powershell)
