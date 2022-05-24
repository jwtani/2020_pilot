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

# トレースログ出力先ファイル
TRACE_LOG_FILE=/var/log/zenikyo/trace.log

# 処理結果が記載されたファイル名
RESULT_FILE_NAME="send_result.txt"

# 結果ファイルが配置されるのを待つ秒数
TIMEOUT_SEC=3600

# 引数で渡された送信対象ディレクトリ
SEND_DIR=$1

# 引数で渡されたネットワーク種別
NETWORK_TYPE=$2

#####################################################################################################

# 引数が2つでなければ終了
if [ $# != 2 ]
then
	exit 9
fi

# 引数で指定されたディレクトリが存在しなければ終了
if [ ! -e ${SEND_DIR} ]
then
        exit 9
fi

# S3へ送信するZIP化対象のディレクトリ
target_dir=${SEND_DIR}/${NETWORK_TYPE}/

# ネットワーク種別のディレクトリが存在しなければ終了
if [ ! -e ${target_dir} ]
then
	exit 9
fi

# S3へ送信するZIPファイルのパス
zip_path="${ZIP_DIR}${target_dir//\//-}${EXT_ZIP}"

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]
then
        mkdir -p ${ZIP_DIR}
fi

# ディレクトリのZIP化
echo "create zip file ${target_dir} → ${zip_path}" >> ${TRACE_LOG_FILE}
zip -er --password=3z061119 ${zip_path} ${target_dir}

# S3へのファイルアップロード
echo "upload ${zip_path} to S3" >> ${TRACE_LOG_FILE}
key=${zip_path##*/}
md5cs=`openssl md5 -binary ${zip_path} | base64`
error=`aws s3api put-object --bucket ${BUCKET_NAME} --key .${key} --body ${zip_path} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} 2>&1 >/dev/null`

# 送信エラーになった場合
if [ -n "${error}" ]
then
        echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Could not upload ${target_dir} to S3." >> ${ERROR_LOG_FILE}
        echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」${error}" >> ${ERROR_LOG_FILE}

	# タイムアウトエラー
        exit 2
fi

# 送信用ZIPファイルの削除
echo "remove local file ${zip_path}" >> ${TRACE_LOG_FILE}
rm ${zip_path}

# 対象ディレクトリ下に結果ファイルが配置されるのを待つ
echo "result file search start" >> ${TRACE_LOG_FILE}
wait_sec=0
while [ ! -f ${target_dir}${RESULT_FILE_NAME} ]
do
        if [ ${TIMEOUT_SEC} -lt ${wait_sec} ]
        then
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Result file could not be detected." >> ${ERROR_LOG_FILE}
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Send bank transfer data」Timeout sec = ${TIMEOUT_SEC}" >> ${ERROR_LOG_FILE}

                # タイムアウトエラー
                exit 2
        fi

	echo "no such file ${target_dir}${RESULT_FILE_NAME}" >> ${TRACE_LOG_FILE}
	wait_sec=`expr ${wait_sec} + 1`
        sleep 1;
done

echo "${target_dir}${RESULT_FILE_NAME} is found" >> ${TRACE_LOG_FILE}

# 結果ファイルの配置を検知したら内容を取得する
result=`head -n 1 ${target_dir}${RESULT_FILE_NAME} | tail -n 1`

line_count=`cat ${target_dir}${RESULT_FILE_NAME} | wc -l`
if [ ${line_count} = "3" ]
then
	z_result=`head -n 3 ${target_dir}${RESULT_FILE_NAME} | tail -n 1`
	echo "ZCLIENT RESULT = [${z_result}]" >> ${TRACE_LOG_FILE}
fi

# 0 -> 全銀ミドルからの結果取得成功
# 1 -> ISDN接続失敗
exit ${result}
