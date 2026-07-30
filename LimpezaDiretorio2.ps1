<#
.SYNOPSIS
    Remove subpastas de $PastaOutput com mais de 2 meses (exceto "Estrutura Redist")
    e gera um relatório de execução.
#>

param(
    [string]$PastaOutput
)

# Caminho padrão do relatório: pasta "Logs" ao lado do próprio script.
# Assim o script funciona em qualquer máquina, sem caminho fixo de usuário.

$PastaLogs = Join-Path $PSScriptRoot "Logs"

# Garante que a pasta de logs existe antes de tentar escrever nela
if (-not (Test-Path $PastaLogs)) {
    New-Item -ItemType Directory -Path $PastaLogs -Force | Out-Null
}

$RelatorioLog = Join-Path $PastaLogs "Relatorio_$(Get-Date -Format 'yyyy-MM-dd').log"

# Função para a escrita do Relatorio.log
function Write-RelatorioLog {
    param($Mensagem)
    Add-Content -Path $RelatorioLog `
        -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Mensagem"
}

# Registros de erros:
# Verifica se a pasta existe, caso não exista, apresenta uma mensagem de erro
if (-not (Test-Path $PastaOutput)) {
    Write-RelatorioLog "ERRO: Diretório não encontrado: $PastaOutput"
    exit
}

Write-RelatorioLog "Início da execução"

# Data limite para que a pasta seja apagada
$DataLimite = (Get-Date).AddMonths(-2)

# Quantidade de pastas analisadas
$PastasAnalisadas = (Get-ChildItem $PastaOutput -Directory).Count

# Contador para contabilizar a quantidade de pastas excluídas
$QntPastasExcluidas = 0

# O espaço que é liberado no disco ao excluir as pastas (em MB)
$EspacoLiberado = 0

# Array de pastas excluídas com seu nome, data de criação e modificação
$PastasExcluidas = @()

# Listar as pastas dentro de Output
Get-ChildItem $PastaOutput -Directory |

    # Enquanto a pasta tiver mais de 2 meses e for diferente de "Estrutura Redist" será apagada
    Where-Object {
        ($_.CreationTime -lt $DataLimite -or
        $_.LastWriteTime -lt $DataLimite) -and
        $_.Name -ne "Estrutura Redist"
    } |

    # Exclui as pastas que atendem ao critério e, somente se a exclusão for
    # bem-sucedida, contabiliza e registra no relatório.
    ForEach-Object {

        # Guarda o objeto da pasta em uma variável própria ANTES do try/catch.
        # Isso é essencial porque dentro do bloco catch o "$_" automático
        # passa a se referir ao erro (ErrorRecord), não mais à pasta -
        # era esse o motivo do log de erro sair vazio no script original.
        $Pasta = $_

        # Soma o tamanho de todos os arquivos da pasta antes de excluir,
        # para saber quanto espaço será liberado.
        $Medida = Get-ChildItem $Pasta.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum
        $TamanhoPasta = if ($Medida.Sum) { $Medida.Sum / 1MB } else { 0 }

        # Caso o usuário em questão não possua permissão ou a pasta esteja bloqueada,
        # apresenta a mensagem de erro no relatório e NÃO contabiliza a pasta como excluída.
        try {
            Remove-Item $Pasta.FullName -Recurse -Force -ErrorAction Stop

            # Só chega aqui se a exclusão realmente funcionou -
            # por isso a contabilização (contador, espaço liberado e lista)
            # fica dentro do try, e não antes dele.
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

# Passa para o Relatorio.log as informações necessárias
Write-RelatorioLog "Total de pastas analisadas: $PastasAnalisadas"
Write-RelatorioLog "Total de pastas excluidas: $QntPastasExcluidas"
Write-RelatorioLog "Total de espaço liberado no disco: $([math]::Round($EspacoLiberado, 2)) MB"

foreach ($Pasta in $PastasExcluidas) {
    Write-RelatorioLog "Pasta excluída: $($Pasta.Nome)"
    Write-RelatorioLog "Data de criação: $($Pasta.DataCriacao)"
    Write-RelatorioLog "Última modificação: $($Pasta.Modificacao)"
}

Write-RelatorioLog "Fim da execução"