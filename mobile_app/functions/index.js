const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

exports.sendChatNotification = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("❌ 没有数据");
    return;
  }

  const message = snap.data();
  const senderId = message.senderId;
  const text = message.text;
  const chatId = event.params.chatId;

  const [uid1, uid2] = chatId.split("_");
  const receiverId = senderId === uid1 ? uid2 : uid1;

  const userDoc = await db.collection("users").doc(receiverId).get();
  const fcmToken = userDoc.get("fcmToken");

  if (!fcmToken) {
    console.log("❌ 接收者没有 FCM Token");
    return;
  }

  const payload = {
    notification: {
      title: "💬 新消息",
      body: text,
    },
    data: {
      type: "chat",
      chatId: chatId,
      senderId: senderId,
    },
    token: fcmToken,
  };

  try {
    await getMessaging().send(payload);
    console.log("✅ 推送已发送");
  } catch (err) {
    console.error("❌ 推送失败", err);
  }
});
