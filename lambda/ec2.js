const AWS = require('aws-sdk');
const SSM = new AWS.SSM({apiVersion: '2020-08-04'});

// S3 → EC2
exports.download = async function(bucket, key) {
  // ファイル送信先である EC2 のディレクトリ
  var dir = '/tmp/jmc/s3_download/';
  // zip解凍後のファイル名
  var filename = key.replace(/.zip/, '');
  // 解凍したファイルを最終的に設置するファイルパス
  var filepath = key.replace(/.-/, '-').replace(/-/g, '/').replace(/.zip/, '');
  // エラーログファイル
  var errorlog = '/var/log/zenikyo/error.log';
  
  // 実行するコマンド
  var commands = [
    "if [ ! -e '" + dir + "' ]; then mkdir -p " + dir + "; fi", // ディレクトリが無ければ作成
    "error=`aws s3 cp s3://" + bucket + "/" + key + " " + dir + " 2>&1 >/dev/null`", // S3 からzipファイルをコピー
    "if [ -n ${error} ]; then " +
      "dt=`date '+%Y/%m/%d %H:%M:%S'`; " +
      "msg=`echo [${dt}] ${error}`; " +
      "echo ${msg} >> " + errorlog + "; " +   // S3よりファイルのコピーに失敗したエラーログ出力
    "else " +
      "md5cs=`openssl md5 -binary " + key + " | base64`; " + // コピーしてきたzipファイルのMD5チェックサム値を取得
      "aws_md5cs=`aws s3api head-object --bucket " + bucket + " --key " + key + " --query 'Metadata' | jq -r '.md5checksum'`; " +  // S3 にあるzipファイルのMD5チェックサム値を取得
      "if [ md5cs = aws_md5cs ]; then " +
        "unzip -P 3z061119 -u " + dir + key + " -d " + dir + "; " +  // zipファイル解凍
        "mv " + dir + filename + " " + filepath + "; " +  // 解凍後のファイルを移動
        "rm " + dir + key + "; " + // コピーしてきたzipファイル削除
        "aws s3 rm s3://" + bucket + "/" + key + "; " + // S3 のzipファイルを削除
      "else " +
        "dt=`date '+%Y/%m/%d %H:%M:%S'`; " +
        "msg=`echo [${dt}] S3の${key}ダウンロード時、MD5チェックサム値の整合性エラーが発生しました。`; " +
        "echo ${msg} >> " + errorlog + "; " +
      "fi; " +
      "rm " + dir + key + "; " +  // コピーしてきたzipファイル削除
    "fi",
  ];
  
  // コマンド実行時のパラメータ
  var params = {
    DocumentName: 'AWS-RunShellScript',   // 必須らしい
    InstanceIds: ['i-0a2e31826d1b896cd'], // EC2 のインスタンスIDを指定
    Parameters: {
      commands: commands,
      executionTimeout: ['300']
    },
    TimeoutSeconds: 600 // コマンド実行のタイムアウト
  };
  
  // コマンド実行＆結果を返す
  return await SSM.sendCommand(params).promise().catch(e => console.error(e));
}
