import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitz/data/models/order.dart';
import 'package:splitz/data/models/order_item.dart';
import 'package:splitz/data/models/user.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;

  OrderDetailsScreen({required this.order});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (user?.userType == 'client') ...[
                  _buildSectionTitle('My Bill'),
                  ...order.items
                      .where((item) =>
                          item.userList.any((u) => u.userId == user!.uid))
                      .map((item) => _buildOrderItem(item)),
                  _buildSectionTitle('All Orders'),
                ],
                ...order.items.map((item) => _buildOrderItem(item)),
                SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Order Summary',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(),
                        if (user?.userType == 'manager')
                          _buildOrderInfo('Order ID', order.orderId),
                        if (user?.userType == 'manager')
                          _buildOrderInfo('Restaurant ID', order.restaurantId),
                        _buildOrderInfo('Table Number', order.tableNumber),
                        _buildOrderInfo('Order Date', order.date),
                        Divider(),
                        _buildTotalInfo('Total Bill', order.totalBill),
                        if (user?.userType == 'manager')
                          _buildTotalInfo('Paid So Far', order.paidSoFar),
                        if (user?.userType == 'client')
                          _buildTotalInfo(
                              'My Total', _calculateMyTotal(user!.uid)),
                        if (user?.userType == 'manager')
                          _buildOrderInfo('Status',
                              order.status == 'paid' ? 'Paid' : 'Unpaid'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOrderInfo(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:', style: TextStyle(fontSize: 18)),
          Text(value, style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildTotalInfo(String title, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('EGP ${value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.quantity} x ${item.itemName}',
                          style: TextStyle(fontSize: 16)),
                      Text('EGP ${item.paidAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                if (item.imageUrl != null && item.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25.0),
                    child: Image.network(
                      item.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            if (item.extras.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                    'Extras: ${item.extras.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            if (item.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Notes: ${item.notes}',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateMyTotal(String userId) {
    double total = 0.0;
    for (var item in order.items) {
      if (item.userList.any((u) => u.userId == userId)) {
        total += item.paidAmount;
      }
    }
    return total;
  }
}
