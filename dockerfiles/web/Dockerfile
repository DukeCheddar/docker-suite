# ===============================================
# Suite - Web Container
# Node.js only, serves the UI behind the core nginx
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
ARG WEB_HTTP_EXPOSED_PORT=4200
ARG NVM_VERSION=v0.40.8
ARG NODE_VERSION=24.21.0

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
    && rm -rf /var/lib/apt/lists/*

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
# Exposed ports
# -----------------------------------------------
EXPOSE $EXPOSE_PORT $WEB_HTTP_EXPOSED_PORT

# -----------------------------------------------
# Default command
# -----------------------------------------------
CMD ["/usr/sbin/sshd", "-D", "-e"]
