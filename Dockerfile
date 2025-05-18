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
# 2. Compilar e instalar GOCR e OSRA em uma única etapa
# ------------------------------------------------------------------
RUN mkdir -p /opt/src && \
    cd /opt/src && \
    # Primeiro baixe e extraia GOCR
    wget -O gocr-0.52.tar.gz https://www-e.uni-magdeburg.de/jschulen/ocr/gocr-0.52.tar.gz && \
    tar -xzf gocr-0.52.tar.gz && \
    cd gocr-0.52 && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    # Verificar se pgm2asc.h existe e criar estrutura de diretórios
    find . -name pgm2asc.h && \
    mkdir -p /usr/include/gocr /usr/local/include/gocr && \
    # Copiar manualmente para todos os locais possíveis
    cp src/pgm2asc.h /usr/include/ && \
    cp src/pgm2asc.h /usr/local/include/ && \
    cp src/pgm2asc.h /usr/include/gocr/ && \
    cp src/pgm2asc.h /usr/local/include/gocr/ && \
    # Verificar
    ls -la /usr/include/gocr/ && \
    ls -la /usr/local/include/gocr/ && \
    ls -la /usr/include/ | grep pgm2asc.h && \
    ls -la /usr/local/include/ | grep pgm2asc.h && \
    # Agora baixe e instale OSRA no mesmo contexto
    cd /opt/src && \
    wget -O osra-2.1.0.tgz https://downloads.sourceforge.net/project/osra/osra/2.1.0/osra-2.1.0.tgz && \
    tar -xzf osra-2.1.0.tgz && \
    cd osra-2.1.0 && \
    # Verificar se os diretórios contêm os arquivos necessários
    find /usr -name pgm2asc.h && \
    find /opt -name pgm2asc.h && \
    # Configurar com caminhos explícitos e debug
    CPPFLAGS="-I/usr/include -I/usr/local/include -I/usr/include/gocr -I/usr/local/include/gocr -I/opt/src/gocr-0.52/src" \
    LDFLAGS="-L/usr/lib -L/usr/local/lib" \
    ./configure --with-gocr-include=/opt/src/gocr-0.52/src && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    # Limpar ao final
    cd / && rm -rf /opt/src

# ------------------------------------------------------------------
# 3. Ambiente Node / sua API
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