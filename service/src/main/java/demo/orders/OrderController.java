package demo.orders;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    /** Fixed on purpose: the golden responses in contract/golden must not depend on the clock. */
    private static final Instant FIXED_NOW = Instant.parse("2026-11-01T10:00:00Z");

    private final OrderRepository orders;

    public OrderController(OrderRepository orders) {
        this.orders = orders;
    }

    @GetMapping
    public List<OrderView> list() {
        return orders.findAll().stream().map(OrderView::new).toList();
    }

    @GetMapping("/{id}")
    public OrderView get(@PathVariable Long id) {
        return orders.findById(id)
                .map(OrderView::new)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderView create(@RequestBody CreateOrderRequest request) {
        BigDecimal factor = BigDecimal.valueOf(100 - request.discountPercent()).movePointLeft(2);
        OrderEntity saved = orders.save(new OrderEntity(
                request.sku(), OrderStatus.NEW, request.price().multiply(factor), FIXED_NOW));
        return new OrderView(saved);
    }

    @PostMapping("/{id}/status")
    public OrderView changeStatus(@PathVariable Long id, @RequestBody ChangeStatusRequest request) {
        OrderEntity order = orders.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        order.setStatus(request.status());
        return new OrderView(orders.save(order));
    }
}
