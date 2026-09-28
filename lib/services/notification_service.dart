
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
final FirebaseMessaging _messaging =
FirebaseMessaging.instance;

final FirebaseFirestore _db =
FirebaseFirestore.instance;

final FirebaseAuth _auth =
FirebaseAuth.instance;

Future<void> initialize() async {
try {
final settings =
await _messaging.requestPermission(
alert: true,
badge: true,
sound: true,
announcement: false,
carPlay: false,
criticalAlert: false,
provisional: false,
);

debugPrint(
'[NotificationService] Permission: '
'${settings.authorizationStatus}',
);

final token =
await _messaging.getToken();

debugPrint(
'[NotificationService] FCM Token: $token',
);

if (token != null) {
await saveToken(token);
}

FirebaseMessaging.onMessage.listen(
(RemoteMessage message) {
debugPrint(
'[NotificationService] Foreground notification',
);

debugPrint(
'Title: ${message.notification?.title}',
);

debugPrint(
'Body: ${message.notification?.body}',
);
},
);

FirebaseMessaging.onMessageOpenedApp.listen(
(RemoteMessage message) {
debugPrint(
'[NotificationService] Notification opened',
);

debugPrint(
'Data: ${message.data}',
);
},
);

final initialMessage =
await _messaging.getInitialMessage();

if (initialMessage != null) {
debugPrint(
'[NotificationService] App opened from notification',
);

debugPrint(
'Data: ${initialMessage.data}',
);
}

_messaging.onTokenRefresh.listen(
(newToken) async {
debugPrint(
'[NotificationService] Token refreshed',
);

debugPrint(
'New token: $newToken',
);

await saveToken(newToken);
},
);
} catch (e) {
debugPrint(
'[NotificationService] Error: $e',
);
}
}

Future<void> saveToken(String token) async {
final user = _auth.currentUser;

if (user == null) {
debugPrint(
'[NotificationService] No authenticated user',
);
return;
}

try {
await _db
    .collection('users')
    .doc(user.uid)
    .set(
{
'fcmToken': token,
'fcmTokenUpdatedAt':
FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);

debugPrint(
'[NotificationService] Token saved for user: '
'${user.uid}',
);
} catch (e) {
debugPrint(
'[NotificationService] Token save error: $e',
);
}
}
}

