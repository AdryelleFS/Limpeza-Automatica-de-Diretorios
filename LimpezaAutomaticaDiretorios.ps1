# Caminho do arquivo Relatorio.log
$RelatorioLog = "C:\Users\adryelle.sousa\Teste scripts\Logs\Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Função para a escrita do Relatorio.log
function Write-Relatorio-Log {
    param($Mensagem)
    Add-Content -Path $RelatorioLog `
        -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

Write-Relatorio-Log "Início da execução"

# Caminho da pasta Output
$PastaOutput = "C:\Users\adryelle.sousa\Teste scripts\Output"

# Data limite para que a pasta seja apagada
$DataLimite = (Get-Date).AddMonths(-2)

# Quantidade de pastas analisadas
$PastasAnalisadas = (Get-ChildItem $PastaOutput -Directory).Count

# Contador para contabilizar a quantidade de pastas excluidas 
$QntPastasExcluidas = 0

# Array de pastas excluidas com seu nome, data de criação e modificação 
$PastasExcluidas = @()

# Listar as pastas dentro de Output
Get-ChildItem $PastaOutput -Directory | 

#Enquanto a pasta tiver mais de 2 meses e for diferente de "Estrutura Redigist" será apagada 
Where-Object {
    ($_.CreationTime -lt $DataLimite -or
    $_.LastWriteTime -lt $DataLimite) -and
    $_.Name -ne "Estrutura Redist"
} |

# Contabiliza,quarda o nome e a data de criação e modificação das pastas excluidas
# Exclui todas pastas que possuem mais de 2 meses e diferente de "Estrutura Redist" 
ForEach-Object {
    $PastasExcluidas += [PSCustomObject]@{
        Nome = $_.Name
        DataCriacao = $_.CreationTime
        Modificacao = $_.LastWriteTime
    }
    $QntPastasExcluidas++
    Remove-Item $_.FullName -Recurse -Force
}

# Passa para o Relatorio.log  as informações necessárias 
Write-Relatorio-Log "Total de pastas analisadas: $PastasAnalisadas"
Write-Relatorio-Log "Total de pastas excluidas: $QntPastasExcluidas"

foreach($Pasta in $PastasExcluidas){
    Write-Relatorio-Log "Pasta excluída: $($Pasta.Nome)"
    Write-Relatorio-Log "Data de criação: $($Pasta.DataCriacao)"
    Write-Relatorio-Log "Última modificação: $($Pasta.Modificacao)"
}

Write-Relatorio-Log "Fim da execução"

