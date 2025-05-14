FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Atualizar pacotes e instalar dependências
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
    && rm -rf /var/lib/apt/lists/*

# Instalar Netpbm (manual build para fornecer pgm2asc.h)
RUN mkdir -p /opt/netpbm && \
    cd /opt && \
    wget https://sourceforge.net/projects/netpbm/files/super_stable/10.86.05/netpbm-10.86.05.tgz && \
    tar zxvf netpbm-10.86.05.tgz && \
    cd netpbm-10.86.05 && \
    cp config.mk.in config.mk && \
    echo "CC = gcc" >> config.mk && \
    echo "NETPBMLIBTYPE = unixshared" >> config.mk && \
    echo "NETPBMLIBSUFFIX = so" >> config.mk && \
    echo "NETPBM_DOCURL = http://netpbm.sourceforge.net/doc/" >> config.mk && \
    make && \
    make package pkgdir=/usr/local/netpbm && \
    cd /usr/local/netpbm && \
    sh installnetpbm && \
    ln -s /usr/local/netpbm/include /usr/include/netpbm && \
    cd / && \
    rm -rf /opt/netpbm*

# Instalar o OSRA
RUN wget https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar xvzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    ./configure CPPFLAGS="-I/usr/local/netpbm/include" LDFLAGS="-L/usr/local/netpbm/lib" && \
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
