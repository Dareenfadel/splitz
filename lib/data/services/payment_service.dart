import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:splitz/data/models/order.dart';
import 'package:splitz/data/services/order_item_service.dart';
import 'package:splitz/data/services/order_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._();
  factory PaymentService() => _instance;
  PaymentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();

  markUserAsPaid({
    required String orderId,
    required String userId,
  }) async {
    return _firestore.runTransaction((transaction) async {
      var orderRef = _firestore.collection('orders').doc(orderId);
      var orderSnapshot = await transaction.get(orderRef);

      if (!orderSnapshot.exists) {
        throw Exception('Order not found');
      }

      var order = Order.fromFirestore(
        orderSnapshot.id,
        orderSnapshot.data()!,
      );

      order.acceptedItemsForUserId(userId).forEach((item) {
        var sharePrice = item.sharePrice;
        item.paidUsers[userId] = sharePrice;
        item.paidAmount += sharePrice;
      });

      order.pendingItemsForUserId(userId).forEach((item) {
        item.userList.removeWhere((u) => u.userId == userId);
      });

      order.paidSoFar = order.calculatedPaidSoFar;
      order.paidUsers.add(userId);

      if (order.isFullyPaid) {
        order.status = 'paid';
        order.paid = true;
      }

      var newOrder = order.toMap();

      transaction.update(orderRef, newOrder);
    });
  }
}
