// firebase/functions/index.js
// 用途：Firebase Cloud Functions - FCM推送通知服务 (v2 兼容版本)

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const cors = require('cors')({origin: true});

// 初始化Firebase Admin SDK
admin.initializeApp();

// 获取Firestore和Messaging实例
const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// 核心通知处理函数
// ============================================================================

/**
 * 处理FCM通知队列
 * 监听 fcm_notifications 集合的新文档，自动发送推送通知
 */
exports.processFCMNotifications = onDocumentCreated('fcm_notifications/{notificationId}', async (event) => {
  const notificationData = event.data.data();
  const notificationId = event.params.notificationId;

  console.log('🔔 Processing FCM notification:', notificationId);
  console.log('📄 Notification data:', notificationData);

  try {
    // 验证通知数据
    if (!notificationData.targetUid) {
      console.error('❌ Missing targetUid in notification data');
      await markNotificationAsProcessed(notificationId, false, 'Missing targetUid');
      return;
    }

    // 获取目标用户的FCM Token
    const tokens = await getUserFCMTokens(notificationData.targetUid);
    if (tokens.length === 0) {
      console.warn('⚠️ No FCM tokens found for user:', notificationData.targetUid);
      await markNotificationAsProcessed(notificationId, false, 'No FCM tokens found');
      return;
    }

    // 构建FCM消息
    const message = buildFCMMessage(notificationData, tokens);

    // 发送推送通知
    const result = await sendFCMMessage(message);

    // 标记为已处理
    await markNotificationAsProcessed(notificationId, true, 'Successfully sent');

    console.log('✅ FCM notification sent successfully:', result);

  } catch (error) {
    console.error('❌ Error processing FCM notification:', error);
    await markNotificationAsProcessed(notificationId, false, error.message);
  }
});

/**
 * 处理新预约请求通知
 * 监听 appointments 集合的新文档，自动发送通知给管理员
 */
exports.onNewAppointment = onDocumentCreated('appointments/{appointmentId}', async (event) => {
  const appointment = event.data.data();
  const appointmentId = event.params.appointmentId;

  console.log('📅 New appointment created:', appointmentId);

  try {
    // 只处理待审批的预约
    if (appointment.overallStatus !== 'pending' || appointment.adminApproval !== 'pending') {
      console.log('📋 Appointment not pending admin approval, skipping notification');
      return;
    }

    // 查找健身房管理员
    const adminUid = await findGymAdmin(appointment.gymId);
    if (!adminUid) {
      console.warn('⚠️ No admin found for gym:', appointment.gymName);
      return;
    }

    // 创建通知
    const notificationData = {
      targetUid: adminUid,
      title: 'New Appointment Request',
      body: `${appointment.userName} requested appointment with ${appointment.coachName}`,
      data: {
        type: 'new_appointment',
        appointmentId: appointmentId,
        userId: appointment.userId,
        userName: appointment.userName,
        coachName: appointment.coachName,
        gymName: appointment.gymName,
        date: appointment.date.toDate().toISOString(),
        timeSlot: appointment.timeSlot,
        clickAction: '/appointments'
      },
      type: 'new_appointment',
      priority: 'high',
      platform: 'web',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    };

    // 添加到FCM通知队列
    await db.collection('fcm_notifications').add(notificationData);

    console.log('✅ Appointment notification queued for admin:', adminUid);

  } catch (error) {
    console.error('❌ Error handling new appointment:', error);
  }
});

/**
 * 处理新绑定请求通知
 * 监听 binding_requests 集合的新文档，自动发送通知给管理员
 */
exports.onNewBindingRequest = onDocumentCreated('binding_requests/{requestId}', async (event) => {
  const request = event.data.data();
  const requestId = event.params.requestId;

  console.log('🏃‍♂️ New binding request created:', requestId);

  try {
    // 只处理待审批的请求
    if (request.status !== 'pending') {
      console.log('📋 Request not pending, skipping notification');
      return;
    }

    // 获取目标管理员
    const adminUid = request.targetAdminUid || await findGymAdmin(request.gymId);
    if (!adminUid) {
      console.warn('⚠️ No admin found for binding request:', requestId);
      return;
    }

    // 创建通知
    const requestType = request.type || 'bind';
    const notificationData = {
      targetUid: adminUid,
      title: `${requestType === 'bind' ? 'Binding' : 'Unbinding'} Request`,
      body: `Coach ${request.coachName} wants to ${requestType} ${request.gymName}`,
      data: {
        type: `new_${requestType}_request`,
        requestId: requestId,
        coachId: request.coachId,
        coachName: request.coachName,
        gymName: request.gymName,
        requestType: requestType,
        clickAction: '/coaches'
      },
      type: `new_${requestType}_request`,
      priority: 'high',
      platform: 'web',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    };

    // 添加到FCM通知队列
    await db.collection('fcm_notifications').add(notificationData);

    console.log('✅ Binding request notification queued for admin:', adminUid);

  } catch (error) {
    console.error('❌ Error handling new binding request:', error);
  }
});

// ============================================================================
// 工具函数
// ============================================================================

/**
 * 获取用户的FCM Token列表
 */
async function getUserFCMTokens(uid) {
  try {
    const tokens = [];

    // 从admins集合获取Web端token
    const adminDoc = await db.collection('admins').doc(uid).get();
    if (adminDoc.exists) {
      const adminData = adminDoc.data();
      if (adminData.webFcmToken) {
        tokens.push(adminData.webFcmToken);
      }
      if (adminData.fcmToken) {
        tokens.push(adminData.fcmToken);
      }
    }

    // 从users集合获取移动端token（备用）
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    }

    // 去重
    return [...new Set(tokens)];
  } catch (error) {
    console.error('❌ Error getting FCM tokens:', error);
    return [];
  }
}

/**
 * 构建FCM消息 - v2兼容版本
 */
function buildFCMMessage(notificationData, tokens) {
  const priority = notificationData.priority || 'normal';
  const type = notificationData.type || 'general';
  const BASE_URL = 'https://gym-app-firebase-79daf.web.app';

  // 基础消息结构
  const message = {
    notification: {
      title: notificationData.title,
      body: notificationData.body,
      icon: '/favicon.ico',
    },
    data: {
      type: type,
      timestamp: new Date().toISOString(),
      notificationId: notificationData.notificationId || 'unknown',
    },
    webpush: {
      notification: {
        title: notificationData.title,
        body: notificationData.body,
        icon: '/favicon.ico',
        badge: '/favicon.ico',
        requireInteraction: priority === 'high' || priority === 'urgent',
        silent: false,
        tag: type,
      },
      fcmOptions: {
        link: BASE_URL + (notificationData.data?.clickAction || '/')
      }
    },
    android: {
      priority: priority === 'high' ? 'high' : 'normal',
      notification: {
        channelId: 'admin_notifications',
        priority: priority === 'high' ? 'high' : 'default',
        sound: 'default',
      }
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: notificationData.title,
            body: notificationData.body,
          },
          sound: 'default',
          badge: 1,
        }
      }
    }
  };

  // 添加自定义数据
  if (notificationData.data) {
    Object.assign(message.data, notificationData.data);
  }

  // 根据token数量选择发送方式
  if (tokens.length === 1) {
    message.token = tokens[0];
  } else {
    message.tokens = tokens;
  }

  return message;
}

/**
 * 发送FCM消息
 */
async function sendFCMMessage(message) {
  try {
    if (message.tokens) {
      // 批量发送
      const response = await messaging.sendEachForMulticast(message);
      console.log('📤 Multicast message sent:', response.successCount, 'success,', response.failureCount, 'failures');

      // 处理失败的token
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error('❌ Failed to send to token:', message.tokens[idx], resp.error);
          }
        });
      }

      return response;
    } else {
      // 单个发送
      const messageId = await messaging.send(message);
      console.log('📤 Single message sent:', messageId);
      return { messageId };
    }
  } catch (error) {
    console.error('❌ Error sending FCM message:', error);
    throw error;
  }
}

/**
 * 查找健身房管理员
 */
async function findGymAdmin(gymId) {
  try {
    // 方法1: 从gym_info集合查找
    const gymDoc = await db.collection('gym_info').doc(gymId).get();
    if (gymDoc.exists) {
      const gymData = gymDoc.data();
      return gymData.adminUid || gymData.ownerId || gymId;
    }

    // 方法2: 从gyms集合查找
    const gymDocAlt = await db.collection('gyms').doc(gymId).get();
    if (gymDocAlt.exists) {
      const gymData = gymDocAlt.data();
      return gymData.adminUid || gymData.ownerId || gymId;
    }

    // 方法3: 使用gymId作为adminUid（最后备用）
    return gymId;
  } catch (error) {
    console.error('❌ Error finding gym admin:', error);
    return null;
  }
}

/**
 * 标记通知为已处理
 */
async function markNotificationAsProcessed(notificationId, success, message) {
  try {
    await db.collection('fcm_notifications').doc(notificationId).update({
      processed: true,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      success: success,
      result: message
    });
  } catch (error) {
    console.error('❌ Error marking notification as processed:', error);
  }
}

// ============================================================================
// HTTP函数（可选 - 用于测试和手动触发）
// ============================================================================

/**
 * 测试通知发送（HTTP函数）
 */
exports.testNotification = onRequest({cors: true}, async (req, res) => {
  try {
    console.log('🧪 Test notification endpoint called');

    // 验证请求方法
    if (req.method !== 'POST') {
      return res.status(405).json({error: 'Method not allowed'});
    }

    const { targetUid, title, body, type = 'test' } = req.body;

    if (!targetUid || !title || !body) {
      return res.status(400).json({
        error: 'Missing required fields: targetUid, title, body'
      });
    }

    // 创建测试通知
    const notificationData = {
      targetUid,
      title,
      body,
      data: {
        type,
        test: true,
        timestamp: new Date().toISOString(),
      },
      type,
      priority: 'normal',
      platform: 'web',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    };

    // 添加到通知队列
    const docRef = await db.collection('fcm_notifications').add(notificationData);

    res.status(200).json({
      success: true,
      message: 'Test notification queued',
      notificationId: docRef.id
    });

  } catch (error) {
    console.error('❌ Error in test notification:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

/**
 * 获取通知统计（HTTP函数）
 */
exports.getNotificationStats = onRequest({cors: true}, async (req, res) => {
  try {
    const { adminUid } = req.query;

    if (!adminUid) {
      return res.status(400).json({error: 'Missing adminUid parameter'});
    }

    // 获取管理员的通知统计
    const notificationsRef = db.collection('admins').doc(adminUid).collection('notifications');

    const totalSnapshot = await notificationsRef.get();
    const unreadSnapshot = await notificationsRef.where('isRead', '==', false).get();

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todaySnapshot = await notificationsRef
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(today))
      .get();

    const stats = {
      total: totalSnapshot.size,
      unread: unreadSnapshot.size,
      today: todaySnapshot.size,
      lastUpdated: new Date().toISOString()
    };

    res.status(200).json(stats);

  } catch (error) {
    console.error('❌ Error getting notification stats:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// ============================================================================
// 清理任务（定时函数）
// ============================================================================

/**
 * 清理已处理的FCM通知记录（每天运行一次）
 */
exports.cleanupProcessedNotifications = onSchedule('0 2 * * *', async (event) => {
  console.log('🧹 Starting notification cleanup task');

  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldNotificationsQuery = db
      .collection('fcm_notifications')
      .where('processed', '==', true)
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .limit(500); // 批量处理，避免超时

    const snapshot = await oldNotificationsQuery.get();

    if (snapshot.empty) {
      console.log('✅ No old notifications to clean up');
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    console.log(`✅ Cleaned up ${snapshot.size} old notification records`);

  } catch (error) {
    console.error('❌ Error in cleanup task:', error);
  }
});

console.log('🚀 Firebase Cloud Functions v2 loaded successfully');
console.log('📋 Available functions:');
console.log('  - processFCMNotifications (Firestore trigger)');
console.log('  - onNewAppointment (Firestore trigger)');
console.log('  - onNewBindingRequest (Firestore trigger)');
console.log('  - testNotification (HTTP)');
console.log('  - getNotificationStats (HTTP)');
console.log('  - cleanupProcessedNotifications (Scheduled)');