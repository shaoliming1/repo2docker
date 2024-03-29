ARG PYTHON_VERSION=3.7
FROM python:${PYTHON_VERSION}

# build wheels in first image
ADD . /tmp/src
RUN mkdir /tmp/wheelhouse \
 && cd /tmp/wheelhouse \
 && pip3 install pip -U \
 && pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
 && pip3 wheel --no-cache-dir /tmp/src

# run with slim variant instead of full
# since we won't need compilers and friends
FROM python:${PYTHON_VERSION}-slim

# we do need git, though
RUN apt-get update \
 && apt-get -y install --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

# install repo2docker
COPY --from=0 /tmp/wheelhouse /tmp/wheelhouse
RUN pip3 install --no-cache-dir /tmp/wheelhouse/*.whl

# add git-credential helper
COPY ./docker/git-credential-env /usr/local/bin/git-credential-env
COPY GeoTrust_RSA_CA_2018.crt /usr/local/share/ca-certificates/GeoTrust_RSA_CA_2018.crt
RUN git config --system credential.helper env && \
    update-ca-certificates && \
    openssl s_client -showcerts -connect gitlab.bnu.edu.cn:443 2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'  >> /etc/ssl/certs/ca-certificates.crt


# Used for testing purpose in ports.py
EXPOSE 52000
