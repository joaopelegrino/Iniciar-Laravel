#!/bin/bash

# --- Configurações Editáveis ---
# Caminho para o diretório que contém seus arquivos .template
# Exemplo WSL: "/mnt/c/Programacao/Aplicacao-web/Templates-Laravel"
# Exemplo Linux/Mac: "$HOME/laravel-templates"
TEMPLATE_DIR="/mnt/c/Programacao/Aplicacao-web/Templates-Laravel" # <<< AJUSTE ESTE CAMINHO

# Nome da sua imagem base no Docker Hub
DOCKER_IMAGE="joaopelegrino/laravel-filament-base:latest" # <<< CONFIRMADO

# Seu nome de usuário no GitHub/GitLab (para o nome do pacote no composer.json)
GIT_USERNAME="joaopelegrino" # <<< AJUSTE SEU USUÁRIO GIT

# Serviços adicionais do Sail (separados por vírgula, ex: mysql,redis,meilisearch)
SAIL_SERVICES="mysql,redis" # Adicione ",redis" etc. se necessário
# --- Fim das Configurações Editáveis ---

# --- Lógica do Script ---
# Verificar se o nome do projeto foi fornecido
if [ -z "$1" ]; then
  echo "Uso: $0 <nome-do-projeto> [diretorio-pai]"
  echo "  Se [diretorio-pai] não for fornecido, o projeto será criado no diretório atual."
  echo "Exemplo 1 (no diretório atual): $0 MeuSite"
  echo "Exemplo 2 (em diretório específico): $0 MeuSite /mnt/c/Programacao/Aplicacao-web"
  exit 1
fi

PROJECT_NAME=$1
# Define o diretório pai: usa o segundo argumento se fornecido, senão usa o diretório atual (.)
PARENT_DIR_INPUT=${2:-.}

# Resolve o caminho absoluto do diretório pai
# Usar 'pwd' se o input for '.' para garantir que funcione mesmo se o diretório atual tiver espaços
if [[ "$PARENT_DIR_INPUT" == "." ]]; then
    PARENT_DIR=$(pwd)
else
    # Tenta criar o diretório pai se não existir (útil)
    mkdir -p "$PARENT_DIR_INPUT" || { echo "Erro: Não foi possível criar ou acessar o diretório pai '$PARENT_DIR_INPUT'. Verifique as permissões."; exit 1; }
    PARENT_DIR=$(realpath "$PARENT_DIR_INPUT")
fi


# Verificar se o diretório pai resolvido existe
if [ ! -d "$PARENT_DIR" ]; then
  echo "Erro: O diretório pai '$PARENT_DIR' não existe ou não é um diretório."
  exit 1
fi

# Caminho completo para o novo projeto
PROJECT_PATH="$PARENT_DIR/$PROJECT_NAME"

# Verificar se o diretório do projeto já existe
if [ -d "$PROJECT_PATH" ]; then
  echo "Erro: O diretório do projeto '$PROJECT_PATH' já existe."
  exit 1
fi

# Verificar se o diretório de templates existe
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Erro: O diretório de templates '$TEMPLATE_DIR' não foi encontrado."
  echo "Por favor, ajuste a variável TEMPLATE_DIR no início do script."
  exit 1
fi


echo "--------------------------------------------------"
echo "Projeto:         $PROJECT_NAME"
echo "Diretório Pai:   $PARENT_DIR"
echo "Caminho Final:   $PROJECT_PATH"
echo "Imagem Docker:   $DOCKER_IMAGE"
echo "Templates:       $TEMPLATE_DIR"
echo "Serviços Sail:   $SAIL_SERVICES"
echo "--------------------------------------------------"
read -p "Confirmar criação? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "Criação cancelada."
    exit 0
fi

echo "--------------------------------------------------"
echo "[1/14] Criando projeto Laravel..."
echo "--------------------------------------------------"
composer create-project laravel/laravel "$PROJECT_PATH" --no-install || { echo "Falha ao criar esqueleto Laravel"; exit 1; } # --no-install para acelerar

cd "$PROJECT_PATH" || { echo "Falha ao entrar no diretório do projeto '$PROJECT_PATH'"; exit 1; }

echo "--------------------------------------------------"
echo "[2/14] Copiando templates (composer.json, etc.)..."
echo "--------------------------------------------------"
# Copiar ANTES de instalar Sail para já ter o composer.json correto
cp "$TEMPLATE_DIR/composer.json.template" ./composer.json || { echo "Falha ao copiar composer.json.template"; exit 1; }
sed -i.bak "s|laravel/laravel|$GIT_USERNAME\/$PROJECT_NAME|g" composer.json && rm composer.json.bak
cp "$TEMPLATE_DIR/pint.json.template" ./pint.json || { echo "Falha ao copiar pint.json.template"; exit 1; }
# Verificar e copiar phpstan.neon.template (adicione este arquivo ao seu TEMPLATE_DIR se não existir)
if [ -f "$TEMPLATE_DIR/phpstan.neon.template" ]; then
    cp "$TEMPLATE_DIR/phpstan.neon.template" ./phpstan.neon || { echo "Falha ao copiar phpstan.neon.template"; exit 1; }
else
    echo "Aviso: Arquivo phpstan.neon.template não encontrado em $TEMPLATE_DIR. Pulando."
fi
cp "$TEMPLATE_DIR/rector.php.template" ./rector.php || { echo "Falha ao copiar rector.php.template"; exit 1; }

echo "--------------------------------------------------"
echo "[3/14] Instalando Laravel Sail..."
echo "--------------------------------------------------"
# Instalar Sail usando o composer.json já modificado
composer install || { echo "Falha no composer install inicial (incluindo Sail)"; exit 1; }

echo "--------------------------------------------------"
echo "[4/14] Publicando arquivos do Sail..."
echo "--------------------------------------------------"
php artisan sail:install --with="$SAIL_SERVICES" --force || { echo "Falha ao instalar Sail"; exit 1; } # --force para não pedir confirmação

echo "--------------------------------------------------"
echo "[5/14] Configurando Docker Compose para usar imagem base..."
echo "--------------------------------------------------"
# Modificar docker-compose.yml
# Abordagem mais robusta usando yq (se disponível) ou sed
if command -v yq &> /dev/null; then
    echo "Usando yq para modificar docker-compose.yml..."
    yq -i ".services.\"laravel.test\".image = \"${DOCKER_IMAGE}\"" docker-compose.yml
    yq -i "del(.services.\"laravel.test\".build)" docker-compose.yml
else
    echo "Aviso: yq não encontrado. Usando sed (pode ser menos robusto)..."
    sed -i.bak -E "s|^(\s+)build:|\1#build:|g" docker-compose.yml
    sed -i.bak -E "/^\s*#build:/a \        image: ${DOCKER_IMAGE}" docker-compose.yml
    sed -i.bak -E "/^\s*#build:/,/image: ${DOCKER_IMAGE}/ s|^(\s*)(context:|dockerfile:|args:|WWWGROUP:)|\1#\2|" docker-compose.yml
    rm docker-compose.yml.bak 2>/dev/null
fi

echo "--------------------------------------------------"
echo "[6/14] Subindo containers Sail (pode demorar na primeira vez)..."
echo "--------------------------------------------------"
./vendor/bin/sail up -d || { echo "Falha ao iniciar Sail"; exit 1; }

echo "--------------------------------------------------"
echo "[7/14] Aguardando serviços Docker..."
echo "--------------------------------------------------"
sleep 20 # Aumentado um pouco

echo "--------------------------------------------------"
echo "[8/14] Instalando Filament Panels..."
echo "--------------------------------------------------"
./vendor/bin/sail php artisan filament:install --panels --force || { echo "Falha ao instalar Filament Panels"; exit 1; }

echo "--------------------------------------------------"
echo "[9/14] Instalando dependências NPM..."
echo "--------------------------------------------------"
./vendor/bin/sail npm install || { echo "Falha no npm install"; exit 1; }

echo "--------------------------------------------------"
echo "[10/14] Configurando ambiente (.env, key, storage link)..."
echo "--------------------------------------------------"
./vendor/bin/sail cp .env.example .env || { echo "Falha ao copiar .env"; exit 1; }
# Ajustar .env para MySQL (Sail padrão) - opcional mas útil
sed -i.bak 's/DB_HOST=127.0.0.1/DB_HOST=mysql/' .env && rm .env.bak
sed -i.bak 's/DB_PORT=3306/DB_PORT=3306/' .env && rm .env.bak # Garantir porta
sed -i.bak 's/DB_DATABASE=laravel/DB_DATABASE=laravel/' .env && rm .env.bak # Manter padrão
sed -i.bak 's/DB_USERNAME=root/DB_USERNAME=sail/' .env && rm .env.bak
sed -i.bak 's/DB_PASSWORD=/DB_PASSWORD=password/' .env && rm .env.bak

./vendor/bin/sail php artisan key:generate || { echo "Falha ao gerar APP_KEY"; exit 1; }
./vendor/bin/sail php artisan storage:link || { echo "Falha ao criar storage link"; exit 1; }

echo "--------------------------------------------------"
echo "[11/14] Rodando migrações..."
echo "--------------------------------------------------"
# Tentar rodar migrate algumas vezes, pois o DB pode demorar a iniciar
MAX_RETRIES=3
RETRY_COUNT=0
until ./vendor/bin/sail php artisan migrate --seed || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "Falha na migração (tentativa $RETRY_COUNT/$MAX_RETRIES). Tentando novamente em 10 segundos..."
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Erro: Falha nas migrações após $MAX_RETRIES tentativas. Verifique a conexão com o DB e os logs do container mysql."
    # exit 1 # Comentar para permitir continuar mesmo se migrate falhar
fi


echo "--------------------------------------------------"
echo "[12/14] Compilando assets..."
echo "--------------------------------------------------"
./vendor/bin/sail npm run build || { echo "Falha no npm run build"; exit 1; }

echo "--------------------------------------------------"
echo "[13/14] Limpando caches e otimizando..."
echo "--------------------------------------------------"
./vendor/bin/sail artisan optimize:clear
./vendor/bin/sail artisan config:cache
./vendor/bin/sail artisan route:cache
./vendor/bin/sail artisan view:cache

echo "--------------------------------------------------"
echo "[14/14] Opcional: Inicializando repositório Git..."
echo "--------------------------------------------------"
read -p "Inicializar repositório Git e fazer commit inicial? (s/N): " INIT_GIT
if [[ "$INIT_GIT" =~ ^[Ss]$ ]]; then
    git init
    git add .
    # Criar .gitignore se não existir (composer create-project deve criar)
    if [ ! -f ".gitignore" ]; then
        echo -e "/node_modules\n/public/build\n/public/hot\n/public/storage\n/storage/*.key\n/vendor\n/.env\n/.env.backup\n/.phpunit.result.cache\n/Homestead.json\n/Homestead.yaml\n/npm-debug.log\n/yarn-error.log\n/.idea\n/.vscode" > .gitignore
        git add .gitignore
    fi
    git commit -m "Setup inicial do projeto $PROJECT_NAME com Laravel, Filament, Sail e Ferramentas de Qualidade"
    echo "Repositório Git inicializado."
fi

echo "--------------------------------------------------"
echo "Projeto '$PROJECT_NAME' criado em '$PARENT_DIR' e configurado com sucesso!"
echo "Ambiente Docker (Sail) está rodando em background."
echo ""
echo "Para começar a desenvolver:"
echo "  cd \"$PROJECT_PATH\""
echo "  ./vendor/bin/sail up (para ver logs em tempo real, Ctrl+C para parar)"
echo "  ./vendor/bin/sail npm run dev (para compilação de assets em tempo real)"
echo ""
echo "Acesse a aplicação em: http://localhost (ou a porta APP_PORT definida no .env)"
echo "Acesse o painel Filament em: http://localhost/admin (usuário inicial precisa ser criado)"
echo "--------------------------------------------------"

exit 0
