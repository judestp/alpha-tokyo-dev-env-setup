#!/bin/bash

# This script assumes you already have SSH key configured and added to GitHub.
# Add your SSH keys to your GitHub account before running this script.

readonly BASE_DIRETORY="alpha-tokyo"
readonly PROJECT_DIRECTORY="$BASE_DIRETORY"

main() {
    essentials &&
        installASDF &&
        installNodeJS &&
        installEnvironmentPackages &&
        cloneRepository &&
        createEnvLocal &&
        generateCerts &&
        dockerize &&
        installProjectPackages &&
        removeTemporaryFiles &&
        
        read -p "Press Enter to exit..."
}

essentials() {
    apt update
    apt upgrade -y
    apt install -y software-properties-common
}

installEnvironmentPackages() {
    apt install --no-install-recommends -y git curl wget jq mkcert
}

installASDF() {
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
    echo ". \"$HOME/.asdf/asdf.sh\"" >>~/.bashrc
    echo ". \"$HOME/.asdf/completions/asdf.bash\"" >>~/.bashrc
}

installNodeJS() {
    asdf plugin-add nodejs
    asdf install nodejs 18.17.0
    asdf global nodejs 18.17.0
}

cloneRepository() {
    cd ~

    git clone git@github.com:Pestalozzitech/alpha-tokyo.git
}

createEnvLocal() {
    local fileName=".env.local"
    local content=$(
        cat <<EOF
# prisma ローカルのホスト側から実行時
CACHE_URL=redis://localhost:6379
DB_WRITER_URL=postgresql://root:password@localhost:5432/alpha-tokyo?schema=public
DB_READER_URL=postgresql://root:pa ssword@localhost:5432/alpha-tokyo?schema=public
DB_WRITER_DB=alpha-tokyo
DB_WRITER_HOST=localhost
DB_WRITER_PORT=5432
DB_WRITER_USER=root
DB_WRITER_PASSWORD=password
DB_READER_DB=alpha-tokyo
DB_READER_HOST=localhost
DB_READER_PORT=5432
DB_READER_USER=root
DB_READER_PASSWORD=password
JWT_SECRET_KEY=secret
EOF
    )

    echo "$content" >"$fileName"
    # Check if the file was created successfully
    if [ -e "$fileName" ]; then
        echo -e "\e[32mFile ($fileName) was successfully created.\e[0m" # Green
    else
        echo -e "\e[31mFailed to create $fileName.\e[0m" # Red
    fi
}

generateCerts() {
    cd ~/$PROJECT_DIRECTORY

    mkcert -install
    mkdir -p certs
    cd certs || exit
    mkcert "*.alpha-pestalozzi.test"
}

dockerize() {
    cd ~/$PROJECT_DIRECTORY

    #==========CUSTOM==========#
    cp env.template .env.compose
    cp ~/.env.local packages/backend/server/.env.local
    #==========CUSTOM==========#

    cp packages/frontend/school/env.template packages/frontend/school/.env.local
    cp packages/frontend/student/env.template packages/frontend/student/.env.local
    cp packages/backend/server/env.local.template packages/backend/server/.env.local
    cp packages/backend/server/env.compose.template packages/backend/server/.env.compose
    cp packages/backend/server/env.test.template packages/backend/server/.env.test
    cp env.template .env

    cp packages/backend/server/env.compose.template packages/backend/server/.env.compose

    docker compose up -d --build
}

installProjectPackages() {
    cd ~/$PROJECT_DIRECTORY

    #==========CUSTOM==========#
    npm install -g yarn
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    apt update && apt install --no-install-recommends yarn
    #==========CUSTOM==========#

    yarn set version $(cat package.json | jq -r .engines.yarn)
    
    cd ~/$PROJECT_DIRECTORY/packages/frontend/student && yarn --immutable
    cd ~/$PROJECT_DIRECTORY/packages/frontend/school && yarn --immutable
    cd ~/$PROJECT_DIRECTORY/packages/frontend/board && yarn --immutable
    cd ~/$PROJECT_DIRECTORY/packages/openapi && yarn --immutable
    cd ~/$PROJECT_DIRECTORY/packages/language && yarn --immutable
    cd ~/$PROJECT_DIRECTORY/packages/backend/server && yarn --immutable

    #==========CUSTOM==========#
    cd ~/$PROJECT_DIRECTORY/packages/frontend/admin && yarn --immutable
    # cd packages/backend/server && yarn --immutable
    yarn db:migrate:local
    #==========CUSTOM==========#

    # Discard .yarnrc changes
    git stash -u
}

removeTemporaryFiles() {
    rm ~/.env.local
    rm ~/script.sh
}

main
