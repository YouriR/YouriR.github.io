# Creer-Partages.ps1
# Cree les dossiers partages de BiznesRentab selon la methode AGDLP :
# groupes domaine local (DL_) -> permissions NTFS, groupes globaux (GG_) imbriques dedans.

# --- Parametres ---------------------------------------------------------
$Racine    = "C:\Partages"
$Domaine   = "BIZNESRENTAB"
$OUGroupes = "OU=Groupes,OU=BiznesRentab,DC=ad,DC=biznesrentab,DC=mq"

# Un dossier par ligne : qui a la lecture/ecriture (RW), qui a la lecture seule (RO)
$Partages = @(
    @{ Dossier = "Direction";    RW = @("GG_Direction");            RO = @() }
    @{ Dossier = "Comptabilite"; RW = @("GG_Comptabilite");         RO = @("GG_Direction") }
    @{ Dossier = "RH";           RW = @("GG_RH");                   RO = @() }
    @{ Dossier = "Commercial";   RW = @("GG_Commercial");           RO = @("GG_Direction") }
    @{ Dossier = "Technique";    RW = @("GG_Pole-Technique");       RO = @() }
    @{ Dossier = "Informatique"; RW = @("GG_Service-Informatique"); RO = @() }
    @{ Dossier = "Commun";       RW = @("Domain Users");            RO = @() }
)

# --- 1. Dossier racine --------------------------------------------------
New-Item -Path $Racine -ItemType Directory -Force | Out-Null
# Tout le monde peut lister la racine (ce dossier seulement), seuls les admins y ecrivent
icacls $Racine /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "$Domaine\Domain Users:RX" | Out-Null

# --- 2. Sous-dossiers, groupes DL et permissions NTFS ------------------
foreach ($P in $Partages) {

    $Chemin = Join-Path $Racine $P.Dossier
    New-Item -Path $Chemin -ItemType Directory -Force | Out-Null

    # Droits de base : administrateurs et systeme en controle total
    $Droits = @("Administrators:(OI)(CI)F", "SYSTEM:(OI)(CI)F")

    foreach ($Niveau in "RW", "RO") {

        if ($P[$Niveau].Count -eq 0) { continue }

        $GroupeDL = "DL_Partage-$($P.Dossier)_$Niveau"

        # Creer le groupe domaine local s'il n'existe pas
        if (-not (Get-ADGroup -Filter "Name -eq '$GroupeDL'")) {
            New-ADGroup -Name $GroupeDL -GroupScope DomainLocal -GroupCategory Security `
                -Path $OUGroupes -Description "Acces $Niveau au partage $($P.Dossier)"
        }

        # G -> DL : les groupes globaux entrent dans le groupe domaine local
        Add-ADGroupMember -Identity $GroupeDL -Members $P[$Niveau]

        # DL -> P : le groupe domaine local recoit la permission NTFS
        $Perm = if ($Niveau -eq "RW") { "M" } else { "RX" }
        $Droits += "$Domaine\$($GroupeDL):(OI)(CI)$Perm"
    }

    icacls $Chemin /inheritance:r /grant:r $Droits | Out-Null
    Write-Host "Dossier pret : $Chemin" -ForegroundColor Green
}

# --- 3. Partage reseau avec enumeration basee sur l'acces --------------
if (-not (Get-SmbShare -Name "Partages" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Partages" -Path $Racine `
        -FullAccess "Administrators" -ChangeAccess "$Domaine\Domain Users" `
        -FolderEnumerationMode AccessBased -Description "Partages BiznesRentab" | Out-Null
}

Write-Host "Partage \\SRV-DC01\Partages pret (ABE active)." -ForegroundColor Cyan
