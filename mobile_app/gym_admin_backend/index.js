const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
app.use(cors()); // ✅ 支持跨域
app.use(bodyParser.json());

app.post('/send', async (req, res) => {
  const { token, title, body } = req.body;

  if (!token || !title || !body) {
    return res.status(400).send('参数缺失');
  }

  const message = {
    token,
    notification: {
      title:'你有新消息',
      body:'来自好友的消息',
    },
    android: {
      priority: "high",
      notification: {
        channelId: "messages", // 🔧 要与你 Flutter 插件中注册的相同
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title,
            body,
          },
          sound: "default",
        },
      },
    },
  };


  try {
    const response = await admin.messaging().send(message);
    console.log(`✅ 通知发送成功: ${response}`);
    res.status(200).send('Notification sent');
  } catch (error) {
    console.error('❌ 通知发送失败:', error);
    res.status(500).send('Failed to send notification');
  }
});

app.listen(3000, () => {
  console.log('🚀 通知服务运行在 http://localhost:3000');
});
