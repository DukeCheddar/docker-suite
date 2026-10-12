# ===============================================
# Suite - Service Container
# Node.js + PostgreSQL, one service per container
# ===============================================
FROM ubuntu:22.04

# -----------------------------------------------
# Build args from compose.yml
# -----------------------------------------------
ARG USER_NAME
ARG USER_PASSWORD
ARG USER_UID
ARG USER_GID
ARG EXPOSE_PORT=22
ARG NVM_VERSION=v0.40.8
ARG NODE_VERSION=24.21.0
ARG POSTGRES_VERSION=16

# -----------------------------------------------
# Fix default ubuntu user (UID/GID 999)
# -----------------------------------------------
RUN groupmod -g 999 ubuntu || true && \
    usermod -u 999 ubuntu || true

# -----------------------------------------------
# Create dev user matching host UID/GID
# -----------------------------------------------
RUN groupadd --gid $USER_GID $USER_NAME && \
    useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USER_NAME && \
    usermod -aG sudo $USER_NAME && \
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Montreal

# -----------------------------------------------
# Install utilities
# -----------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        net-tools \
        ca-certificates \
        curl \
        git \
        sudo \
        tini \
        util-linux \
        passwd \
        openssh-server \
        coreutils \
        wget \
        vim \
        unzip \
        redis-tools \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------
# PostgreSQL (PGDG repository)
# The cluster is created at first start by the entrypoint,
# in the mounted data directory, not at install time
# -----------------------------------------------
ENV PG_MAJOR=${POSTGRES_VERSION}
ENV PGDATA=/var/lib/postgresql/data

RUN install -d /usr/share/postgresql-common/pgdg && \
    curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt jammy-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-common && \
    sed -ri 's/^#?\s*create_main_cluster\s*=.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf && \
    apt-get install -y --no-install-recommends \
        postgresql-${POSTGRES_VERSION} \
        postgresql-client-${POSTGRES_VERSION} \
    && rm -rf /var/lib/apt/lists/* && \
    install -d -o postgres -g postgres -m 700 $PGDATA

# -----------------------------------------------
# Node.js via nvm (installed for the dev user)
# -----------------------------------------------
RUN su - $USER_NAME -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" && \
    su - $USER_NAME -c ". \$HOME/.nvm/nvm.sh && nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION}"

# Liens dans /usr/local/bin : disponibles pour toutes les sessions,
# y compris SSH non interactif et docker exec
RUN NODE_BIN=$(su - $USER_NAME -c ". \$HOME/.nvm/nvm.sh && dirname \$(nvm which ${NODE_VERSION})") && \
    ln -sf "$NODE_BIN/node" /usr/local/bin/node && \
    ln -sf "$NODE_BIN/npm"  /usr/local/bin/npm && \
    ln -sf "$NODE_BIN/npx"  /usr/local/bin/npx && \
    node -v && npm -v

# -----------------------------------------------
# SSH setup
# -----------------------------------------------
RUN mkdir -p /var/run/sshd && \
    mkdir -p /home/$USER_NAME/.ssh && \
    chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh && \
    chmod 700 /home/$USER_NAME/.ssh

COPY ./configs/etc/ssh/authorized_keys /home/$USER_NAME/.ssh/authorized_keys
RUN chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys && \
    chmod 600 /home/$USER_NAME/.ssh/authorized_keys

COPY ./configs/etc/ssh/sshd_config /etc/ssh/sshd_config
RUN sed -i "s/^Port .*/Port ${EXPOSE_PORT}/" /etc/ssh/sshd_config

RUN chown root:root /etc/ssh/ssh_host_* && \
    chmod 600        /etc/ssh/ssh_host_* && \
    chmod 644        /etc/ssh/ssh_host_*.pub

# -----------------------------------------------
# Workspaces directory
# -----------------------------------------------
RUN mkdir -p /home/$USER_NAME/workspaces && \
    chown $USER_NAME:$USER_NAME /home/$USER_NAME/workspaces

# -----------------------------------------------
# Entrypoint: starts PostgreSQL, then sshd
# -----------------------------------------------
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# -----------------------------------------------
# Exposed ports
# -----------------------------------------------
EXPOSE $EXPOSE_PORT

# -----------------------------------------------
# Default command
# -----------------------------------------------
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
