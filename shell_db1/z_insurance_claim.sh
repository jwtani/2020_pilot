#!/bin/bash
set -u

#
# 保険請求データ取込バッチ用のシェルスクリプト
#

CURRENT_DIR=$(cd $(dirname $0) && pwd)
. ${CURRENT_DIR}/common_functions
. ${CURRENT_DIR}/s3_functions

# 多重起動回避
return_error=`check_multiple $(basename $0)`
return_code=$?
if [ ${return_code} -ne 0 ]; then
    echo ${return_error}
    exit 1
fi

CMT_DIR=/data/jmc/jmc_w_ins_cmt
HIST_DIR=/data/jmc/jmc_w_history
ZIP_DIR=/home/jw/jmc_upload/ins_clm
ERROR_LOG_DIR=/var/log/zenikyo
ERROR_LOG_FILE=${ERROR_LOG_DIR}/error.log

# 送信先S3バケット名: 旧
BUCKET_NAME="zop-prod-to-ec2"

# 送信先S3バケット名: 新
NEW_BUCKET_NAME="mcs-prod-bills"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# ZIP拡張子
EXT_ZIP=".zip"

# ZIPファイルのパスワード
ZIP_PASS="3z061119"

# 仮）AES256暗号化アップロード時の暗号キー
ENC_PASS="a0b1c2d3e4f5g6h7i8j9k0l1m2n3o4p5"

main() {
    is_old=$1
    is_new=$2

    targets=`find ${CMT_DIR} -regextype posix-basic \
        -regex '^'${CMT_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{4\}\.txt$'`
    for target in ${targets}; do
        
        ym=${targets%/*}
        ym=${ym##*/}

        # 新方式アップロード
        if [ ${is_new} ]; then
            key=ym/00001-0001.txt
            s3upload_aes256 ${NEW_BUCKET_NAME} ${key} ${target} ${ENC_PASS}
        fi

        # 履歴ディレクトリを作成
        dir_timestamp=`date +%Y%m%d_%H%M%S`
        ins_hist_dir=${HIST_DIR}/insurance/${ym}/${dir_timestamp}
        mkdir -p ${ins_hist_dir}

        # 旧方式アップロード対象ならZIP化
        if [ ${is_old} ]; then
            zip_path="${ZIP_DIR}/${target//\//-}"
            zip -er --password=${ZIP_PASS} ${zip_path} ${target}
            mv ${zip_path} ${zip_path}${EXT_ZIP}
        fi

        # 履歴ファイル移動
        mv ${target} ${ins_hist_dir}
    done

    # 旧方式アップロード
    upload_files=`find ${ZIP_DIR} -type f -name '*'${EXT_ZIP}`
    for upload_file in ${upload_files}; do
        # key eg. .-data-jmc-jmc_w_ins_cmt-202201-00001-0001.txt.zip
        key=.${upload_file##*/}
        return_error=$(s3upload ${BUCKET_NAME} ${key} ${upload_file})
        return_code=$?

        # 送信エラーになった場合
        if [ ${return_code} -ne 0 ]; then
            echo [`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」\
                Could not upload ${upload_file} to S3.$'\n' ${return_error}\
                >> ${ERROR_LOG_FILE}
        else
            # 送信済みZIPファイルの削除
            rm ${upload_file}
        fi
    done

    return 0
}

# エラーログ出力先が無ければ作成
if [ ! -e ${ERROR_LOG_DIR} ]; then
        mkdir ${ERROR_LOG_DIR}
fi

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]; then
        mkdir -p ${ZIP_DIR}
fi

set +u
upload_type=$1
is_old=false
if [[ "${upload_type}" =~ "old" ]]; then
    is_old=true
fi
is_new=false
if [[ "${upload_type}" =~ "new" ]] || [[ "${upload_type}" =~ "" ]]; then
    is_new=true
fi
set -u

return_error=`main is_old is_new 2>&1 1>/dev/null`

if [ $? -ne 0 ]; then
    echo ${return_error} >> ${ERROR_LOG_FILE}
    exit 1
fi

exit 0
