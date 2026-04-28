#! /bin/bash
# scantofile
#

set +o noclobber

#
#   $1 = scanner device
#   $2 = friendly name
#


mount_cifsshare() {
    sudo mount -t cifs -o credentials=/etc/smbcredentials,vers=3.0 //filer/shared /mnt/scan/ || exit 1
    logger -t "brscan-skey" -s "[ERROR ] Could not mount ${CIFS_SHARE}. Exiting"
}

check_cifsmount() {
    CIFS_SHARE="//filer/shared" # Replace with your actual CIFS share
    MOUNT_POINT="/mnt/scan"      # Replace with your actual mount point

    if findmnt -t cifs -n "${CIFS_SHARE}" "${MOUNT_POINT}" &>/dev/null; then
        logger -t "brscan-skey" -s "[INFO  ] CIFS share ${CIFS_SHARE} is mounted to ${MOUNT_POINT}."
        return 0
    else
        logger -t "brscan-skey" -s "[INFO  ] CIFS share ${CIFS_SHARE} is * NOT * mounted to ${MOUNT_POINT}."
        return 1
    fi
}


if ! check_cifsmount; then
    # If share is not mounted, mount it and check again
    mount_cifsshare
    check_cifsmount
fi

BASE="/mnt/scan/scans"
if [[ ! -d "$BASE" ]]; then
    mkdir "$BASE"
    sleep 0.2
fi

if [ -e ~/.brscan-skey/scantofile.config ];then
    source ~/.brscan-skey/scantofile.config
elif [ -e /etc/opt/brother/scanner/brscan-skey/scantofile.config ];then
    source /etc/opt/brother/scanner/brscan-skey/scantofile.config
fi


#SCANIMAGE="/opt/brother/scanner/brscan-skey/skey-scanimage"
SCANIMAGE="/usr/bin/scanimage"

TEMP_DIR="$(mktemp -p $BASE -d)"
if [[ ! -d "$BASE" || ! -d "$TEMP_DIR" ]]; then
    logger -t "brscan-skey" -s "[ERROR ] $TARGET_DIR does not exist. Exiting."
    exit 1
fi

OUTPUT="$BASE/brscan_$(date +%Y-%m-%d-%H-%M-%S).pdf"
OPT_OTHER="-l 0 -t 0 -x 210.0 -y 297.0 --batch=out%03d.tiff"


logger -t "brscan-skey" "[DEBUG ] resolution: $resolution; duplex=$duplex; args: $*"
if [ "$resolution" != '' ];then
    OPT_RESO="--resolution $resolution"
else
    OPT_RESO="--resolution 300"
fi

# Note: empty for automatic detection
#OPT_SRC="--source FB"


#if [ "$size" != '' ];then
##   OPT_SIZE="--size $size"
#else
#   OPT_SIZE="--size A4"
#fi

if [ "$duplex" = 'ON' ];then
    OPT_DUP="--duplex"
    OPT_SRC="--source ADF_C"
else
    OPT_DUP=""
    OPT_SRC=""
fi

OPT_DEV="--device-name $1"

# Note: OPT_FILE not required in batch mode!
#OPT_FILE="--outputfile  $OUTPUT"

OUT_FORMAT="--format tiff"

OPT="$OPT_DEV $OPT_RESO $OPT_SRC $OPT_SIZE $OPT_DUP $OUT_FORMAT $OPT_OTHER $OPT_FILE"

if [ "$(echo "$1" | grep net)" != '' ];then
    sleep 1
fi


(
    cd "$TEMP_DIR" || exit 1
    logger -t "brscan-skey" -s "[DEBUG ] Scanning to \"$TEMP_DIR\" directory. Arguments $1 $2 $3 $4"
    logger -t "brscan-skey" -s "[DEBUG ] Cmd: $SCANIMAGE $OPT"
    $SCANIMAGE $OPT
)

sleep 0.2


(
    # convert TIFFs
    cd "$TEMP_DIR" || exit 1
    tiffcp out*.tiff "${TEMP_DIR}/combined.big" || exit 1
    tiff2pdf -p A4 -j -t "Document" -f -o "${OUTPUT}" "${TEMP_DIR}/combined.big" || exit 1
    rm *.tiff combined.big          # remove temporary files
)
[ ! -z "${TEMP_DIR:-}" ] && rmdir "${TEMP_DIR:-}"

# combine images into a single PDF
#gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite \
#-dPDFSETTINGS=/ebook -sOutputFile="${OUTPUT}" "${TEMP_DIR}/brscan.big"


echo "$OUTPUT" is created.
