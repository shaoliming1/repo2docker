#!/bin/bash
# This downloads and installs a pinned version of miniconda
set -ex

cd $(dirname $0)
MINICONDA_VERSION=4.5.11
CONDA_VERSION=4.5.11
# URL="https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh"
URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh"
INSTALLER_PATH=/tmp/miniconda-installer.sh

wget --quiet $URL -O ${INSTALLER_PATH}
chmod +x ${INSTALLER_PATH}

# Only MD5 checksums are available for miniconda
# Can be obtained from https://repo.continuum.io/miniconda/
MD5SUM="e1045ee415162f944b6aebfe560b8fee"

if ! echo "${MD5SUM}  ${INSTALLER_PATH}" | md5sum  --quiet -c -; then
    echo "md5sum mismatch for ${INSTALLER_PATH}, exiting!"
    exit 1
fi

bash ${INSTALLER_PATH} -b -p ${CONDA_DIR}
export PATH="${CONDA_DIR}/bin:$PATH"

# add .condarc to  `/srv/condda`
mv /tmp/.condarc /srv/conda/.condarc

# 我们在.condarc中已经加入，这里注释掉
# conda config --system --add channels conda-forge

# Do not attempt to auto update conda or dependencies
conda config --system --set auto_update_conda false
# conda config --system --set show_channel_urls true

# install conda itself
conda install -y conda==${CONDA_VERSION}

# switch Python in its own step
# since switching Python during an env update can
# prevent pip installation.
# we wouldn't have this issue if we did `conda env create`
# instead of `conda env update` in these cases
conda install -y $(cat /tmp/environment.yml | grep -o '\spython=.*') conda==${CONDA_VERSION}

# bug in conda 4.3.>15 prevents --set update_dependencies
echo 'update_dependencies: false' >> ${CONDA_DIR}/.condarc

echo "installing root env:"
cat /tmp/environment.yml

echo "config pip to use tuna mirror"
pip install pip -U
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

conda env update -n root -f /tmp/environment.yml

# enable nteract-on-jupyter, which was installed with pip
jupyter serverextension enable nteract_on_jupyter --sys-prefix

if [[ -f /tmp/kernel-environment.yml ]]; then
    # install kernel env and register kernelspec
    echo "installing kernel env:"
    cat /tmp/kernel-environment.yml

    conda env create -n kernel -f /tmp/kernel-environment.yml
    ${CONDA_DIR}/envs/kernel/bin/ipython kernel install --prefix "${CONDA_DIR}"
    echo '' > ${CONDA_DIR}/envs/kernel/conda-meta/history
fi
# empty conda history file,
# which seems to result in some effective pinning of packages in the initial env,
# which we don't intend.
# this file must not be *removed*, however
echo '' > ${CONDA_DIR}/conda-meta/history

# Clean things out!
conda clean -tipsy

# Remove the big installer so we don't increase docker image size too much
rm ${INSTALLER_PATH}

chown -R $NB_USER:$NB_USER ${CONDA_DIR}

conda list
