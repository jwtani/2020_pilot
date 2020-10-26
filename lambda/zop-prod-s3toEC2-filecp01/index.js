//イベントハンドラ（メイン）
exports.handler = async (event, context) => {
  // S3 のインスタンス名
  var bucket = event.Records[0].s3.bucket.name;
  // key（アップロードのイベントがあったファイル名）
  var key = event.Records[0].s3.object.key;
  
  var ec2 = require('./ec2.js');
  
  // EC2へZIPファイル送信＆解凍
  return ec2.download(bucket, key);
};
