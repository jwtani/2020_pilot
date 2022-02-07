#!/bin/bash
set -u

#
# 保険請求データ取込バッチ用のシェルスクリプト
#

CURRENT_DIR=$(cd $(dirname $0) && pwd)
. ${CURRENT_DIR}/common_functions
. ${CURRENT_DIR}/s3_functions

# 自分自身が既に実行されている時は処理を終了する
return_error=`check_multiple $(basename $0)`
return_code=$?
if [ ${return_code} -ne 0 ]; then
	echo ${return_error}
	exit 1
fi

# jmc_w_ins_cmtディレクトリ
CMT_DIR=/data/jmc/jmc_w_ins_cmt

# jmc_w_historyディレクトリ
HIST_DIR=/data/jmc/jmc_w_history

# ZIP化したファイルの一時配置場所
ZIP_DIR=/home/jw/jmc_upload/ins_clm

# ZIP拡張子
EXT_ZIP=".zip"

# ZIPファイルのパスワード
ZIP_PASS="3z061119"

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

targets=`find ${CMT_DIR} -regextype posix-basic -regex '^'${CMT_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{4\}\.txt$'`
for target in ${targets}; do
        # ファイルのZIP化
        zip_path="${ZIP_DIR}/${target//\//-}"
        zip -er --password=${ZIP_PASS} ${zip_path} ${target}

	# 対象ファイルのパスから履歴ファイル格納ディレクトリのパスを特定
	# 例：/data/jmc/jmc_w_inc_cmt/202201/00001 → /data/jmc/jmc_w_history/insurance/202201/20220201_093045
	ok_dir_path=${target/jmc_w_ins_cmt/jmc_w_history}
	ym=${ok_dir_path%/*}
	ym=${ym##*/}
	ok_dir_path=${ok_dir_path%/*}
	ok_dir_path=${ok_dir_path%/*}
	dir_timestamp=`date +%Y%m%d_%H%M%S`
	ok_dir_path=${ok_dir_path}/insurance/${ym}/${dir_timestamp}

	# 履歴ファイル格納ディレクトリを作成
	mkdir -p ${ok_dir_path}

	# アップロード待機ファイルに.zip拡張子を付与
	mv ${zip_path} ${zip_path}${EXT_ZIP}

	# 履歴ファイル格納ディレクトリへ元ファイル移動
	mv ${target} ${ok_dir_path}
done

# S3へのファイルアップロード
upload_files=`find ${ZIP_DIR} -type f -name '*'${EXT_ZIP}`
for upload_file in ${upload_files}; do
        # ファイルのZIP化
        key=.${upload_file##*/}
	return_error=$(s3upload ${upload_file} ${key} ${BUCKET_NAME} ${AWSCLI_USER})
	return_code=$?

        # 送信エラーになった場合
        if [ ${return_code} -ne 0 ]; then
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」Could not upload ${upload_file} to S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」${return_error}" >> ${ERROR_LOG_FILE}
	else
		# 送信済みZIPファイルの削除
		rm ${upload_file}
        fi
done

exit 0
