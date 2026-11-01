package demo.orders;

import java.math.BigDecimal;
import java.time.Instant;

/** A plain class on purpose: most long-lived services return beans, not records. */
public class OrderView {

    private final Long id;
    private final String sku;
    private final OrderStatus status;
    private final BigDecimal total;
    private final Instant createdAt;
    /** Always null: the golden responses show that non_null inclusion survives the upgrade. */
    private final String comment;

    public OrderView(OrderEntity entity) {
        this.id = entity.getId();
        this.sku = entity.getSku();
        this.status = entity.getStatus();
        this.total = entity.getTotal();
        this.createdAt = entity.getCreatedAt();
        this.comment = null;
    }

    public Long getId() {
        return id;
    }

    public String getSku() {
        return sku;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getComment() {
        return comment;
    }
}
