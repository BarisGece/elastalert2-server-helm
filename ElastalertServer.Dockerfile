# Base Dockerfile - https://github.com/BarisGece/elastalert-server/blob/main/Dockerfile
FROM python:3.9-alpine3.14 as py-ea
ARG ELASTALERT_VERSION=2.1.2
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
ARG ELASTALERT_URL=https://github.com/jertel/elastalert2/archive/refs/tags/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
ENV ELASTALERT_HOME /opt/elastalert

RUN apk --update upgrade && \
    apk add --no-cache wget git && \
    rm -rf /var/cache/apk/*

WORKDIR /opt

RUN git clone -b main https://github.com/BarisGece/elastalert-server.git /tmp/elastalert-server && \
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

#RUN python3 setup.py install
 
RUN mkdir -p /opt/elastalert-server && \
  cp /tmp/elastalert-server/index.js /opt/elastalert-server/index.js && \
  cp /tmp/elastalert-server/package.json /opt/elastalert-server/package.json && \
  cp /tmp/elastalert-server/.babelrc /opt/elastalert-server/.babelrc && \
  cp -R /tmp/elastalert-server/src /opt/elastalert-server/src && \
  cp -R /tmp/elastalert-server/scripts /opt/elastalert-server/scripts && \
  cp -R /tmp/elastalert-server/elastalert_modules /opt/elastalert-server/elastalert_modules && \
  cp -R /tmp/elastalert-server/rule_templates /opt/elastalert-server/rule_templates && \
  cp -R /tmp/elastalert-server/config /opt/elastalert-server/config

FROM node:16.4.2-alpine3.14
LABEL maintainer="John Susek <john@johnsolo.net>"
ENV TZ Etc/UTC
ENV PATH /home/node/.local/bin:$PATH

RUN apk add --update --no-cache \
    ca-certificates \
    cargo \
    curl \
    gcc \
    libffi-dev \
    libmagic \
    make \
    musl-dev \
    openssl \
    openssl-dev \
    py3-pip \
    python3 \
    python3-dev \
    tzdata

#COPY --from=py-ea /usr/lib/python3.8/site-packages /usr/lib/python3.8/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
# COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY --from=py-ea /opt/elastalert-server /opt/elastalert-server

RUN npm install --production --quiet
RUN cp /opt/elastalert-server/config/elastalert.yaml /opt/elastalert/config.yaml
RUN cp -R /opt/elastalert-server/rule_templates /opt/elastalert/rule_templates
RUN cp -R /opt/elastalert-server/elastalert_modules /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

RUN pip3 install --no-cache-dir --upgrade pip==21.1.3

USER node

EXPOSE 3030

WORKDIR /opt/elastalert

RUN pip3 install --no-cache-dir cryptography --user
RUN pip3 install --no-cache-dir -r requirements.txt --user

WORKDIR /opt/elastalert-server

ENTRYPOINT ["npm", "start"]