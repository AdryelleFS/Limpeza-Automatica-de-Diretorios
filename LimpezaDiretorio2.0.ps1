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
# Pasta "Logs" default, criada ao lado do proprio script - nao depende de
# usuario especifico e funciona com qualquer conta de execucao (inclusive
# a conta de servico usada pela Tarefa Agendada).
$PastaLogs = Join-Path $PSScriptRoot "Logs"

if (-not (Test-Path $PastaLogs)) {
    New-Item -ItemType Directory -Path $PastaLogs -Force | Out-Null
}

$RelatorioLog = Join-Path $PastaLogs "Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Funcao para a escrita do Relatorio.log
function Write-RelatorioLog {
    param($Mensagem)
    Add-Content -Path $RelatorioLog `
        -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

# ===================== VALIDACOES =====================
# Protege contra parametro vazio/nulo passado explicitamente (ex.: -PastaOutput ""),
# que faria o Test-Path abaixo lancar um erro nao tratado em vez de uma mensagem clara.
if ([string]::IsNullOrWhiteSpace($PastaOutput)) {
    Write-RelatorioLog "ERRO: parametro PastaOutput nao informado e sem valor default valido."
    exit 1
}

# Verifica se a pasta existe; caso nao exista, registra erro e encerra
if (-not (Test-Path $PastaOutput)) {
    Write-RelatorioLog "ERRO: Diretorio nao encontrado: $PastaOutput"
    exit 1
}

Write-RelatorioLog "Inicio da execucao"
Write-RelatorioLog "Pasta analisada: $PastaOutput"

# Data limite para que a pasta seja apagada (2 meses)
$DataLimite = (Get-Date).AddMonths(-2)

# -Force garante que pastas ocultas/de sistema tambem sejam identificadas
# ("identificar TODAS as pastas existentes", conforme o requisito), e nao
# apenas as visiveis por padrao.
$PastasAnalisadas = (Get-ChildItem $PastaOutput -Directory -Force).Count

# Contador de pastas excluidas
$QntPastasExcluidas = 0

# Espaco liberado no disco (MB)
$EspacoLiberado = 0

# Lista de pastas efetivamente excluidas (nome, criacao, modificacao)
$PastasExcluidas = @()

# Lista as pastas dentro de Output que tem mais de 2 meses e nao sao "Estrutura Redist"
Get-ChildItem $PastaOutput -Directory -Force |
    Where-Object {
        ($_.CreationTime -lt $DataLimite -or $_.LastWriteTime -lt $DataLimite) -and
        $_.Name -ne "Estrutura Redist"
    } |
    ForEach-Object {
        # Guarda o objeto da pasta em variavel propria ANTES do try/catch:
        # dentro do bloco catch, "$_" automatico passa a se referir ao ERRO
        # (ErrorRecord), e nao mais a pasta - por isso os dados sao copiados aqui.
        $Pasta = $_

        # Soma o tamanho de todos os arquivos da pasta ANTES de excluir, para
        # saber quanto espaco sera liberado.
        #
        # CORRECAO IMPORTANTE: esta medicao agora usa -Force, assim como o
        # Remove-Item abaixo. Sem -Force, arquivos ocultos/de sistema dentro
        # da pasta eram removidos normalmente (Remove-Item -Force remove tudo),
        # mas NAO entravam na soma de tamanho (Get-ChildItem sem -Force ignora
        # ocultos/sistema) - por isso o "espaco liberado" do relatorio podia
        # sair menor do que o espaco realmente recuperado no disco.
        $Medida = Get-ChildItem $Pasta.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum
        $TamanhoPasta = if ($Medida.Sum) { $Medida.Sum / 1MB } else { 0 }

        # Caso o usuario nao possua permissao ou a pasta/arquivo esteja em uso,
        # apresenta a mensagem de erro no relatorio e NAO contabiliza a pasta como excluida.
        try {
            Remove-Item $Pasta.FullName -Recurse -Force -ErrorAction Stop

            # So chega aqui se a exclusao realmente funcionou - por isso a
            # contabilizacao (contador, espaco liberado e lista) fica dentro
            # do try, e nao antes dele.
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