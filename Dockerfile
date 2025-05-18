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
# 2. Compilar e instalar GOCR separadamente
# ------------------------------------------------------------------
RUN mkdir -p /opt/src && \
    cd /opt/src && \
    wget -O gocr-0.52.tar.gz https://www-e.uni-magdeburg.de/jschulen/ocr/gocr-0.52.tar.gz && \
    tar -xzf gocr-0.52.tar.gz && \
    cd gocr-0.52 && \
    # Compilar GOCR com construção completa
    ./configure && \
    make -j$(nproc) && \
    make install && \
    # Garantir que os cabeçalhos estejam acessíveis
    mkdir -p /usr/include/gocr /usr/local/include/gocr && \
    cp src/pgm2asc.h /usr/include/ && \
    cp src/pgm2asc.h /usr/local/include/ && \
    cp src/pgm2asc.h /usr/include/gocr/ && \
    cp src/pgm2asc.h /usr/local/include/gocr/ && \
    # Verificar onde o pgm2asc.h está localizado
    find /usr -name pgm2asc.h && \
    # Criar um link simbólico no diretório /usr/include
    ln -sf /opt/src/gocr-0.52/src/pgm2asc.h /usr/include/pgm2asc.h && \
    # Atualizar a cache de bibliotecas
    ldconfig

# ------------------------------------------------------------------
# 3. Compilar e instalar OSRA, com dependência explícita de GOCR
# ------------------------------------------------------------------
RUN cd /opt/src && \
    wget -O osra-2.1.0.tgz https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar -xzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    # Garantir que pgm2asc.h esteja disponível no código fonte
    cp /usr/include/pgm2asc.h . && \
    # Configurar OSRA com os caminhos explícitos para GOCR
    CPPFLAGS="-I/usr/include -I/usr/local/include -I/usr/include/gocr -I/usr/local/include/gocr -I/opt/src/gocr-0.52/src" \
    LDFLAGS="-L/usr/lib -L/usr/local/lib" \
    ./configure --with-gocr-include=/opt/src/gocr-0.52/src && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# ------------------------------------------------------------------
# 4. Limpeza
# ------------------------------------------------------------------
RUN rm -rf /opt/src

# ------------------------------------------------------------------
# 5. Ambiente Node / sua API
# ------------------------------------------------------------------
WORKDIR /app

COPY package*.json ./ 
RUN npm install

COPY . .

# Criar diretório de uploads e garantir permissões corretas
RUN mkdir -p uploads && chmod 777 uploads

# Expor a porta que será usada pelo app
EXPOSE ${PORT:-3003}

# Comando para iniciar o servidor
CMD ["node", "server.js"]