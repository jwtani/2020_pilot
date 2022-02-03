#!/bin/sh

#
# AWS関連の共通関数
#

# AmazonS3アップロード
function s3_upload() {
    # エラー：引数の数が４以外
    if [ $# -ne 4 ]; then
        echo ERROR: Invalid argument count. Specify four arguments. \<TARGET_FILE\> \<S3_KEY\> \<BUCKET_NAME\> \<PROFILE\>
        exit 1
    fi

    # 第１引数：アップロード対象ファイル
    TARGET_FILE=$1

    # 第２引数：S3アップロード後のファイルkey
    S3_KEY=$2

    # 第３引数：S3バケット名
    BUCKET_NAME=$3

    # 第４引数：コマンドを実行するプロファイル
    PROFILE=$4

    # エラー：存在しないファイル
    if [ ! -e ${TARGET_FILE} ]; then
        echo ERROR: ${TARGET_FILE} is not found. Please specify a valid file path.
        exit 1
    fi

    # エラー：ディレクトリが指定された
    if [ -d ${TARGET_FILE} ]; then
        echo ERROR: ${TARGET_FILE} is directory. Please specify a valid file path.
        exit 1
    fi

    # 対象ファイルのMD5ハッシュ値を取得
    md5cs=`openssl md5 -binary ${TARGET_FILE} | base64`
    code=$?

    # エラー：MD5ハッシュ値取得に失敗
    if [ ${code} -ne 0 ]; then
        echo ERROR: Faild to get ${TARGET_FILE} md5checksum.
        exit 1
    fi

    # S3へアップロード
    error=`/usr/local/bin/aws s3api put-object --bucket ${BUCKET_NAME} --key ${S3_KEY} --body ${TARGET_FILE} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} --profile ${PROFILE} 2>&1 >/dev/null`
    code=$?

    # エラー：S3へのファイルアップロードに失敗
    if [ ${code} -ne 0 ]; then
        echo ${error}
        exit 1
    fi 

    exit 0
}

# AmazonS3ダウンロード
function s3_download() {
    echo This is Amazon S3 download function. [Coming soon]
    exit 0
}
