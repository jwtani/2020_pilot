const AWS = require('aws-sdk');
const SQS = new AWS.SQS({apiVersion: '2020-08-04'});

// SQS メッセージキューイング
exports.queueing = async function(body) {
    const QUEUE_URL = 'https://sqs.ap-northeast-1.amazonaws.com/889520124611/zop-prod-sqs01';

    // 送信するメッセージ
    var params = {
        MessageBody: body,
        QueueUrl: QUEUE_URL,
        DelaySeconds: 0
    };

    // 送信
    SQS.sendMessage(params, function(err, data) {
        if (err) console.log(err, err.stack); // エラーがあった場合
        else     console.log(data);           // 正常の場合
    });
}
