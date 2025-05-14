FROM ubuntu:20.04

# Evitar prompts interativos durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências necessárias
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
    libopenbabel6 \
    nodejs \
    npm \
    git \
    libnetpbm10-dev \
    && rm -rf /var/lib/apt/lists/*

# Instalar o OSRA
RUN wget https://sourceforge.net/projects/osra/files/osra/2.1.0/osra-2.1.0.tgz && \
    tar xvzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    ./configure && \
    make && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf osra-2.1.0 osra-2.1.0.tgz

# Definir o diretório de trabalho
WORKDIR /app

# Copiar package.json e package-lock.json
COPY package*.json ./

# Instalar dependências do Node.js
RUN npm install

# Copiar o restante dos arquivos da aplicação
COPY . .

# Criar diretório de uploads
RUN mkdir -p uploads && chmod 777 uploads

# Expor a porta que o servidor usa
EXPOSE 3003

# Comando para iniciar o servidor
CMD ["node", "server.js"]