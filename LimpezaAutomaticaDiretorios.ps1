# Caminho da pasta Output
param(
    [string]$PastaOutput
)

# Caminho do arquivo Relatorio.log
$RelatorioLog = "C:\Users\adryelle.sousa\Teste scripts\Logs\Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Função para a escrita do Relatorio.log
function Write-Relatorio-Log {
    param($Mensagem)
        Add-Content -Path $RelatorioLog `
        -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

#Registros de erros: 
# Verifica se a pasta existe, caso não exista, apresenta uma mensagem de erro
if (-not (Test-Path $PastaOutput)) {
    Write-Relatorio-Log "ERRO: Diretório não encontrado: $PastaOutput"
    exit
}


Write-Relatorio-Log "Início da execução"

# Data limite para que a pasta seja apagada
$DataLimite = (Get-Date).AddMonths(-2)

# Quantidade de pastas analisadas
$PastasAnalisadas = (Get-ChildItem $PastaOutput -Directory).Count

# Contador para contabilizar a quantidade de pastas excluidas 
$QntPastasExcluidas = 0

# O espaço que é liberado no disco ao excluir as pastas 
$EspacoLiberado = 0

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

    # Soma o tamanho de todos os arquivos da pasta para dar a quantidade de espaço liberado no disco
    $TamanhoPasta = (
    (Get-ChildItem $_.FullName -Recurse -File | 
    Measure-Object Length -Sum).Sum / 1MB
    )

    # Caso o usuário em questão não possuir permissão ou a pasta estiver bloqueada
    #Apresentaa a mensagem de erro no relátorio 
    try {
       Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop

       # Adiciona o tamanho da pasta ao espaço liberado
        $EspacoLiberado += $TamanhoPasta

    }

    catch {
        Write-Relatorio-Log "ERRO ao excluir $($_.Name): $($_.Exception.Message)"
    }
}

# Passa para o Relatorio.log  as informações necessárias   
Write-Relatorio-Log "Total de pastas analisadas: $PastasAnalisadas"
Write-Relatorio-Log "Total de pastas excluidas: $QntPastasExcluidas"
Write-Relatorio-Log "Total de espaço liberado no disco: $([math]::Round($EspacoLiberado, 2)) MB"

foreach($Pasta in $PastasExcluidas){
    Write-Relatorio-Log "Pasta excluída: $($Pasta.Nome)"
    Write-Relatorio-Log "Data de criação: $($Pasta.DataCriacao)"
    Write-Relatorio-Log "Última modificação: $($Pasta.Modificacao)"
}

Write-Relatorio-Log "Fim da execução"