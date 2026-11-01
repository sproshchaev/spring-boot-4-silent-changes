package demo.orders;

import java.math.BigDecimal;

/** Older clients send "discountPercent": null, and that has always meant "no discount". */
public record CreateOrderRequest(String sku, BigDecimal price, int discountPercent) {
}
