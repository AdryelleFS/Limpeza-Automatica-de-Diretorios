<#
.SYNOPSIS
    Limpeza automatica de subpastas antigas dentro da pasta Output.

.DESCRIPTION
    Percorre a pasta informada em $PastaOutput, identifica todas as subpastas
    existentes e remove as que tem mais de 2 meses (sem criacao/alteracao
    recente), exceto a pasta "Estrutura Redist", que nunca e removida.
    Gera um relatorio diario (Logs\Relatorio_AAAA-MM-DD.log) com data/hora,
    quantidade de pastas analisadas, pastas excluidas (nome + datas), total
    removido, espaco liberado em disco e eventuais erros/excecoes.

.PARAMETER PastaOutput
    Caminho da pasta a ser analisada. Parametrizado para nao depender de
    valor fixo no corpo do script. Caso nao seja informado na chamada,
    assume o valor default abaixo (ajustar para o ambiente de producao
    antes de implantar).

.NOTES
    Requisito de agendamento: executar semanalmente, toda sexta-feira,
    via Agendador de Tarefas do Windows (ver Documento de Implantacao).
#>

param(
    [string]$PastaOutput = "C:\Output"   # <-- ajustar para o caminho real do ambiente antes de implantar
)

# ===================== CONFIGURACAO DE LOG =====================
$PastaLogs = Join-Path $PSScriptRoot "Logs"

if (-not (Test-Path $PastaLogs)) {
    New-Item -ItemType Directory -Path $PastaLogs -Force | Out-Null
}

$RelatorioLog = Join-Path $PastaLogs "Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Funcao para a escrita do Relatorio.log
function Write-RelatorioLog {
    param($Mensagem)
    Add-Content -Path $RelatorioLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

# ===================== VALIDACOES =====================
if ([string]::IsNullOrWhiteSpace($PastaOutput)) {
    Write-RelatorioLog "ERRO: parametro PastaOutput nao informado e sem valor default valido."
    exit 1
}

if (-not (Test-Path $PastaOutput)) {
    Write-RelatorioLog "ERRO: Diretorio nao encontrado: $PastaOutput"
    exit 1
}

Write-RelatorioLog "Inicio da execucao"
Write-RelatorioLog "Pasta analisada: $PastaOutput"

$DataLimite = (Get-Date).AddMonths(-2)

# Uso de -LiteralPath em vez de passagem livre previne quebra de caminhos com colchetes []
$PastasAnalisadas = (Get-ChildItem -LiteralPath $PastaOutput -Directory -Force).Count

# Contadores
$QntPastasExcluidas = 0

# CORREÇÃO: Força o tipo [double] (ponto flutuante) para garantir precisão e evitar erro de cast em somas sucessivas
[double]$EspacoLiberado = 0

# Lista de pastas efetivamente excluidas
$PastasExcluidas = @()

Get-ChildItem -LiteralPath $PastaOutput -Directory -Force |
    Where-Object {
        ($_.CreationTime -lt $DataLimite -or $_.LastWriteTime -lt $DataLimite) -and
        $_.Name -ne "Estrutura Redist"
    } |
    ForEach-Object {
        $Pasta = $_

        # CORREÇÃO: Adicionado o -LiteralPath.
        # Separamos a consulta Get-ChildItem do Measure-Object para validar se a pasta realmente possui 
        # arquivos antes de tentar medir, impedindo que pastas vazias enviem "nada" pro Measure-Object e quebrem o cálculo.
        $Arquivos = Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
        
        $TamanhoPasta = 0
        if ($null -ne $Arquivos) {
            # Realiza a medida apenas se houverem arquivos identificados
            $Medida = $Arquivos | Measure-Object -Property Length -Sum
            if ($null -ne $Medida.Sum) {
                $TamanhoPasta = $Medida.Sum / 1MB
            }
        }

        try {
            # CORREÇÃO: Adicionado o -LiteralPath no momento da exclusão também para consistência.
            Remove-Item -LiteralPath $Pasta.FullName -Recurse -Force -ErrorAction Stop

            $QntPastasExcluidas++
            $EspacoLiberado += $TamanhoPasta

            $PastasExcluidas += [PSCustomObject]@{
                Nome        = $Pasta.Name
                DataCriacao = $Pasta.CreationTime
                Modificacao = $Pasta.LastWriteTime
            }
        }
        catch {
            Write-RelatorioLog "ERRO ao excluir $($Pasta.Name): $($_.Exception.Message)"
        }
    }

# Passa para o Relatorio.log as informacoes necessarias
Write-RelatorioLog "Total de pastas analisadas: $PastasAnalisadas"
Write-RelatorioLog "Total de pastas excluidas: $QntPastasExcluidas"
Write-RelatorioLog "Total de espaco liberado no disco: $([math]::Round($EspacoLiberado, 2)) MB"

foreach ($Pasta in $PastasExcluidas) {
    Write-RelatorioLog "Pasta excluida: $($Pasta.Nome)"
    Write-RelatorioLog "Data de criacao: $($Pasta.DataCriacao)"
    Write-RelatorioLog "Ultima modificacao: $($Pasta.Modificacao)"
}

Write-RelatorioLog "Fim da execucao"