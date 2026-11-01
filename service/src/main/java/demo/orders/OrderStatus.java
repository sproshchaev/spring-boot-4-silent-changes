package demo.orders;

/** toString() is used for logs and the operator UI, the API contract is the constant name. */
public enum OrderStatus {
    NEW("Новый"),
    PAID("Оплачен");

    private final String label;

    OrderStatus(String label) {
        this.label = label;
    }

    @Override
    public String toString() {
        return label;
    }
}
