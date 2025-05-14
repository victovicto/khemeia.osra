FROM ubuntu:20.04

# Evitar prompts interativos
ENV DEBIAN_FRONTEND=noninteractive

# Atualizar e instalar dependências
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    build-essential \
    libcairo2-dev \
    pkg-config \
    libopenbabel-dev \
    libgraphicsmagick++1-dev \
    libpotrace-dev \
    ocrad \
    gocr \
    libnetpbm10-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    imagemagick \
    cmake \
    zlib1g-dev \
    libtclap-dev \
    openbabel \
    nodejs \
    npm \
    git \
    && rm -rf /var/lib/apt/lists/*

# Instalar o OSRA
RUN wget https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar xvzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    ./configure && \
    make && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf osra-2.1.0 osra-2.1.0.tgz

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependência Node.js
COPY package*.json ./

# Instalar dependências do Node.js
RUN npm install

# Copiar o restante da aplicação
COPY . .

# Criar diretório para uploads de imagens
RUN mkdir -p uploads && chmod 777 uploads

# Expor a porta do servidor
EXPOSE 3003

# Comando para iniciar a aplicação
CMD ["node", "server.js"]
