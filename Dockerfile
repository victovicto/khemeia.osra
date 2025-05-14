FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------
# 1. Pacotes de sistema e de desenvolvimento
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl wget git build-essential gcc make \
    autoconf automake libtool pkg-config \
    libcairo2-dev libgraphicsmagick++1-dev \
    libpotrace-dev ocrad \
    netpbm libnetpbm10-dev \
    libjpeg-dev libpng-dev libtiff-dev imagemagick \
    zlib1g-dev libtclap-dev \
    openbabel libopenbabel-dev \
    nodejs npm \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 2. Compilar e instalar GOCR 0.52 (fornece pgm2asc.h + libgocr)
# ------------------------------------------------------------------
RUN mkdir -p /opt/src && \
    cd /opt/src && \
    wget -O gocr-0.52.tar.gz https://www-e.uni-magdeburg.de/jschulen/ocr/gocr-0.52.tar.gz && \
    tar -xzf gocr-0.52.tar.gz && \
    cd gocr-0.52 && \
    make -j$(nproc) && \
    make install && \
    # Expor o cabeçalho que o OSRA procura
    cp src/pgm2asc.h /usr/include/ && \
    ldconfig && \
    cd / && rm -rf /opt/src

# ------------------------------------------------------------------
# 3. Baixar, compilar e instalar OSRA 2.1.0
# ------------------------------------------------------------------
RUN mkdir -p /opt/src && \
    cd /opt/src && \
    wget -O osra-2.1.0.tgz https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar -xzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    ./configure \
      CPPFLAGS="-I/usr/include -I/usr/local/include" \
      LDFLAGS="-L/usr/lib -L/usr/local/lib" && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && rm -rf /opt/src

# ------------------------------------------------------------------
# 4. Ambiente Node / sua API
# ------------------------------------------------------------------
WORKDIR /app

# Copiar arquivos de dependências do Node
COPY package*.json ./
RUN npm install

# Copiar o restante do código para a aplicação
COPY . .

# Configuração do diretório de uploads
RUN mkdir -p uploads && chmod 777 uploads

# Expor a porta que o servidor vai rodar
EXPOSE 3003

# Iniciar a API com Node.js
CMD ["node", "server.js"]
