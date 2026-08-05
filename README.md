# Limpeza-Automatica-de-Diretorios

O Script em questão tem como objetivo automatizar a limpeza de diretórios antigos na pasta Output, 
garantindo a preservação de diretórios específicos e registrando todas as ações executadas.

## Autor
Adryelle Fonseca Sousa

## Data
05/08/2026

## Scripts

### LimpezaDiretorio2.1.ps1

#### Funcionalidades

* **Limpeza Automática:** Exclui subpastas dentro do diretório de `Output` que possuam data de criação ou última modificação superior a 2 meses.
* **Preservação Segura:** Ignora e preserva integralmente a pasta `Estrutura Redist`, independentemente da data.
* **Monitoramento e Logs:** Gera relatórios detalhados contendo a quantidade de pastas analisadas, itens excluídos, espaço liberado e eventuais erros.

#### Pré-requisitos

* Sistema Operacional Windows.
* Privilégios Administrativos (para exclusão forçada de arquivos e pastas).
* Permissão de leitura/escrita no diretório raiz do script (necessário para gerar a pasta de `Logs`).

#### Implantação e Uso (Agendador de Tarefas)

A maneira recomendada de rodar este script é através do **Agendador de Tarefas do Windows** (ex: execução semanal).

1. Abra o **Agendador de Tarefas** e selecione **"Criar Tarefa..."** (não utilize a opção Básica).
2. Na aba **Geral**, marque **"Executar estando o usuário logado ou não"** e **"Executar com privilégios mais altos"**.
3. Na aba **Disparadores**, configure a frequência desejada (ex: Semanalmente, às sextas-feiras, 22:00).
4. Na aba **Ações**, configure a execução do PowerShell:
   * **Ação:** Iniciar um programa.
   * **Programa/script:** `powershell.exe`
   * **Adicione os argumentos:**
     ```powershell
     -ExecutionPolicy Bypass -WindowStyle Hidden -File .\LimpezaDiretorio2.1.ps1 -PastaOutput "C:\Caminho\Para\Output"
     ```
   * **Iniciar em:** Insira o caminho exato da pasta onde o script está salvo (ex: `C:\Scripts\`).

> **Atenção:** Lembre-se de substituir `"C:\Caminho\Para\Output"` pelo caminho real do diretório alvo. Mantenha as aspas no caminho.

## 📊 Logs de Execução

A cada execução (manual ou agendada), o script verifica e limpa os arquivos de forma silenciosa (sem abrir telas). Os resultados são salvos em uma pasta `Logs` gerada automaticamente no mesmo local do script.

O arquivo gerado terá o formato `Relatorio_YYYY-MM-DD.log` e listará:
- Horário de início e fim.
- Total de pastas analisadas e removidas.
- Quantidade de arquivos apagados e o espaço liberado.
















