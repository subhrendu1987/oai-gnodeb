#!/bin/bash

set -uo pipefail

PREFIX=/opt/oai-gnb
CUSTOM=/mnt/conf
ENABLE_X2=${ENABLE_X2:-yes}
THREAD_PARALLEL_CONFIG=${THREAD_PARALLEL_CONFIG:-PARALLEL_SINGLE_THREAD}

# Based another env var, pick one template to use

if [[ -v USE_NSA_TDD_MONO ]]; then cp $CUSTOM/etc/gnb.nsa.tdd.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_TDD_MONO ]]; then cp $CUSTOM/etc/gnb.sa.tdd.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_TDD_MONO_B2XX ]]; then cp $CUSTOM/etc/gnb.sa.tdd.b2xx.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_FDD_MONO ]]; then cp $CUSTOM/etc/gnb.sa.fdd.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_CU ]]; then cp $CUSTOM/etc/gnb.sa.cu.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_TDD_DU ]]; then cp $CUSTOM/etc/gnb.sa.du.tdd.conf $PREFIX/etc/gnb.conf; fi
if [[ -v USE_SA_NFAPI_VNF ]]; then cp $CUSTOM/etc/gnb.sa.nfapi.vnf.conf $PREFIX/etc/gnb.conf; fi
# Sometimes, the templates are not enough. We mount a conf file on $PREFIX/etc. It can be a template itself.
if [[ -v USE_VOLUMED_CONF ]]; then cp $CUSTOM/etc/mounted.conf $PREFIX/etc/gnb.conf; fi

# Defualt Parameters
GNB_ID=${GNB_ID:-e00}
NSSAI_SD=${NSSAI_SD:-ffffff}
# AMF_IP_ADDRESS can be amf ip address of amf fqdn
if [[ -v AMF_IP_ADDRESS ]] && [[ "${AMF_IP_ADDRESS}" =~ [a-zA-Z] ]] && [[ -z `getent hosts $AMF_IP_ADDRESS | awk '{print $1}'` ]]; then echo "not able to resolve AMF FQDN" && exit 1 ; fi
[[ -v AMF_IP_ADDRESS ]] && [[ "${AMF_IP_ADDRESS}" =~ [a-zA-Z] ]] && AMF_IP_ADDRESS=$(getent hosts $AMF_IP_ADDRESS | awk '{print $1}')

# Only this template will be manipulated
CONFIG_FILES=`ls $PREFIX/etc/gnb.conf || true`

for c in ${CONFIG_FILES}; do
    # Sometimes templates have no pattern to be replaced.
    if ! grep -oP '@[a-zA-Z0-9_]+@' ${c}; then
        echo "Configuration is already set"
        break
    fi

    # grep variable names (format: ${VAR}) from template to be rendered
    VARS=$(grep -oP '@[a-zA-Z0-9_]+@' ${c} | sort | uniq | xargs)

    # create sed expressions for substituting each occurrence of ${VAR}
    # with the value of the environment variable "VAR"
    EXPRESSIONS=""
    for v in ${VARS}; do
        NEW_VAR=`echo $v | sed -e "s#@##g"`
        if [[ "${!NEW_VAR}x" == "x" ]]; then
            echo "Error: Environment variable '${NEW_VAR}' is not set." \
                "Config file '$(basename $c)' requires all of $VARS."
            exit 1
        fi
        EXPRESSIONS="${EXPRESSIONS};s|${v}|${!NEW_VAR}|g"
    done
    EXPRESSIONS="${EXPRESSIONS#';'}"

    # render template and inline replace config file
    sed -i "${EXPRESSIONS}" ${c}

    echo "=================================="
    echo "== Configuration file: ${c}"
    cat ${c}
done

# Load the USRP binaries
echo "=================================="
echo "== Load USRP binaries"
if [[ -v USE_B2XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t b2xx
elif [[ -v USE_X3XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t x3xx
elif [[ -v USE_N3XX ]]; then
    $PREFIX/bin/uhd_images_downloader.py -t n3xx
fi

# enable printing of stack traces on assert
export gdbStacks=1

echo "=================================="
echo "== Starting gNB soft modem"
if [[ -v USE_ADDITIONAL_OPTIONS ]]; then
    echo "Additional option(s): ${USE_ADDITIONAL_OPTIONS}"
    new_args=()
    while [[ $# -gt 0 ]]; do
        new_args+=("$1")
        shift
    done
    for word in ${USE_ADDITIONAL_OPTIONS}; do
        new_args+=("$word")
    done
    echo "${new_args[@]}"
    exec "${new_args[@]}"
else
    echo "$@"
    exec "$@"
fi