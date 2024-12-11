import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:splitz/data/models/order.dart';
import 'package:splitz/data/models/order_item.dart';
import 'package:splitz/data/services/auth.dart';
import 'package:splitz/data/models/user.dart';

class OrderService {
  //Private constructor
  OrderService._();

  // The single instance of the class
  static final OrderService _instance = OrderService._();

  // Factory method to access the instance
  factory OrderService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
  /// Fetch all orders for a specific restaurant
  Future<List<Order>> fetchOrdersByRestaurant(String restaurantId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('orders')
          .where('restaurant_id', isEqualTo: restaurantId)
          .get();

      return querySnapshot.docs
          .map((doc) =>
              Order.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Fetch a specific order by ID
  Future<Order?> fetchOrderById(String orderId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('orders').doc(orderId).get();

      if (doc.exists) {
        return Order.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      } else {
        return null;
      }
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  /// Create a new order
  Future<void> createOrder(Order order) async {
    try {
      await _firestore
          .collection('orders')
          .doc(order.orderId)
          .set(order.toMap());
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update an existing order
  Future<void> updateOrder(Order order) async {
    try {
      await _firestore
          .collection('orders')
          .doc(order.orderId)
          .update(order.toMap());
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  /// Delete an order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  /// Listen to real-time updates for a specific restaurant's orders
  Stream<List<Order>> listenToOrdersByRestaurant(String restaurantId) {
    try {
      return _firestore
          .collection('orders')
          .where('restaurant_id', isEqualTo: restaurantId)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs
              .map((doc) => Order.fromFirestore(
                  doc.id, doc.data() as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw Exception('Failed to listen to orders: $e');
    }
  }

  Future<void> updateItemStatus(String orderId, String itemID) async {
    try {
      DocumentReference orderRef = _firestore.collection('orders').doc(orderId);
      DocumentSnapshot orderSnapshot = await orderRef.get();

      if (orderSnapshot.exists) {
        Order order = Order.fromFirestore(
            orderSnapshot.id, orderSnapshot.data() as Map<String, dynamic>);

        // Update item status
        for (var item in order.items) {
          if (item.itemId == itemID) {
            item.prepared = true;
          }
        }

        // Update Firestore with modified items
        await orderRef.update({
          'items': order.items.map((item) => item.toMap()).toList(),
        });
        print('Item status updated to prepared');
      } else {
        print('Order not found');
      }
    } catch (e) {
      print('Error updating item status: $e');
    }
  }

  // Update the overall order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      DocumentReference orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);

      if (newStatus == "served") {
        DocumentSnapshot orderSnapshot = await orderRef.get();

        if (orderSnapshot.exists) {
          // Convert the 'items' field to a List<OrderItem>
          List<dynamic> itemsData = orderSnapshot['items'];
          List<OrderItem> items = itemsData.map((item) {
            return OrderItem.fromFirestore(item as Map<String, dynamic>);
          }).toList();

          // Mark items as prepared
          for (var item in items) {
            item.prepared = true;
          }
          await orderRef.update({
            'status': newStatus,
            'items': items.map((item) => item.toMap()).toList(),
          });

          print(
              'Order status updated to "served" and items marked as prepared');
        } else {
          print('Order not found');
        }
      } else {
        await orderRef.update({
          'status': newStatus,
        });
        print('Order status updated to $newStatus');
      }
    } catch (e) {
      print('Error updating order status in Firestore: $e');
    }
  }

  // Fetch orders by restaurant ID and status
  Stream<List<Order>> fetchOrders(String restaurantId, String orderStatus) {
    return _firestore
        .collection('orders')
        .where('restaurant_id', isEqualTo: restaurantId)
        .where('status', isEqualTo: orderStatus.toLowerCase())
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Order.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<void> checkAndAddUserToOrder({
    required String restaurantId,
    required String tableNumber,
  }) async {
    try {
       final FirebaseAuth _auth = FirebaseAuth.instance;

      User? user = _auth.currentUser;

      if (user != null) {
        String userId = user.uid;
        // Generate order ID (you can use Firestore auto-generated ID or create your own)
        String orderId = _firestore.collection('orders').doc().id;
      // Query to find orders that match the restaurant and table number
      QuerySnapshot querySnapshot = await _firestore
          .collection('orders')
          .where('restaurant_id', isEqualTo: restaurantId)
          .where('table_number', isEqualTo: tableNumber)
          .where ('status', isEqualTo: 'not paid')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Order exists, now check if the user is already in the user list
        DocumentSnapshot orderDoc = querySnapshot.docs.first;
        Order order = Order.fromFirestore(orderDoc.id, orderDoc.data() as Map<String, dynamic>);

        if (!order.userIds.contains(userId)) {
          // Add the user to the list if not already present
          order.userIds.add(userId);
          
          // Update the order with the new user list
          await orderDoc.reference.update({
            'user_ids': order.userIds,
          });
           await _updateUserOrderIds(userId, orderDoc.id);
          print('User added to the existing order');
        } else {
          print('User already exists in the order');
        }
      } else {
        // No existing order, create a new one
        String orderId = _firestore.collection('orders').doc().id; // Generate new order ID

        Order newOrder = Order(
          orderId: orderId,
          restaurantId: restaurantId,
          status: 'not paid',  // Assuming new orders are 'pending'
          tableNumber: tableNumber,
          totalBill: 0.0,
          paidSoFar: 0.0,
          paid: false,
          items: [],
          userIds: [userId], // Add the user to the list
        );
        
        // Create the new order in Firestore
        await _firestore.collection('orders').doc(orderId).set({
          'restaurant_id': restaurantId,
          'order_id': orderId,
          'status': 'not paid',
          'table_number': tableNumber,
          'total_bill': 0.0,
          'paid_so_far': 0.0,
          'paid': false,
          'items': [],
          'user_ids': [userId],
      });
       await _updateUserOrderIds(userId, orderId);
        print('New order created and user added');
      }
      } else {
        print('User not signed in');
      }
    } catch (e) {
      print('Error in checking or adding user to order: $e');
    }
  }
 // Listen to real-time updates for orders that contain the current user in user_ids
Stream<List<Order>> listenToOrdersByUserId() {
  
  final FirebaseAuth auth = FirebaseAuth.instance;
  User? user = auth.currentUser;
print("user id is ${user!.uid}");
  if (user == null) {
    return Stream.value([]);
  }
  return _firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .switchMap((userDoc) {
    if (!userDoc.exists) return Stream.value([]);
    print(userDoc.data());
    String? currentOrderId = userDoc.get('currentOrderId') as String?;
    print("current order id is $currentOrderId");
    if (currentOrderId == null) return Stream.value([]);

    return _firestore
        .collection('orders')
        .where('order_id', isEqualTo: currentOrderId)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Order.fromFirestore(doc.id, doc.data()))
            .toList());
  });
}
Future<void> _updateUserOrderIds(String userId, String orderId) async {
  try {
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    DocumentSnapshot userDoc = await userRef.get();

    if (userDoc.exists) {
      UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userId);


      if (user.currentOrderId != orderId) {
        user.currentOrderId = orderId;
      }

      if (!user.orderIds.contains(orderId)) {
        user.orderIds.add(orderId);
      }
        await userRef.update({
          'currentOrderId': user.currentOrderId,
          'orderIds': user.orderIds,
        });
        print('User document updated with new order ID');
      
    } else {
      print('User document not found');
    }
  } catch (e) {
    print('Error updating user orderIds: $e');
  }
}
Future<void> addItemToOrder(String userId, OrderItem item) async {
    try {

      // Get the user's current order ID
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      String? orderId = userDoc.get('currentOrderId') as String?;

      DocumentReference orderRef = _firestore.collection('orders').doc(orderId);
      
      // Get current items array
      DocumentSnapshot orderDoc = await orderRef.get();
      List<dynamic> currentItems = orderDoc.get('items') ?? [];
      
      // Add new item
      currentItems.add(item.toMap());

      // Update order document
      await orderRef.update({
        'items': currentItems,
      });
    } catch (e) {
      throw Exception('Failed to add item to order: $e');
    }
  }
  Future<void> updateItemInOrder(String orderId, OrderItem updatedItem, int orderItemInd) async {
    try {
      DocumentReference orderRef = _firestore.collection('orders').doc(orderId);
      DocumentSnapshot orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      List<dynamic> items = orderDoc.get('items') ?? [];
      int itemIndex = orderItemInd;

      if (itemIndex != -1) {
        items[itemIndex] = updatedItem.toMap();
        await orderRef.update({'items': items});
      } else {
        throw Exception('Item not found in order');
      }
    } catch (e) {
      throw Exception('Failed to update item in order: $e');
    }
  }
  Future <OrderItem> getOrderItemDetails(String orderId, int orderItemInd) async{
    try {
      DocumentSnapshot orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      List<dynamic> items = orderDoc.get('items') ?? [];
      if (orderItemInd < 0 || orderItemInd >= items.length) {
        throw Exception('Invalid item index');
      }

      return OrderItem.fromFirestore(items[orderItemInd]);
    } catch (e) {
      throw Exception('Failed to get order item details: $e');
    }
  }
}