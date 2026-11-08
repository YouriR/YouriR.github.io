# Creer-Utilisateurs.ps1
# Importe les salaries de BiznesRentab depuis un fichier CSV :
# cree chaque compte dans l'OU de son service et l'ajoute a son groupe global.

# --- Parametres ---------------------------------------------------------
$Domaine    = "DC=ad,DC=biznesrentab,DC=mq"
$Racine     = "OU=BiznesRentab,$Domaine"
$SuffixeUPN = "ad.biznesrentab.mq"
$Fichier    = "C:\Scripts\utilisateurs.csv"

# Mot de passe initial : demande a l'execution, jamais ecrit dans le script
$MotDePasse = Read-Host -AsSecureString "Mot de passe initial des comptes"

# --- Lecture du CSV -----------------------------------------------------
$Utilisateurs = Import-Csv -Path $Fichier -Delimiter ";" -Encoding UTF8

# --- Creation des comptes -----------------------------------------------
foreach ($U in $Utilisateurs) {

    $Login = $U.Login

    # On ne recree pas un compte qui existe deja
    if (Get-ADUser -Filter "SamAccountName -eq '$Login'") {
        Write-Host "Existe deja : $Login" -ForegroundColor Yellow
        continue
    }

    # Parametres du compte, regroupes dans une table (splatting)
    $Parametres = @{
        Name                  = "$($U.Prenom) $($U.Nom)"
        GivenName             = $U.Prenom
        Surname               = $U.Nom
        DisplayName           = "$($U.Prenom) $($U.Nom)"
        SamAccountName        = $Login
        UserPrincipalName     = "$Login@$SuffixeUPN"
        Title                 = $U.Fonction
        Department            = $U.Service
        Company               = "BiznesRentab"
        Path                  = "$($U.OU),$Racine"
        AccountPassword       = $MotDePasse
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    New-ADUser @Parametres
    Add-ADGroupMember -Identity $U.Groupe -Members $Login

    Write-Host "Cree : $Login ($($U.Service))" -ForegroundColor Green
}

Write-Host "Import termine." -ForegroundColor Cyan
