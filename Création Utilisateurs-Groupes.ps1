# === Paramètres ===
$CSVFile = "C:\Users\Administrateur\Scripts\AD_USERS\Utilisateurs.csv"
$CSVData = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8

# === Création des groupes AD dans l'OU "Personnel" s'ils n'existent pas ===
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

# === Création des utilisateurs + ajout aux groupes ===
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
