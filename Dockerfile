ARG ALPINE_VERSION=3.9.4
FROM alpine:${ALPINE_VERSION}

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
 && apk update \
 && apk add --no-cache git python3 python3-dev

# build wheels in first image
ADD . /tmp/src
RUN mkdir /tmp/wheelhouse \
 && cd /tmp/wheelhouse \
 && pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
 && pip3 install -U pip \
 && pip3 install wheel \
 && pip3 wheel --no-cache-dir /tmp/src

FROM alpine:${ALPINE_VERSION}

# install python, git, bash
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
 && apk add --no-cache git git-lfs python3 bash

# install repo2docker
COPY --from=0 /tmp/wheelhouse /tmp/wheelhouse
RUN pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip3 install -U pip && \
    pip3 install --no-cache-dir /tmp/wheelhouse/*.whl

# add git-credential helper
COPY ./docker/git-credential-env /usr/local/bin/git-credential-env
COPY GeoTrust_RSA_CA_2018.crt /usr/local/share/ca-certificates/GeoTrust_RSA_CA_2018.crt
RUN git config --system credential.helper env && \
    update-ca-certificates && \
    openssl s_client -showcerts -connect gitlab.bnu.edu.cn:443 2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'  >> /etc/ssl/certs/ca-certificates.crt


# Used for testing purpose in ports.py
EXPOSE 52000
