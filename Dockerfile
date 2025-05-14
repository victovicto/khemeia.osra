FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Atualizar pacotes e instalar dependências básicas
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    build-essential \
    libcairo2-dev \
    pkg-config \
    libgraphicsmagick++1-dev \
    libpotrace-dev \
    ocrad \
    gocr \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    imagemagick \
    cmake \
    zlib1g-dev \
    libtclap-dev \
    openbabel \
    libopenbabel-dev \
    nodejs \
    npm \
    git \
    netpbm \
    libnetpbm10-dev \
    && rm -rf /var/lib/apt/lists/*

# Simular header necessário do Netpbm para o OSRA (pgm2asc.h)
RUN mkdir -p /usr/include/netpbm && \
    cp /usr/include/pgm.h /usr/include/netpbm/pgm2asc.h

# Instalar o OSRA
RUN wget https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar xvzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf osra-2.1.0 osra-2.1.0.tgz

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos do Node.js
COPY package*.json ./

# Instalar dependências Node.js
RUN npm install

# Copiar restante do código
COPY . .

# Criar diretório para uploads
RUN mkdir -p uploads && chmod 777 uploads

# Expor porta
EXPOSE 3003

# Iniciar servidor
CMD ["node", "server.js"]
