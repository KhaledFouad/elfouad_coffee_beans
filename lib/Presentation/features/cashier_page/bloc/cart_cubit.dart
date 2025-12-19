import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodel/cart_state.dart';

class CartViewState extends Equatable {
  const CartViewState({required this.cart, required this.version});

  final CartState cart;
  final int version;

  CartViewState copyWith({CartState? cart, int? version}) {
    return CartViewState(
      cart: cart ?? this.cart,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [version];
}

class CartCubit extends Cubit<CartViewState> {
  CartCubit() : super(CartViewState(cart: CartState(), version: 0));

  CartState get cart => state.cart;

  void addLine(CartLine line) {
    state.cart.addLine(line);
    _bump();
  }

  void removeLine(String id) {
    state.cart.removeLine(id);
    _bump();
  }

  void clear() {
    state.cart.clear();
    _bump();
  }

  void setInvoiceDeferred(bool value) {
    state.cart.setInvoiceDeferred(value);
    _bump();
  }

  void setInvoiceComplimentary(bool value) {
    state.cart.setInvoiceComplimentary(value);
    _bump();
  }

  void setInvoiceNote(String value) {
    state.cart.setInvoiceNote(value);
    _bump();
  }

  void setPaymentMethod(String value) {
    state.cart.setPaymentMethod(value);
    _bump();
  }

  void _bump() {
    emit(state.copyWith(version: state.version + 1));
  }
}
