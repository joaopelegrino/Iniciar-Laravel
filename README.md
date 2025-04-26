# Laravel Filament Project Starter (Dockerized)

Este repositório fornece um método padronizado e automatizado para iniciar novos projetos web usando a stack Laravel + Filament, rodando em um ambiente Docker consistente via Laravel Sail. Ele inclui ferramentas de qualidade de código pré-configuradas.

**Stack Principal:**

*   PHP 8.3
*   Laravel 11
*   Filament 3
*   Banco de Dados: MySQL (padrão), Redis (opcional via script)
*   Frontend: Vite, Tailwind CSS, Alpine.js (via Filament/Laravel)
*   Ambiente: Docker com Laravel Sail
*   Qualidade: Laravel Pint, Pest, PHPStan, Rector, Enlightn Security Checker

## Pré-requisitos

Antes de começar, garanta que você tenha instalado em sua máquina:

1.  **Docker e Docker Compose:** Essencial para rodar o ambiente. Docker Desktop (Windows/Mac) ou Docker Engine + Docker Compose (Linux).
2.  **Shell Bash:** Necessário para executar o script de criação.
    *   Linux/macOS: Terminal padrão.
    *   Windows: Git Bash (recomendado) ou WSL (Windows Subsystem for Linux).
    *   **Importante:** Se usar WSL ou Git Bash no Windows, use caminhos no formato Linux (ex: `/c/Users/SeuNome/Projetos`) ao interagir com o script.
3.  **Composer:** Necessário globalmente para o passo inicial `composer create-project` dentro do script.
4.  **Git:** Necessário pelo Composer e para controle de versão.
5.  **(Opcional, Recomendado)** `yq`: Uma ferramenta de linha de comando para processar YAML. O script a utiliza para modificar o `docker-compose.yml` de forma mais robusta. Se não encontrado, o script usará `sed` como alternativa.

## Configuração (Apenas uma vez)

1.  **Imagem Docker Base:**
    *   Este projeto utiliza uma imagem Docker base customizada (`joaopelegrino/laravel-filament-base`) que contém PHP 8.3, Composer, Node.js, Git e cliente MySQL.
    *   O `Dockerfile` para esta imagem está em `Site para contexto por zip/Dockerfile.laravel-filament-base` (idealmente, mova este Dockerfile para um local mais genérico, fora de um projeto específico).
    *   Construa e envie a imagem para o seu Docker Hub (substitua `joaopelegrino` se necessário):
        ```bash
        # Navegue até o diretório que contém Dockerfile.laravel-filament-base
        cd /caminho/para/o/Dockerfile

        # Construa com uma tag de versão e atualize 'latest'
        docker build -t joaopelegrino/laravel-filament-base:php8.3-v1.0 -f Dockerfile.laravel-filament-base .
        docker tag joaopelegrino/laravel-filament-base:php8.3-v1.0 joaopelegrino/laravel-filament-base:latest

        # Faça login no Docker Hub
        docker login

        # Envie as tags
        docker push joaopelegrino/laravel-filament-base:php8.3-v1.0
        docker push joaopelegrino/laravel-filament-base:latest
        ```

2.  **Arquivos de Template:**
    *   Os arquivos de configuração padrão (`composer.json.template`, `pint.json.template`, `rector.php.template`, `phpstan.neon.template`) e o script de automação (`criar-novo-projeto-filament.sh`) estão localizados em `Templates-Laravel/`.
    *   **Ajuste o Script:** Abra o arquivo `Templates-Laravel/criar-novo-projeto-filament.sh` e **edite as variáveis** no topo:
        *   `TEMPLATE_DIR`: Defina o caminho **absoluto** para o diretório `Templates-Laravel` na sua máquina (use o formato de caminho do seu shell - ex: `/mnt/c/Programacao/Aplicacao-web/Templates-Laravel` no WSL).
        *   `GIT_USERNAME`: Defina seu nome de usuário do GitHub/GitLab (usado no `composer.json` gerado).
        *   `DOCKER_IMAGE`: Verifique se está correto (`joaopelegrino/laravel-filament-base:latest`).
        *   `SAIL_SERVICES`: Ajuste se precisar de serviços além de `mysql` (ex: `mysql,redis`).
    *   **Crie `phpstan.neon.template`:** Certifique-se de que este arquivo existe no diretório `TEMPLATE_DIR`. Você pode usar o conteúdo fornecido anteriormente como base.

3.  **Torne o Script Executável:**
    *   No seu terminal, navegue até o diretório `Templates-Laravel` e execute:
        ```bash
        chmod +x criar-novo-projeto-filament.sh
        ```

## Criando um Novo Projeto

Com a configuração única feita, criar um novo projeto é simples:

1.  Abra seu terminal.
2.  Execute o script `criar-novo-projeto-filament.sh` passando o nome do projeto e, opcionalmente, o diretório pai onde ele deve ser criado.

    *   **Para criar no diretório atual:**
        ```bash
        # Exemplo: Cria a pasta 'MeuNovoSite' onde você está
        /caminho/para/Templates-Laravel/criar-novo-projeto-filament.sh MeuNovoSite
        ```

    *   **Para criar em um diretório específico:**
        ```bash
        # Exemplo: Cria a pasta 'MeuOutroSite' dentro de /mnt/c/Projetos
        /caminho/para/Templates-Laravel/criar-novo-projeto-filament.sh MeuOutroSite /mnt/c/Projetos
        ```
        *(Lembre-se de usar o formato de caminho correto para seu shell)*

3.  O script pedirá confirmação e então executará todos os passos necessários:
    *   Cria o projeto Laravel.
    *   Copia os arquivos de template (`composer.json`, `pint.json`, etc.).
    *   Instala dependências Composer (incluindo Sail, Filament, Pint, Pest, Stan, Rector).
    *   Publica e configura o Sail para usar sua imagem base Docker.
    *   Inicia os containers Docker (`sail up -d`).
    *   Instala o Filament Panels.
    *   Instala dependências NPM.
    *   Configura o arquivo `.env` (com padrões Sail DB) e gera a chave da aplicação.
    *   Cria o link de storage.
    *   Executa as migrações do banco de dados (com retentativas).
    *   Compila os assets frontend (`npm run build`).
    *   Limpa caches e otimiza.
    *   Opcionalmente, inicializa um repositório Git.

4.  Após a conclusão, siga as instruções exibidas para acessar seu projeto.

## Fluxo de Desenvolvimento

Uma vez que o projeto está criado e o ambiente Sail rodando (`sail up -d`):

*   **Acessar a Aplicação:** `http://localhost` (ou a porta definida em `APP_PORT` no `.env`).
*   **Acessar o Painel Filament:** `http://localhost/admin` (você precisará criar um usuário Filament primeiro, ex: `sail artisan make:filament-user`).
*   **Iniciar/Parar Ambiente:**
    *   `sail up` (inicia e mostra logs, `Ctrl+C` para parar)
    *   `sail up -d` (inicia em background)
    *   `sail stop` (para os containers)
    *   `sail down` (para e remove os containers)
*   **Executar Comandos Artisan:** `sail artisan <comando>` (ex: `sail artisan make:model Produto`)
*   **Executar Comandos Composer:** `sail composer <comando>` (ex: `sail composer require spatie/laravel-permission`)
*   **Executar Comandos NPM/Vite:**
    *   `sail npm run dev` (compilação com hot-reloading)
    *   `sail npm run build` (compilação para produção)
    *   `sail npm install <pacote>`
*   **Executar Ferramentas de Qualidade (via scripts Composer):**
    *   Formatação (Pint): `sail composer pint`
    *   Análise Estática (PHPStan): `sail composer stan`
    *   Refatoração (Rector - verificar mudanças): `sail composer rector --dry-run`
    *   Aplicar Refatoração (Rector): `sail composer rector`
    *   Verificação de Segurança: `sail composer sec-check`
    *   Testes (Pest): `sail composer test`
    *   Testes com Cobertura: `sail composer test-coverage`
*   **Acessar Banco de Dados:** Use um cliente de DB (TablePlus, DBeaver, etc.) conectando em `localhost`, porta `3306` (padrão MySQL do Sail), usuário `sail`, senha `password`, database `laravel` (ou conforme definido no `.env`).

## Atualizando a Imagem Base Docker

Se você precisar atualizar o ambiente base (ex: instalar um novo pacote de sistema no `Dockerfile.laravel-filament-base`):

1.  Modifique o `Dockerfile.laravel-filament-base`.
2.  Reconstrua a imagem com uma nova tag de versão (ex: `php8.3-v1.1`) e atualize a tag `latest`:
    ```bash
    cd /caminho/para/o/Dockerfile
    docker build -t joaopelegrino/laravel-filament-base:php8.3-v1.1 -f Dockerfile.laravel-filament-base .
    docker tag joaopelegrino/laravel-filament-base:php8.3-v1.1 joaopelegrino/laravel-filament-base:latest
    ```
3.  Envie as novas tags para o Docker Hub:
    ```bash
    docker push joaopelegrino/laravel-filament-base:php8.3-v1.1
    docker push joaopelegrino/laravel-filament-base:latest
    ```
4.  Para projetos existentes usarem a nova imagem:
    *   Atualize a linha `image:` no `docker-compose.yml` do projeto para a nova tag (ou mantenha `latest`).
    *   Rode `sail pull` para baixar a nova imagem.
    *   Rode `sail build --no-cache` (se houver alguma customização local no `docker-compose.yml` que dependa da base).
    *   Rode `sail up -d --force-recreate` para reiniciar os containers com a nova imagem.

## Customização

*   **Templates:** Modifique os arquivos `.template` no diretório `TEMPLATE_DIR` para alterar as configurações padrão de novos projetos.
*   **Script:** Edite `criar-novo-projeto-filament.sh` para adicionar ou remover passos no processo de criação.

