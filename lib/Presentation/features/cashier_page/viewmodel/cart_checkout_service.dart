part of 'cart_state.dart';

class CartCheckoutService {
  Future<String> commitInvoice({
    required CartState cart,
    FirebaseFirestore? firestore,
  }) {
    return CartCheckout.commitInvoice(cart: cart, firestore: firestore);
  }
}
