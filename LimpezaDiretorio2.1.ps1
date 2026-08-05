# Limpeza automatica de subpastas com mais de dois meses dentro da pasta Output, 
# mantendo a pasta "Estrutura Redigist" e gerando um relatório de Log sobre a execução do script.

# Caminho da pasta Output por parametro. 
#Caminho da pasta a ser analisada. Parametrizado para nâo depender de  valor fixo no corpo do script. 

# Requisito de agendamento: executar semanalmente, toda sexta-feira, via Agendador de Tarefas do 
# Windows (ver Documento de Implantacao).


param(
    [string]$PastaOutput = "C:\Output"   # <-- fornecer o caminho real do ambiente no momento da compilação.
)

# Configuração do caminho do arquivo de Log. O arquivo será criado na pasta "Log",
# no mesmo diretório do script. Se a pasta Log não existe, ela será criada automaticamente.  
$PastaLogs = Join-Path $PSScriptRoot "Logs"

if (-not (Test-Path $PastaLogs)) {
    New-Item -ItemType Directory -Path $PastaLogs -Force | Out-Null
}

$RelatorioLog = Join-Path $PastaLogs "Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Função para a escrita do Relatorio.log.
function Write-RelatorioLog {
    param($Mensagem)
    Add-Content -Path $RelatorioLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

# Validações, tratamento de erros e registro de falhas. 
if ([string]::IsNullOrWhiteSpace($PastaOutput)) {
    Write-RelatorioLog "ERRO: parametro PastaOutput nao informado e sem valor default valido."
    exit 1
}

if (-not (Test-Path $PastaOutput)) {
    Write-RelatorioLog "ERRO: Diretorio nao encontrado: $PastaOutput"
    exit 1
}

# Início da execução do script.
Write-RelatorioLog "Inicio da execucao"
Write-RelatorioLog "Pasta analisada: $PastaOutput"

#Tempo limite de dois meses para a exclusão de pastas.
$DataLimite = (Get-Date).AddMonths(-2)

#Quantidade de pastas analisadas, incluindo as que não foram excluídas. Quantidade de pastas em Output.
$PastasAnalisadas = (Get-ChildItem -LiteralPath $PastaOutput -Directory -Force).Count

# Contadores:
$QntPastasExcluidas = 0

# Força o tipo [double] para garantir precisão e evitar erro de cast em somas sucessivas.
[double]$EspacoLiberado = 0

# Lista de pastas efetivamente excluidas.
$PastasExcluidas = @()

# Filtra as pastas de Output que atendem os critérios de exclusão e processa cada uma delas. 
Get-ChildItem -LiteralPath $PastaOutput -Directory -Force |
    Where-Object {
        ($_.CreationTime -lt $DataLimite -or $_.LastWriteTime -lt $DataLimite) -and
        $_.Name -ne "Estrutura Redist"
    } |
    ForEach-Object {
        $Pasta = $_

        $Arquivos = Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
        
        #Tamanho da pasta em MB.
        [double]$TamanhoPasta = 0
        $QtdArquivos = 0

        if ($null -ne $Arquivos) {
            # Realiza a medida apenas se houverem arquivos identificados.
            $Medida = $Arquivos | Measure-Object -Property Length -Sum
            $QtdArquivos = $Medida.Count
            if ($null -ne $Medida.Sum) {
                $TamanhoPasta = $Medida.Sum / 1MB
            }
        }

        #Remove a pasta e incrementa os contadores de pastas excluídas e espaços liberados.
        try {
            Remove-Item -LiteralPath $Pasta.FullName -Recurse -Force -ErrorAction Stop

            $QntPastasExcluidas++

            $EspacoLiberado += $TamanhoPasta

            $PastasExcluidas += [PSCustomObject]@{
                Nome        = $Pasta.Name
                DataCriacao = $Pasta.CreationTime
                Modificacao = $Pasta.LastWriteTime
                TamanhoMB   = $TamanhoPasta
                QtdArquivos = $QtdArquivos
            }
        }
        #Caso ocorra algum erro na exclçusão da pasta, registra o erro no relatório de Log.
        catch {
            Write-RelatorioLog "ERRO ao excluir $($Pasta.Name): $($_.Exception.Message)"
        }
    }

# Passa para o Relatorio.log as informacoes necessárias. 
Write-RelatorioLog "Total de pastas analisadas: $PastasAnalisadas"
Write-RelatorioLog "Total de pastas excluidas: $QntPastasExcluidas"
Write-RelatorioLog "Total de espaco liberado no disco: $([math]::Round($EspacoLiberado, 4)) MB"

foreach ($Pasta in $PastasExcluidas) {
    Write-RelatorioLog "Pasta excluida: $($Pasta.Nome)"
    Write-RelatorioLog "Data de criacao: $($Pasta.DataCriacao)"
    Write-RelatorioLog "Ultima modificacao: $($Pasta.Modificacao)"
    Write-RelatorioLog "Arquivos removidos nesta pasta: $($Pasta.QtdArquivos)"
    Write-RelatorioLog "Espaco liberado por esta pasta: $([math]::Round($Pasta.TamanhoMB, 4)) MB"
}

Write-RelatorioLog "Fim da execucao"