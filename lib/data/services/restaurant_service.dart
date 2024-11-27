//made for test cases
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/review.dart';

class RestaurantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new restaurant with default attributes
  Future<void> createRestaurant({
    required String name,
    required String image,
  }) async {
    try {
      // Create a new restaurant document in Firestore
      await _db.collection('restaurants').add({
        'name': name,
        'overall_rating': 0.0, // Default rating
        'image': image,
      });

      print('Restaurant "$name" created successfully.');
    } catch (e) {
      print('Error creating restaurant: $e');
    }
  }
 Future<List<Restaurant>> fetchRestaurants() async {
  try {
    QuerySnapshot snapshot = await _db.collection('restaurants').get();

    // Map Firestore documents to Restaurant objects
    List<Restaurant> restaurants = [];
    for (var doc in snapshot.docs) {
      Map<String, dynamic> restaurantData = doc.data() as Map<String, dynamic>;

      // Fetch `menu_categories` subcollection
      QuerySnapshot menuCategoriesSnapshot =
          await _db.collection('restaurants').doc(doc.id).collection('menu_categories').get();
      List<MenuCategory> menuCategories = [];
      if(menuCategoriesSnapshot.docs.length!=0){
      menuCategories = menuCategoriesSnapshot.docs.map((menuDoc) {
        return MenuCategory.fromFirestore(menuDoc.data() as Map<String, dynamic>);
      }).toList();
      }

      // Fetch `menu_items` subcollection
      QuerySnapshot menuItemsSnapshot =
          await _db.collection('restaurants').doc(doc.id).collection('menu_items').get();
        List<MenuItem> menuItems = [];
      if(menuItemsSnapshot.docs.length!=0){
     menuItems = menuItemsSnapshot.docs.map((itemDoc) {
      
        return MenuItem.fromFirestore(itemDoc.id,itemDoc.data() as Map<String, dynamic>);
      }).toList();
      }

      // Fetch `reviews` subcollection
      QuerySnapshot reviewsSnapshot =
          await _db.collection('restaurants').doc(doc.id).collection('reviews').get();
          List<Review> reviews = [];
      if(reviewsSnapshot.docs.length!=0){
      reviews = reviewsSnapshot.docs.map((reviewDoc) {
        return Review.fromFirestore(reviewDoc.data() as Map<String, dynamic>);
      }).toList();
    }

      // Add all data to the Restaurant object
      restaurants.add(
        Restaurant(
          name: restaurantData['name'] ?? 'Unknown',
          overallRating: (restaurantData['overall_rating'] ?? 0).toDouble(),
          image: restaurantData['image'] ?? '',
          reviews: reviews,
          menuCategories: menuCategories,
          menuItems: menuItems,
        ),
      );
    }
    return restaurants;
  } catch (e) {
    print('Error fetching restaurants: $e');
    return [];
  }
}


}
