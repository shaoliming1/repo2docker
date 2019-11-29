#!/bin/bash
# This downloads and installs a pinned version of miniconda
set -ex

cd $(dirname $0)
MINICONDA_VERSION=4.7.10
CONDA_VERSION=4.7.10


INSTALLER_PATH=/tmp/miniconda-installer.sh

# make sure we don't do anything funky with user's $HOME
# since this is run as root
unset HOME

chmod +x ${INSTALLER_PATH}


bash ${INSTALLER_PATH} -b -p ${CONDA_DIR}
export PATH="${CONDA_DIR}/bin:$PATH"

# add .condarc to  `/srv/condda`
mv /tmp/.condarc /srv/conda/.condarc

# Do not attempt to auto update conda or dependencies
conda config --system --set auto_update_conda false
conda config --system --set show_channel_urls true

# bug in conda 4.3.>15 prevents --set update_dependencies
echo 'update_dependencies: false' >> ${CONDA_DIR}/.condarc

# install conda itself
if [[ "${CONDA_VERSION}" != "${MINICONDA_VERSION}" ]]; then
    conda install -yq conda==${CONDA_VERSION}
fi

# avoid future changes to default channel_priority behavior
conda config --system --set channel_priority "flexible"

# 替换pip源为阿里镜像源
echo "config pip to use ali mirror"
pip config set global.index-url http://mirrors.aliyun.com/pypi/simple
pip config set install.trusted-host mirrors.aliyun.com
pip install pip -U

# for debug
# sleep 5h

echo "installing notebook env:"
cat /tmp/environment.yml
strace conda env create -p ${NB_PYTHON_PREFIX} -f /tmp/environment.yml

# empty conda history file,
# which seems to result in some effective pinning of packages in the initial env,
# which we don't intend.
# this file must not be *removed*, however
echo '' > ${NB_PYTHON_PREFIX}/conda-meta/history

if [[ -f /tmp/kernel-environment.yml ]]; then
    # install kernel env and register kernelspec
    echo "installing kernel env:"
    cat /tmp/kernel-environment.yml

    conda env create -p ${KERNEL_PYTHON_PREFIX} -f /tmp/kernel-environment.yml
    ${KERNEL_PYTHON_PREFIX}/bin/ipython kernel install --prefix "${NB_PYTHON_PREFIX}"
    echo '' > ${KERNEL_PYTHON_PREFIX}/conda-meta/history
    conda list -p ${KERNEL_PYTHON_PREFIX}
fi

# Clean things out!
conda clean --all -f -y

# Remove the big installer so we don't increase docker image size too much
rm ${INSTALLER_PATH}

# Remove the pip cache created as part of installing miniconda
rm -rf /root/.cache

chown -R $NB_USER:$NB_USER ${CONDA_DIR}

conda list -n root
conda list -p ${NB_PYTHON_PREFIX}
