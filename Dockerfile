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
    netpbm libnetpbm10-dev            \
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
    ./configure && \
    make -j$(nproc) && \
    make install && \
    # Criar os diretórios necessários e copiar pgm2asc.h para todos os possíveis locais
    mkdir -p /usr/include/gocr /usr/local/include/gocr && \
    cp src/pgm2asc.h /usr/include/ && \
    cp src/pgm2asc.h /usr/local/include/ && \
    cp src/pgm2asc.h /usr/include/gocr/ && \
    cp src/pgm2asc.h /usr/local/include/gocr/ && \
    # Manter diretório fonte para OSRA
    cd /opt/src

# ------------------------------------------------------------------
# 3. Baixar, compilar e instalar OSRA 2.1.0
# ------------------------------------------------------------------
RUN cd /opt/src && \
    wget -O osra-2.1.0.tgz https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar -xzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    # Mostrar caminhos de diretórios para debug
    ls -la /usr/include/gocr && \
    ls -la /usr/local/include/gocr && \
    ls -la /opt/src/gocr-0.52/src && \
    # Configurar com caminhos para todos os locais possíveis
    ./configure \
      CPPFLAGS="-I/usr/include -I/usr/local/include -I/usr/include/gocr -I/usr/local/include/gocr -I/opt/src/gocr-0.52/src" \
      LDFLAGS="-L/usr/lib -L/usr/local/lib" && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    # Limpar ao final
    cd / && rm -rf /opt/src

# ------------------------------------------------------------------
# 4. Ambiente Node / sua API
# ------------------------------------------------------------------
WORKDIR /app

COPY package*.json ./ 
RUN npm install

COPY . .

RUN mkdir -p uploads && chmod 777 uploads

EXPOSE 3003
CMD ["node", "server.js"]