# Caminho da pasta Output
$PastaOutput = "C:\Users\adryelle.sousa\Teste scripts\Output"

# Data limite para que a pasta seja apagada
$DataLimite = (Get-Date).AddMonths(-2)

#Listar as pastas dentro de Output
Get-ChildItem $PastaOutput -Directory |

#Enquanto a pasta tiver mais de 2 meses e for diferente de "Estrutura Redigist" será apagada 
Where-Object {
    ($_.CreationTime -lt $DataLimite -or
    $_.LastWriteTime -lt $DataLimite) -and
    $_.Name -ne "Estrutura Redist"
} |
ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force
}
