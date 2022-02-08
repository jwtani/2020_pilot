#!/bin/bash
set -u

#
# 保険請求データ取込バッチ用のシェルスクリプト
#

CURRENT_DIR=$(cd $(dirname $0) && pwd)
. ${CURRENT_DIR}/common_functions
. ${CURRENT_DIR}/s3_functions

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

# エラーログ出力
output_error() {
    message="$1"
    logfile=$2

    echo [`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」${message} >> ${logfile}
}

# 多重起動回避
return_error=`check_multiple $(basename $0)`
return_code=$?
if [ ${return_code} -ne 0 ]; then
    output_error "${return_error}" ${ERROR_LOG_FILE}
    exit 1
fi

# メイン処理
main() {
    local upload_type=${1-}
    local is_old=false
    local is_new=false
    local targets

    # エラーログ出力先が無ければ作成
    if [ ! -e ${ERROR_LOG_DIR} ]; then
        mkdir ${ERROR_LOG_DIR}
    fi

    # zipファイルの一時格納先ディレクトリが無かったら作成
    if [ ! -e ${ZIP_DIR} ]; then
        mkdir -p ${ZIP_DIR}
    fi

    if [ "${upload_type}" = "old" ]; then
        is_old=true
    fi
    if [ "${upload_type}" = "new" ] || [ "${upload_type}" = "" ]; then
        is_new=true
    fi
    if [ "${upload_type}" = "oldnew" ]; then
        is_old=true
        is_new=true
    fi

    if [ ! ${is_old} ] && [ ! ${is_new} ]; then
        echo Invalid argument specified.
        return 1
    fi

    targets=`find ${CMT_DIR} -regextype posix-basic \
        -regex '^'${CMT_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{4\}\.txt$'`
    for target in ${targets}; do
        split_path=(${target//\// })
        ym=${split_path[3]}

        # 新方式アップロード
        if [ ${is_new} ]; then
            ins5=${split_path[4]}
            ins4=`echo ${split_path[5]} | sed 's/\.txt$//'`
            key=${ym}/${ins5}-${ins4}-enc.txt
            return_error=`s3upload_aes256 ${NEW_BUCKET_NAME} ${key} ${target} ${ENC_PASS}`
            return_code=$?

            # 送信エラーになった場合
            if [ ${return_code} -ne 0 ]; then
                output_error "Could not upload ${target} to S3. ${return_error}" ${ERROR_LOG_FILE}
                # 後の処理はスキップ
                continue
            fi
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

    # 旧方式無しならここで抜ける
    if [ ! ${is_old} ]; then
        return 0
    fi

    # 旧方式アップロード
    upload_files=`find ${ZIP_DIR} -type f -name '*'${EXT_ZIP}`
    for upload_file in ${upload_files}; do
        # key eg. .-data-jmc-jmc_w_ins_cmt-202201-00001-0001.txt.zip
        key=.${upload_file##*/}
        return_error=$(s3upload ${BUCKET_NAME} ${key} ${upload_file})
        return_code=$?

        # 送信エラーになった場合
        if [ ${return_code} -ne 0 ]; then
            output_error "Could not upload ${upload_file} to S3. ${return_error}" ${ERROR_LOG_FILE}
            # 後の処理はスキップ
            continue
        fi

        # 送信済みZIPファイルの削除
        rm ${upload_file}
    done

    return 0
}

main $@ 1>/dev/null

