package demo.orders;

/** Clients send the constant name, for example {"status":"PAID"}. */
public record ChangeStatusRequest(OrderStatus status) {
}
