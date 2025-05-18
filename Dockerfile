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
    nodejs npm gocr \
 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 2. Usar uma abordagem alternativa para instalar OSRA sem dependência direta de GOCR
# ------------------------------------------------------------------
RUN mkdir -p /opt/src && \
    cd /opt/src && \
    # Clona o repositório OSRA de um fork que contém fixes
    git clone https://github.com/kaliw/osra.git && \
    cd osra && \
    autoreconf -i && \
    # Configura e compila sem dependência de GOCR
    ./configure --without-gocr && \
    make && \
    make install && \
    ldconfig

# ------------------------------------------------------------------
# 3. Limpar e configurar ambiente para Node
# ------------------------------------------------------------------
RUN rm -rf /opt/src

# ------------------------------------------------------------------
# 4. Ambiente Node / sua API
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