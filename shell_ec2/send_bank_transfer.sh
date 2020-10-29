#!/bin/bash

#
# 銀行振替データ送信バッチ用のシェルスクリプト
#

# ZIP化したファイルの一時配置場所
ZIP_DIR=/tmp/jmc/s3_upload/

# ZIP拡張子
EXT_ZIP=".zip"

# 送信先S3バケット名
BUCKET_NAME="zop-prod-from-ec2"

# エラー出力先ファイル
ERROR_LOG_FILE=/var/log/zenikyo/error.log

# 処理結果が記載されたファイル名
RESULT_FILE_NAME="send_result.txt"

# 結果ファイルが配置されるのを待つ秒数
TIMEOUT_SEC=600

# 引数で渡された送信対象ディレクトリ
TARGET_DIR=$1

#####################################################################################################

# S3へ送信するZIPファイルのパス
zip_path="${ZIP_DIR}${TARGET_DIR//\//-}${EXT_ZIP}"

# 引数で指定されたディレクトリが存在しなければ終了（通常の運用ではあり得ない）
if [ ! -e ${TARGET_DIR} ]
then
        exit 9
fi

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]
then
        mkdir -p ${ZIP_DIR}
fi

# ディレクトリのZIP化
zip -r ${zip_path} ${TARGET_DIR}

# S3へのファイルアップロード
key=${zip_path##*/}
md5cs=`openssl md5 -binary ${zip_path} | base64`
error=`aws s3api put-object --bucket ${BUCKET_NAME} --key .${key} --body ${zip_path} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} 2>&1 >/dev/null`

# 送信エラーになった場合
if [ -n "${error}" ]
then
        echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Could not upload ${TARGET_DIR} to S3." >> ${ERROR_LOG_FILE}
        echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」${error}" >> ${ERROR_LOG_FILE}

	# タイムアウトエラー
        exit 2
fi

# 送信用ZIPファイルの削除
rm ${zip_path}

# 対象ディレクトリ下に結果ファイルが配置されるのを待つ
wait_sec=0
while [ ! -f ${TARGET_DIR}${RESULT_FILE_NAME} ]
do
        if [ ${TIMEOUT_SEC} < ${wait_sec} ]
        then
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Result file could not be detected." >> ${ERROR_LOG_FILE}
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Timeout sec = ${TIMEOUT_SEC}" >> ${ERROR_LOG_FILE}

                # タイムアウトエラー
                exit 2
        fi

	wait_sec=`expr ${wait_sec} + 1`
        sleep 1;
done

# 結果ファイルの配置を検知したら内容を取得する
result=`head -n 1 ${TARGET_DIR}${RESULT_FILE_NAME} | tail -n 1`

# 0 -> 全銀ミドルからの結果取得成功
# 1 -> ISDN接続失敗
exit ${result}
