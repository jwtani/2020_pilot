#!/bin/bash

#
# 保険請求データ取込バッチ用のシェルスクリプト
#

# 自分自身が既にcronで実行されている時は処理を終了する
ps_count=`ps aux | pgrep -xfc '^((/bin/bash )|/|\./)[^ ]*/'$(basename $0)'$'`
if [ ${ps_count} -gt 1 ]; then
	exit 1
fi

. $(cd $(dirname $0) && pwd)/func.d/s3_functions

# ZIP化したファイルの一時配置場所
ZIP_DIR=/home/jw/jmc_upload/ins_clm

# ZIP拡張子
EXT_ZIP=".zip"

# 送信先S3バケット名
BUCKET_NAME="zop-prod-to-ec2"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# エラーログファイル格納ディレクトリ
ERROR_LOG_DIR=/var/log/zenikyo

# エラー出力先ファイル
ERROR_LOG_FILE=${ERROR_LOG_DIR}/error.log

#####################################################################################################

# エラーログ出力先が無ければ作成
if [ ! -e ${ERROR_LOG_DIR} ]; then
        mkdir ${ERROR_LOG_DIR}
fi

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]; then
        mkdir -p ${ZIP_DIR}
fi

targets=`find /data/jmc/jmc_w_ins_cmt -regextype posix-basic -regex '^/data/jmc/jmc_w_ins_cmt/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{4\}\.txt$'`
for target in $targets; do
        # ファイルのZIP化
        zip_path="${ZIP_DIR}/${target//\//-}${EXT_ZIP}"
        zip -er --password=3z061119 ${zip_path} ${target}

	# 送信済み用のディレクトリへファイル移動
	ok_dir_path=${target/jmc_w_ins_cmt/jmc_w_history}
	ym=${ok_dir_path%/*}
	ym=${ym##*/}
	ok_dir_path=${ok_dir_path%/*}
	ok_dir_path=${ok_dir_path%/*}
	dir_timestamp=`date +%Y%m%d_%H%M%S`
	ok_dir_path=${ok_dir_path}/insurance/${ym}/${dir_timestamp}
	mkdir -p ${ok_dir_path}

	# 送信済み用のディレクトリへファイル移動
	mv ${target} ${ok_dir_path}
done

# S3へのファイルアップロード
upload_files=`find ${ZIP_DIR} -type f`
for upload_file in $upload_files; do
        key=.${upload_file##*/}
	return_error=$(s3upload ${upload_file} ${key} ${BUCKET_NAME} ${AWSCLI_USER})
	return_code=$?

        # 送信エラーになった場合
        if [ ${return_code} -ne 0 ]; then
                delextension=${key/${EXT_ZIP}/}
                originalpath=${delextension//-/\/}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」Could not upload ${originalpath} to S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」${return_error}" >> ${ERROR_LOG_FILE}
	else
		# 送信済みZIPファイルの削除
		rm ${upload_file}
        fi
done

exit 0
